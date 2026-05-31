import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const tokenHashSecret = Deno.env.get("TOKEN_HASH_SECRET") ?? serviceRoleKey;
const functionBaseUrl =
  Deno.env.get("HOSTED_PUBLIC_BASE_URL") ??
  "https://dtzydnjnqkruxaacgkio.supabase.co/functions/v1/healthsync";

const db = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-version, x-device-id",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

type TokenKind = "ingest" | "agent_read";

type AuthContext = {
  workspaceId: string;
};

type PageInfo = {
  limit: number;
  offset: number;
  has_more: boolean;
};

type RangeInfo = {
  from: string | null;
  to: string | null;
};

class HttpError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const path = normalizePath(url.pathname);

    if (path === "/health" && req.method === "GET") {
      return json({ ok: true });
    }

    if (path === "/api/hosted/workspaces" && req.method === "POST") {
      return await provisionWorkspace(req);
    }

    if (path === "/api/apple-health/sync" && req.method === "POST") {
      return await ingestSync(req);
    }

    if (path === "/api/agent/health-data" && req.method === "GET") {
      return await agentHealthData(req, url);
    }

    if (path === "/api/agent/metrics" && req.method === "GET") {
      return await agentList(req, url, "health_metrics");
    }

    if (path === "/api/agent/workouts" && req.method === "GET") {
      return await agentList(req, url, "health_workouts");
    }

    if (path === "/api/agent/syncs" && req.method === "GET") {
      return await agentList(req, url, "sync_batches");
    }

    return json({ detail: "Not found" }, 404);
  } catch (error) {
    if (error instanceof HttpError) {
      return json({ detail: error.message }, error.status);
    }

    console.error(error);
    return json({ detail: "Internal server error" }, 500);
  }
});

function normalizePath(pathname: string): string {
  for (const prefix of ["/functions/v1/healthsync", "/healthsync"]) {
    if (pathname.startsWith(prefix)) {
      return pathname.slice(prefix.length) || "/";
    }
  }

  return pathname;
}

async function provisionWorkspace(req: Request): Promise<Response> {
  const payload = await jsonBody(req);
  const createdAt = new Date().toISOString();
  const workspaceId = randomToken("wk");
  const ingestToken = randomToken("hs_ingest");
  const agentToken = randomToken("hs_agent");

  await requireOk(
    db.from("workspaces").insert({
      id: workspaceId,
      created_at: createdAt,
      label: typeof payload.label === "string" ? payload.label : null,
    }),
  );
  await requireOk(
    db.from("access_tokens").insert([
      {
        id: randomToken("tok"),
        workspace_id: workspaceId,
        kind: "ingest",
        token_hash: await tokenHash(ingestToken),
        created_at: createdAt,
      },
      {
        id: randomToken("tok"),
        workspace_id: workspaceId,
        kind: "agent_read",
        token_hash: await tokenHash(agentToken),
        created_at: createdAt,
      },
    ]),
  );

  return json({
    workspace_id: workspaceId,
    backend_url: functionBaseUrl,
    ingest_token: ingestToken,
    agent_endpoint: `${functionBaseUrl}/api/agent/health-data`,
    agent_token: agentToken,
  });
}

