import { NextResponse } from "next/server";
import {
  normalizeAccessRequestPayload,
  validateAccessRequest,
  type AccessRequestInput
} from "@/lib/access-requests";
import {
  getRequestStorageMode,
  listAccessRequests,
  persistAccessRequest,
  type StoredAccessRequest
} from "@/lib/access-request-store";

export const runtime = "nodejs";

type RateLimitBucket = {
  count: number;
  resetAt: number;
};

const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 5;
const rateLimitBuckets = new Map<string, RateLimitBucket>();

function jsonResponse(body: unknown, init?: ResponseInit) {
  return NextResponse.json(body, {
    ...init,
    headers: {
      "Cache-Control": "no-store",
      ...init?.headers
    }
  });
}

function getClientIp(request: Request) {
  const forwardedFor = request.headers.get("x-forwarded-for");
  if (forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() || "unknown";
  }

  return request.headers.get("x-real-ip") ?? "unknown";
}

function checkRateLimit(key: string) {
  const now = Date.now();
  const current = rateLimitBuckets.get(key);

  if (!current || current.resetAt <= now) {
    rateLimitBuckets.set(key, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return { ok: true as const };
  }

  if (current.count >= RATE_LIMIT_MAX_REQUESTS) {
    return {
      ok: false as const,
      retryAfter: Math.ceil((current.resetAt - now) / 1000)
    };
  }

  current.count += 1;
  return { ok: true as const };
}

function isSuspiciousSubmission(input: AccessRequestInput) {
  if (input.company) {
    return true;
  }

  if (!input.startedAt) {
    return false;
  }

  const startedAt = Date.parse(input.startedAt);
  if (!Number.isFinite(startedAt)) {
    return true;
  }

  return Date.now() - startedAt < 800;
}

function makeStoredRequest(
  value: Omit<StoredAccessRequest, "id" | "createdAt" | "userAgent">,
  request: Request
): StoredAccessRequest {
  return {
    ...value,
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    userAgent: request.headers.get("user-agent")?.slice(0, 240) || undefined
  };
}

function isAuthorizedAdminRequest(request: Request) {
  const adminToken = process.env.TESTFLIGHT_ADMIN_TOKEN?.trim();
  if (!adminToken) {
    return false;
  }

  const authorization = request.headers.get("authorization");
  return authorization === `Bearer ${adminToken}`;
}

export async function POST(request: Request) {
  let payload: unknown;

  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ message: "Send a JSON request body." }, { status: 400 });
  }

  const normalized = normalizeAccessRequestPayload(payload);

  if (isSuspiciousSubmission(normalized)) {
    return jsonResponse(
      { delivery: "filtered", id: crypto.randomUUID(), message: "Request received." },
      { status: 201 }
    );
  }

  const validation = validateAccessRequest(normalized);

  if (!validation.ok) {
    return jsonResponse({ errors: validation.errors }, { status: 422 });
  }

  const rateLimit = checkRateLimit(`${getClientIp(request)}:${validation.value.email}`);
  if (!rateLimit.ok) {
    return jsonResponse(
      { message: "Too many requests. Please try again later." },
      {
        status: 429,
        headers: {
          "Retry-After": String(rateLimit.retryAfter)
        }
      }
    );
  }

  const accessRequest = makeStoredRequest(validation.value, request);

  try {
    const delivery = await persistAccessRequest(accessRequest);
    return jsonResponse(
      { delivery, id: accessRequest.id, message: "Request received." },
      { status: 201 }
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to save request.";
    return jsonResponse({ message }, { status: 502 });
  }
}

export async function GET(request: Request) {
  if (!isAuthorizedAdminRequest(request)) {
    return jsonResponse({ message: "Not found." }, { status: 404 });
  }

  try {
    const requests = await listAccessRequests();
    requests.sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    const url = new URL(request.url);
    if (url.searchParams.get("format") === "jsonl") {
      return new Response(requests.map((item) => JSON.stringify(item)).join("\n"), {
        headers: {
          "Cache-Control": "no-store",
          "Content-Type": "application/x-ndjson; charset=utf-8"
        }
      });
    }

    return jsonResponse({
      count: requests.length,
      requests,
      storage: getRequestStorageMode()
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to list requests.";
    return jsonResponse({ message }, { status: 502 });
  }
}