async function ingestSync(req: Request): Promise<Response> {
  const auth = await requireToken(req, "ingest");
  const payload = await jsonBody(req);
  const now = new Date().toISOString();
  const deviceId = requiredString(payload.device_id, "device_id");
  const exportId = requiredString(payload.export_id, "export_id");
  const metrics = Array.isArray(payload.metrics) ? payload.metrics : [];
  const workouts = Array.isArray(payload.workouts) ? payload.workouts : [];
  const appVersion = req.headers.get("X-App-Version");

  await ensureWorkspace(auth.workspaceId, now);
  await upsertDevice(deviceId, now, appVersion);
  await upsertWorkspaceDevice(auth.workspaceId, deviceId, now);

  const duplicates = await countExistingRows(auth.workspaceId, deviceId, metrics, workouts);

  await requireOk(
    db.from("sync_batches").upsert(
      {
        workspace_id: auth.workspaceId,
        export_id: exportId,
        device_id: deviceId,
        generated_at: requiredString(payload.generated_at, "generated_at"),
        received_at: now,
        schema_version: Number(payload.schema_version ?? 1),
        timezone: requiredString(payload.timezone, "timezone"),
        source: requiredString(payload.source, "source"),
        date_range_start: requiredString(payload.date_range?.start, "date_range.start"),
        date_range_end: requiredString(payload.date_range?.end, "date_range.end"),
        metrics_count: metrics.length,
        workouts_count: workouts.length,
      },
      { onConflict: "workspace_id,export_id" },
    ),
  );

  if (metrics.length > 0) {
    await requireOk(
      db.from("health_metrics").upsert(
        metrics.map((metric: Record<string, unknown>) => ({
          workspace_id: auth.workspaceId,
          device_id: deviceId,
          id: requiredString(metric.id, "metrics.id"),
          type: requiredString(metric.type, "metrics.type"),
          value: Number(metric.value),
          unit: requiredString(metric.unit, "metrics.unit"),
          start_at: requiredString(metric.start_at, "metrics.start_at"),
          end_at: requiredString(metric.end_at, "metrics.end_at"),
          source_name: requiredString(metric.source_name, "metrics.source_name"),
          source_bundle_id: nullableString(metric.source_bundle_id),
          metadata: isRecord(metric.metadata) ? metric.metadata : {},
          export_id: exportId,
        })),
        { onConflict: "workspace_id,device_id,id" },
      ),
    );
  }

  if (workouts.length > 0) {
    await requireOk(
      db.from("health_workouts").upsert(
        workouts.map((workout: Record<string, unknown>) => ({
          workspace_id: auth.workspaceId,
          device_id: deviceId,
          id: requiredString(workout.id, "workouts.id"),
          activity_type: requiredString(workout.activity_type, "workouts.activity_type"),
          start_at: requiredString(workout.start_at, "workouts.start_at"),
          end_at: requiredString(workout.end_at, "workouts.end_at"),
          duration_seconds: Number(workout.duration_seconds),
          total_energy_kcal: nullableNumber(workout.total_energy_kcal),
          active_energy_kcal: nullableNumber(workout.active_energy_kcal),
          distance_meters: nullableNumber(workout.distance_meters),
          source_name: requiredString(workout.source_name, "workouts.source_name"),
          source_bundle_id: nullableString(workout.source_bundle_id),
          metadata: isRecord(workout.metadata) ? workout.metadata : {},
          export_id: exportId,
        })),
        { onConflict: "workspace_id,device_id,id" },
      ),
    );
  }

  return json({
    ok: true,
    received: metrics.length + workouts.length,
    duplicates,
    workspace_id: auth.workspaceId,
    export_id: exportId,
  });
}

async function agentHealthData(req: Request, url: URL): Promise<Response> {
  const auth = await requireToken(req, "agent_read");
  const range = readRange(url);
  const metricsPage = await listRows("health_metrics", auth.workspaceId, url, range);
  const workoutsPage = await listRows("health_workouts", auth.workspaceId, url, range);
  const syncsPage = await listRows("sync_batches", auth.workspaceId, url, range);
  const metrics = await enrichRows(metricsPage.items, "health_metrics");
  const workouts = await enrichRows(workoutsPage.items, "health_workouts");

  return json({
    agent_schema_version: 2,
    workspace_id: auth.workspaceId,
    range,
    page: {
      limit: metricsPage.page.limit,
      offset: metricsPage.page.offset,
      has_more: metricsPage.page.has_more || workoutsPage.page.has_more || syncsPage.page.has_more,
    },
    catalog: await agentCatalog(auth.workspaceId),
    metrics,
    workouts,
    syncs: syncsPage.items.map(syncRowToAgent),
    metric_daily_summaries: summarizeMetrics(metrics),
    workout_daily_summaries: summarizeWorkouts(workouts),
  });
}

async function agentList(req: Request, url: URL, table: string): Promise<Response> {
  const auth = await requireToken(req, "agent_read");
  const result = await listRows(table, auth.workspaceId, url, readRange(url));
  const items = table === "sync_batches" ? result.items.map(syncRowToAgent) : await enrichRows(result.items, table);
  return json({ items, page: result.page });
}

async function listRows(
  table: string,
  workspaceId: string,
  url: URL,
  range: RangeInfo,
): Promise<{ items: Record<string, unknown>[]; page: PageInfo }> {
  const limit = boundedInt(url.searchParams.get("limit"), 100, 1, 500);
  const offset = boundedInt(url.searchParams.get("offset"), 0, 0, 100000);
  const orderColumn = table === "sync_batches" ? "received_at" : "start_at";
  let query = db
    .from(table)
    .select("*")
    .eq("workspace_id", workspaceId)
    .order(orderColumn, { ascending: false });

  if (table === "health_metrics" && url.searchParams.has("type")) {
    query = query.eq("type", url.searchParams.get("type") ?? "");
  }
  if (table === "health_workouts" && url.searchParams.has("activity_type")) {
    query = query.eq("activity_type", url.searchParams.get("activity_type") ?? "");
  }
  if (table === "sync_batches" && url.searchParams.has("device_id")) {
    query = query.eq("device_id", url.searchParams.get("device_id") ?? "");
  }

  if (range.from) {
    query = table === "sync_batches" ? query.gte("date_range_end", range.from) : query.gte("start_at", range.from);
  }
  if (range.to) {
    query = table === "sync_batches" ? query.lte("date_range_start", range.to) : query.lte("end_at", range.to);
  }

  const { data, error } = await query.range(offset, offset + limit);
  if (error) {
    throw error;
  }

  const rows = (data ?? []) as Record<string, unknown>[];
  return {
    items: rows.slice(0, limit),
    page: { limit, offset, has_more: rows.length > limit },
  };
}

async function enrichRows(rows: Record<string, unknown>[], table: string): Promise<Record<string, unknown>[]> {
  if (rows.length === 0) {
    return [];
  }

  const exportIds = [...new Set(rows.map((row) => String(row.export_id)).filter(Boolean))];
  const workspaceId = String(rows[0].workspace_id);
  const { data, error } = await db
    .from("sync_batches")
    .select("workspace_id,export_id,timezone")
    .eq("workspace_id", workspaceId)
    .in("export_id", exportIds);
  if (error) {
    throw error;
  }

  const timezoneByExportId = new Map<string, string>();
  for (const batch of data ?? []) {
    timezoneByExportId.set(String(batch.export_id), String(batch.timezone ?? "UTC"));
  }

  return rows.map((row) => {
    const timezone = timezoneByExportId.get(String(row.export_id)) ?? "UTC";
    const startAt = String(row.start_at);
    return {
      id: row.id,
      device_id: row.device_id,
      ...(table === "health_metrics"
        ? {
            type: row.type,
            value: row.value,
            unit: row.unit,
          }
        : {
            activity_type: row.activity_type,
            duration_seconds: row.duration_seconds,
            total_energy_kcal: row.total_energy_kcal,
            active_energy_kcal: row.active_energy_kcal,
            distance_meters: row.distance_meters,
          }),
      start_at: row.start_at,
      end_at: row.end_at,
      timezone,
      local_date: localDateFor(startAt, timezone),
      source_name: row.source_name,
      source_bundle_id: row.source_bundle_id,
      metadata: row.metadata ?? {},
      export_id: row.export_id,
    };
  });
}

async function agentCatalog(workspaceId: string): Promise<Record<string, unknown>> {
  const [metrics, workouts, syncs, devices] = await Promise.all([
    db.from("health_metrics").select("type").eq("workspace_id", workspaceId).limit(5000),
    db.from("health_workouts").select("activity_type").eq("workspace_id", workspaceId).limit(5000),
    db.from("sync_batches").select("timezone").eq("workspace_id", workspaceId).limit(5000),
    db.from("workspace_devices").select("device_id,label").eq("workspace_id", workspaceId).order("device_id"),
  ]);
  for (const result of [metrics, workouts, syncs, devices]) {
    if (result.error) {
      throw result.error;
    }
  }

  return {
    metric_types: sortedUnique((metrics.data ?? []).map((row) => row.type)),
    activity_types: sortedUnique((workouts.data ?? []).map((row) => row.activity_type)),
    timezones: sortedUnique((syncs.data ?? []).map((row) => row.timezone)),
    devices: devices.data ?? [],
  };
}

function summarizeMetrics(items: Record<string, unknown>[]): Record<string, unknown>[] {
  const groups = new Map<string, number[]>();
  for (const item of items) {
    const key = `${item.local_date}\u0000${item.type}\u0000${item.unit}`;
    const values = groups.get(key) ?? [];
    values.push(Number(item.value));
    groups.set(key, values);
  }

  return [...groups.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, values]) => {
      const [localDate, type, unit] = key.split("\u0000");
      const total = values.reduce((sum, value) => sum + value, 0);
      return {
        local_date: localDate,
        type,
        unit,
        sample_count: values.length,
        total_value: total,
        average_value: total / values.length,
        minimum_value: Math.min(...values),
        maximum_value: Math.max(...values),
      };
    });
}

function syncRowToAgent(row: Record<string, unknown>): Record<string, unknown> {
  return {
    export_id: row.export_id,
    device_id: row.device_id,
    generated_at: row.generated_at,
    received_at: row.received_at,
    schema_version: row.schema_version,
    timezone: row.timezone,
    source: row.source,
    date_range_start: row.date_range_start,
    date_range_end: row.date_range_end,
    metrics_count: row.metrics_count,
    workouts_count: row.workouts_count,
  };
}

function summarizeWorkouts(items: Record<string, unknown>[]): Record<string, unknown>[] {
  const groups = new Map<string, Record<string, unknown>[]>();
  for (const item of items) {
    const key = `${item.local_date}\u0000${item.activity_type}`;
    const workouts = groups.get(key) ?? [];
    workouts.push(item);
    groups.set(key, workouts);
  }

  return [...groups.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, workouts]) => {
      const [localDate, activityType] = key.split("\u0000");
      const distanceMeters = workouts.map((row) => nullableNumber(row.distance_meters)).filter(isNumber);
      const totalEnergy = workouts.map((row) => nullableNumber(row.total_energy_kcal)).filter(isNumber);
      const activeEnergy = workouts.map((row) => nullableNumber(row.active_energy_kcal)).filter(isNumber);
      return {
        local_date: localDate,
        activity_type: activityType,
        workout_count: workouts.length,
        duration_minutes: workouts.reduce((sum, row) => sum + Number(row.duration_seconds), 0) / 60,
        distance_km: distanceMeters.length > 0 ? sum(distanceMeters) / 1000 : null,
        total_energy_kcal: totalEnergy.length > 0 ? sum(totalEnergy) : null,
        active_energy_kcal: activeEnergy.length > 0 ? sum(activeEnergy) : null,
      };
    });
}

async function requireToken(req: Request, kind: TokenKind): Promise<AuthContext> {
  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice("Bearer ".length).trim() : "";
  if (!token) {
    throw new HttpError(401, "Missing bearer token");
  }

  const hash = await tokenHash(token);
  const { data, error } = await db
    .from("access_tokens")
    .select("workspace_id,kind,revoked_at")
    .eq("token_hash", hash)
    .eq("kind", kind)
    .maybeSingle();
  if (error) {
    throw error;
  }
  if (!data || data.revoked_at) {
    throw new HttpError(403, "Invalid bearer token");
  }

  await requireOk(db.from("access_tokens").update({ last_used_at: new Date().toISOString() }).eq("token_hash", hash));
  return { workspaceId: data.workspace_id };
}

async function ensureWorkspace(workspaceId: string, now: string): Promise<void> {
  await requireOk(
    db.from("workspaces").upsert(
      { id: workspaceId, created_at: now, label: null },
      { onConflict: "id", ignoreDuplicates: true },
    ),
  );
}

async function upsertDevice(deviceId: string, now: string, appVersion: string | null): Promise<void> {
  const { data, error } = await db.from("devices").select("device_id").eq("device_id", deviceId).maybeSingle();
  if (error) {
    throw error;
  }

  if (data) {
    await requireOk(
      db
        .from("devices")
        .update({ last_seen_at: now, app_version: appVersion })
        .eq("device_id", deviceId),
    );
    return;
  }

  await requireOk(
    db.from("devices").insert({
      device_id: deviceId,
      first_seen_at: now,
      last_seen_at: now,
      app_version: appVersion,
    }),
  );
}

async function upsertWorkspaceDevice(workspaceId: string, deviceId: string, now: string): Promise<void> {
  await requireOk(
    db.from("workspace_devices").upsert(
      {
        workspace_id: workspaceId,
        device_id: deviceId,
        created_at: now,
        last_seen_at: now,
      },
      { onConflict: "workspace_id,device_id" },
    ),
  );
}

async function countExistingRows(
  workspaceId: string,
  deviceId: string,
  metrics: Record<string, unknown>[],
  workouts: Record<string, unknown>[],
): Promise<number> {
  const metricIds = metrics.map((metric) => String(metric.id)).filter(Boolean);
  const workoutIds = workouts.map((workout) => String(workout.id)).filter(Boolean);
  const [metricRows, workoutRows] = await Promise.all([
    metricIds.length > 0
      ? db
          .from("health_metrics")
          .select("id")
          .eq("workspace_id", workspaceId)
          .eq("device_id", deviceId)
          .in("id", metricIds)
      : Promise.resolve({ data: [], error: null }),
    workoutIds.length > 0
      ? db
          .from("health_workouts")
          .select("id")
          .eq("workspace_id", workspaceId)
          .eq("device_id", deviceId)
          .in("id", workoutIds)
      : Promise.resolve({ data: [], error: null }),
  ]);
  if (metricRows.error) {
    throw metricRows.error;
  }
  if (workoutRows.error) {
    throw workoutRows.error;
  }

  return (metricRows.data?.length ?? 0) + (workoutRows.data?.length ?? 0);
}

function readRange(url: URL): RangeInfo {
  return {
    from: url.searchParams.get("from"),
    to: url.searchParams.get("to"),
  };
}

function boundedInt(value: string | null, fallback: number, min: number, max: number): number {
  const parsed = value === null ? fallback : Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.min(max, Math.max(min, parsed));
}

function localDateFor(value: string, timezone: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value.slice(0, 10);
  }

  try {
    const formatter = new Intl.DateTimeFormat("en", {
      timeZone: timezone || "UTC",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    const parts = Object.fromEntries(formatter.formatToParts(date).map((part) => [part.type, part.value]));
    return `${parts.year}-${parts.month}-${parts.day}`;
  } catch {
    return localDateFor(value, "UTC");
  }
}

function randomToken(prefix: string): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return `${prefix}_${base64Url(bytes)}`;
}

async function tokenHash(token: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(tokenHashSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(token));
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function jsonBody(req: Request): Promise<Record<string, unknown>> {
  const payload = await req.json();
  if (!isRecord(payload)) {
    throw new HttpError(400, "Expected JSON object");
  }

  return payload;
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

async function requireOk<T>(promise: PromiseLike<{ error: unknown }>): Promise<T | null> {
  const result = await promise;
  if (result.error) {
    throw result.error;
  }

  return result as T;
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim() === "") {
    throw new HttpError(400, `Missing ${field}`);
  }

  return value;
}

function nullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function nullableNumber(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null;
  }

  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNumber(value: number | null): value is number {
  return typeof value === "number";
}

function sum(values: number[]): number {
  return values.reduce((total, value) => total + value, 0);
}

function sortedUnique(values: unknown[]): string[] {
  return [...new Set(values.map((value) => String(value)).filter(Boolean))].sort();
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}
