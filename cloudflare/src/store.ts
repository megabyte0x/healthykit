import { SourceCollation } from './collation';
import { LocalDates, Summaries } from './summaries';
export type Row = Record<string, any>;
export type Kind = 'ingest' | 'agent_read';
export type Table = 'health_metrics' | 'health_workouts' | 'sync_batches';
export type Auth = {
    hash: string;
    kind: Kind;
    workspaceId: string;
};
export class HttpError extends Error {
    constructor(public status: number, message: string) { super(message); }
}
export const capacity = { requestBytes: 8 * 1024 * 1024, requestItems: 10000, responseBytes: 8 * 1024 * 1024, pageRows: 5000, tieKeys: 150000, tieBytes: 16 * 1024 * 1024, groups: 50000, groupBytes: 8 * 1024 * 1024, devices: 10000, statements: 1000 };
export function timestamp(value: unknown): string {
    if (typeof value !== 'string')
        throw new HttpError(400, 'Invalid timestamp');
    const match = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}:\d{2})$/.exec(value);
    if (!match)
        throw new HttpError(400, 'Unsupported timestamp syntax');
    const local = new Date(`${match[1]}T${match[2]}Z`);
    if (Number.isNaN(local.getTime()) || local.toISOString().slice(0, 19) !== `${match[1]}T${match[2]}` || match[1].startsWith('0000'))
        throw new HttpError(400, 'Invalid timestamp');
    const whole = new Date(`${match[1]}T${match[2]}${match[4]}`);
    if (Number.isNaN(whole.getTime()))
        throw new HttpError(400, 'Invalid timestamp');
    return whole.toISOString().slice(0, 19) + '.' + (match[3] ?? '').padEnd(6, '0') + 'Z';
}
export function wireTimestamp(value: string) { return value.replace(/(\.\d*?[1-9])0+Z$/, '$1Z').replace(/\.0+Z$/, 'Z').replace(/Z$/, '+00:00'); }
export function now() { return timestamp(new Date().toISOString()); }
export function required(value: unknown, field: string): string { if (typeof value !== 'string' || !value.trim())
    throw new HttpError(400, `Missing ${field}`); return value; }
export function record(value: unknown): value is Row { return typeof value === 'object' && value !== null && !Array.isArray(value); }
export function nullableNumber(value: unknown) { if (value === undefined || value === null)
    return null; const n = Number(value); return Number.isFinite(n) ? n : null; }
function postgresUnicode(value: unknown): void {
    if (typeof value === 'string') {
        if (/[\uD800-\uDFFF]/u.test(value)) throw new HttpError(500, 'Internal server error');
    } else if (Array.isArray(value)) {
        for (const item of value) postgresUnicode(item);
    } else if (record(value)) {
        for (const [key, item] of Object.entries(value)) {
            postgresUnicode(key);
            postgresUnicode(item);
        }
    }
}
function postgresMetadata(value: unknown): string {
    const metadata = record(value) ? value : {};
    // JSON.stringify preserves lone surrogates as escapes that PostgreSQL JSONB rejects.
    postgresUnicode(metadata);
    return JSON.stringify(metadata);
}
const encoder = new TextEncoder();
export const byteLength = (value: unknown) => encoder.encode(JSON.stringify(value)).length;
const chunks = <T>(rows: T[], size: number): T[][] => Array.from({ length: Math.ceil(rows.length / size) }, (_, i) => rows.slice(i * size, (i + 1) * size));
const placeholders = (n: number) => Array(n).fill('?').join(',');
const identity = (row: Row) => JSON.stringify('id' in row ? [row.device_id, row.id] : [row.export_id]);
export class Store {
    readonly collation = new SourceCollation();
    readonly dates = new LocalDates();
    readonly stats = { statements: 0, rowsRead: 0, rowsWritten: 0, maxBindings: 0, maxPageBytes: 0, summaryRows: 0, summaryGroups: 0, summaryKeyBytes: 0, maxTieKeys: 0, maxTieBytes: 0, responseBytes: 0, durationMs: 0 };
    private started = Date.now();
    constructor(private db: D1Database) { }
    statement(sql: string, values: unknown[] = []): D1PreparedStatement {
        if (values.length > 100)
            throw new Error('Binding capacity exceeded');
        for (const value of values) postgresUnicode(value);
        this.stats.maxBindings = Math.max(this.stats.maxBindings, values.length);
        return this.db.prepare(sql).bind(...values);
    }
    private async batch(statements: D1PreparedStatement[]): Promise<D1Result<Row>[]> {
        this.stats.statements += statements.length;
        if (this.stats.statements > capacity.statements)
            throw new HttpError(503, 'Request query capacity exceeded');
        const results = await this.db.batch<Row>(statements);
        for (const r of results) {
            this.stats.rowsRead += r.meta.rows_read ?? 0;
            this.stats.rowsWritten += r.meta.rows_written ?? 0;
        }
        return results;
    }
    private guard(auth: Auth) {
        // A failed SQL expression aborts the entire D1 batch, including earlier writes.
        return this.statement("SELECT CASE WHEN EXISTS(SELECT 1 FROM access_tokens WHERE token_hash=? AND kind=? AND workspace_id=? AND revoked_at IS NULL) THEN 1 ELSE json('invalid authorization') END AS authorized", [auth.hash, auth.kind, auth.workspaceId]);
    }
    async authenticate(hash: string, kind: Kind): Promise<Auth> {
        const rows = await this.batch([this.statement('SELECT workspace_id FROM access_tokens WHERE token_hash=? AND kind=? AND revoked_at IS NULL', [hash, kind])]);
        if (!rows[0].results.length)
            throw new HttpError(403, 'Invalid bearer token');
        const auth = { hash, kind, workspaceId: rows[0].results[0].workspace_id };
        await this.mutate(auth, [this.statement('UPDATE access_tokens SET last_used_at=? WHERE token_hash=?', [now(), hash])]);
        return auth;
    }
    async recheck(auth: Auth) {
        const result = await this.batch([this.statement('SELECT 1 FROM access_tokens WHERE token_hash=? AND kind=? AND workspace_id=? AND revoked_at IS NULL', [auth.hash, auth.kind, auth.workspaceId])]);
        if (!result[0].results.length)
            throw new HttpError(403, 'Invalid bearer token');
    }
    private async mutate(auth: Auth, statements: D1PreparedStatement[]) {
        try {
            return (await this.batch([this.guard(auth), ...statements])).slice(1);
        }
        catch (error) {
            await this.recheck(auth);
            throw error;
        }
    }
    private async read(auth: Auth, sql: string, values: unknown[] = []): Promise<Row[]> {
        const result = await this.mutate(auth, [this.statement(sql, values)]);
        const rows = result[0].results;
        const bytes = byteLength(rows);
        this.stats.maxPageBytes = Math.max(this.stats.maxPageBytes, bytes);
        if (bytes > capacity.responseBytes)
            throw new HttpError(503, 'Result capacity exceeded; narrow the requested range');
        return rows;
    }
    async health() { await this.batch([this.statement('SELECT 1 FROM workspaces LIMIT 1')]); }
    private upsert(table: string, row: Row, keys: string[], ignore = false) {
        const columns = Object.keys(row), updates = columns.filter(c => !keys.includes(c));
        return this.statement(`INSERT INTO ${table} (${columns.join(',')}) VALUES (${placeholders(columns.length)}) ON CONFLICT (${keys.join(',')}) DO ${ignore ? 'NOTHING' : `UPDATE SET ${updates.map(c => `${c}=excluded.${c}`).join(',')}`}`, Object.values(row));
    }
    async provision(workspace: Row, tokens: Row[], oldAuth?: Auth) {
        const statements = [];
        if (oldAuth)
            statements.push(this.statement('DELETE FROM workspaces WHERE id=?', [oldAuth.workspaceId]));
        statements.push(this.upsert('workspaces', workspace, ['id']), ...tokens.map(t => this.upsert('access_tokens', t, ['id'])));
        if (oldAuth)
            await this.mutate(oldAuth, statements);
        else
            await this.batch(statements);
    }
    async rotate(auth: Auth, token: Row) {
        await this.mutate(auth, [this.upsert('access_tokens', token, ['id']), this.statement("UPDATE access_tokens SET revoked_at=? WHERE workspace_id=? AND kind='agent_read' AND revoked_at IS NULL AND id<>?", [token.created_at, auth.workspaceId, token.id])]);
    }
    async ingest(auth: Auth, payload: Row, appVersion: string | null) {
        const at = now(), workspace_id = auth.workspaceId, device_id = required(payload.device_id, 'device_id'), export_id = required(payload.export_id, 'export_id');
        const metrics: Row[] = Array.isArray(payload.metrics) ? payload.metrics : [], workouts: Row[] = Array.isArray(payload.workouts) ? payload.workouts : [];
        if (payload.deletions !== undefined && !Array.isArray(payload.deletions))
            throw new HttpError(400, 'Expected deletions array');
        const deletions: Row[] = (payload.deletions ?? []).map((item: unknown, index: number) => {
            if (!record(item))
                throw new HttpError(400, `Expected deletions[${index}] object`);
            const id = required(item.id, `deletions[${index}].id`), kind = required(item.kind, `deletions[${index}].kind`);
            if (kind !== 'metric' && kind !== 'workout')
                throw new HttpError(400, `Invalid deletions[${index}].kind`);
            return { id, kind };
        });
        if (metrics.length + workouts.length + deletions.length > capacity.requestItems)
            throw new HttpError(413, 'Too many records');
        const statements = [this.statement('INSERT INTO devices(device_id,first_seen_at,last_seen_at,app_version) VALUES(?,?,?,?) ON CONFLICT(device_id) DO UPDATE SET last_seen_at=excluded.last_seen_at,app_version=excluded.app_version', [device_id, at, at, appVersion]), this.statement('INSERT INTO workspace_devices(workspace_id,device_id,created_at,last_seen_at) VALUES(?,?,?,?) ON CONFLICT(workspace_id,device_id) DO UPDATE SET created_at=excluded.created_at,last_seen_at=excluded.last_seen_at', [workspace_id, device_id, at, at])];
        const deletedIndexes: number[] = [], duplicateIndexes: number[] = [];
        if (metrics.length || workouts.length || deletions.length) {
            const schema_version = Number(payload.schema_version ?? 1);
            if (!Number.isInteger(schema_version) || schema_version < -2147483648 || schema_version > 2147483647)
                throw new HttpError(500, 'Internal server error');
            for (const [kind, table] of [['metric', 'health_metrics'], ['workout', 'health_workouts']]) {
                const ids = [...new Set<string>(deletions.filter(d => d.kind === kind).map(d => d.id))];
                for (const part of chunks(ids, 98)) {
                    deletedIndexes.push(statements.length);
                    statements.push(this.statement(`DELETE FROM ${table} WHERE workspace_id=? AND device_id=? AND id IN (${placeholders(part.length)})`, [workspace_id, device_id, ...part]));
                }
            }
            for (const [table, rows] of [['health_metrics', metrics], ['health_workouts', workouts]] as const) {
                // The source counts distinct IDs separately in each original 100-item chunk.
                for (const original of chunks(rows.map(r => String(r.id)).filter(Boolean), 100))
                    for (const part of chunks([...new Set(original)], 98)) {
                        duplicateIndexes.push(statements.length);
                        statements.push(this.statement(`SELECT count(*) AS n FROM ${table} WHERE workspace_id=? AND device_id=? AND id IN (${placeholders(part.length)})`, [workspace_id, device_id, ...part]));
                    }
            }
            statements.push(this.upsert('sync_batches', { workspace_id, export_id, device_id, generated_at: timestamp(required(payload.generated_at, 'generated_at')), received_at: at, schema_version, timezone: required(payload.timezone, 'timezone'), source: required(payload.source, 'source'), date_range_start: timestamp(required(payload.date_range?.start, 'date_range.start')), date_range_end: timestamp(required(payload.date_range?.end, 'date_range.end')), metrics_count: metrics.length, workouts_count: workouts.length }, ['workspace_id', 'export_id']));
            for (const [table, rows, kind] of [['health_metrics', metrics, 'metrics'], ['health_workouts', workouts, 'workouts']] as const) {
                for (const original of chunks(rows, 100)) {
                    if (new Set(original.map(r => r.id)).size !== original.length)
                        throw new HttpError(500, 'Internal server error');
                    for (const row of original) {
                        const base = { workspace_id, device_id, id: required(row.id, `${kind}.id`), start_at: timestamp(required(row.start_at, `${kind}.start_at`)), end_at: timestamp(required(row.end_at, `${kind}.end_at`)), source_name: required(row.source_name, `${kind}.source_name`), source_bundle_id: typeof row.source_bundle_id === 'string' ? row.source_bundle_id : null, metadata: postgresMetadata(row.metadata), export_id };
                        const details = table === 'health_metrics' ? { type: required(row.type, 'metrics.type'), value: Number(row.value), unit: required(row.unit, 'metrics.unit') } : { activity_type: required(row.activity_type, 'workouts.activity_type'), duration_seconds: Number(row.duration_seconds), total_energy_kcal: nullableNumber(row.total_energy_kcal), active_energy_kcal: nullableNumber(row.active_energy_kcal), distance_meters: nullableNumber(row.distance_meters) };
                        statements.push(this.upsert(table, { ...base, ...details }, ['workspace_id', 'device_id', 'id']));
                    }
                }
            }
        }
        const results = await this.mutate(auth, statements);
        return { ok: true, received: metrics.length + workouts.length, duplicates: duplicateIndexes.reduce((n, i) => n + Number(results[i].results[0].n), 0), deleted: deletedIndexes.reduce((n, i) => n + results[i].meta.changes, 0), workspace_id, export_id };
    }
    private filter(table: Table, auth: Auth, url: URL) {
        const clauses = ['r.workspace_id=?'], values: unknown[] = [auth.workspaceId];
        const field = table === 'health_metrics' ? 'type' : table === 'health_workouts' ? 'activity_type' : 'device_id';
        if (url.searchParams.has(field)) {
            clauses.push(`r.${field}=?`);
            values.push(url.searchParams.get(field));
        }
        for (const [parameter, column, op] of [['from', table === 'sync_batches' ? 'date_range_end' : 'start_at', '>='], ['to', table === 'sync_batches' ? 'date_range_start' : 'end_at', '<=']]) {
            const value = url.searchParams.get(parameter);
            if (value) {
                clauses.push(`r.${column}${op}?`);
                values.push(timestamp(/^\d{4}-\d{2}-\d{2}$/.test(value) ? value + 'T00:00:00Z' : value));
            }
        }
        return { sql: clauses.join(' AND '), values };
    }
    private order(table: Table) { return table === 'sync_batches' ? { stamp: 'received_at', keys: ['export_id'] } : { stamp: 'start_at', keys: ['device_id', 'id'] }; }
    private async selectKeys(table: Table, auth: Auth, url: URL, limit: number, offset: number) {
        const f = this.filter(table, auth, url), o = this.order(table), columns = [o.stamp, ...o.keys].map(c => 'r.' + c).join(','), sort = `r.${o.stamp} DESC,${o.keys.map(k => 'r.' + k + ' COLLATE BINARY').join(',')}`;
        const window = await this.read(auth, `SELECT ${columns} FROM ${table} r WHERE ${f.sql} ORDER BY ${sort} LIMIT ? OFFSET ?`, [...f.values, limit + 1, offset]);
        if (!window.length)
            return [];
        const stamps = [...new Set<string>(window.map(r => r[o.stamp]))], selected: Row[] = [];
        for (let index = 0; index < stamps.length; index++) {
            const stamp = stamps[index];
            if (index !== 0 && index !== stamps.length - 1) {
                selected.push(...window.filter(r => r[o.stamp] === stamp).sort(this.collation.key));
                continue;
            }
            const [counts] = await this.read(auth, `SELECT (SELECT count(*) FROM ${table} r WHERE ${f.sql} AND r.${o.stamp}>?) before_count,(SELECT count(*) FROM ${table} r WHERE ${f.sql} AND r.${o.stamp}=?) tie_count`, [...f.values, stamp, ...f.values, stamp]);
            const before = Number(counts.before_count), count = Number(counts.tie_count);
            if (count > capacity.tieKeys)
                throw new HttpError(503, 'Ordering capacity exceeded; narrow the requested range');
            const group: Row[] = [];
            let cursor: Row | undefined, bytes = 0;
            do {
                const cursorSql = cursor ? (o.keys.length === 1 ? ' AND r.export_id COLLATE BINARY>?' : ' AND (r.device_id,r.id)>(?,?)') : '';
                const cursorValues = cursor ? (o.keys.length === 1 ? [cursor.export_id] : [cursor.device_id, cursor.id]) : [];
                const page = await this.read(auth, `SELECT ${columns} FROM ${table} r WHERE ${f.sql} AND r.${o.stamp}=?${cursorSql} ORDER BY ${o.keys.map(k => 'r.' + k + ' COLLATE BINARY').join(',')} LIMIT ?`, [...f.values, stamp, ...cursorValues, capacity.pageRows]);
                bytes += byteLength(page);
                if (bytes > capacity.tieBytes || group.length + page.length > capacity.tieKeys)
                    throw new HttpError(503, 'Ordering capacity exceeded; narrow the requested range');
                group.push(...page);
                if (page.length < capacity.pageRows)
                    break;
                cursor = page[page.length - 1];
            } while (true);
            if (group.length !== count)
                throw new HttpError(503, 'Data changed during pagination; retry');
            this.stats.maxTieKeys = Math.max(this.stats.maxTieKeys, group.length);
            this.stats.maxTieBytes = Math.max(this.stats.maxTieBytes, bytes);
            group.sort(this.collation.key);
            selected.push(...group.slice(Math.max(0, offset - before), Math.min(count, offset + limit + 1 - before)));
        }
        return selected;
    }
    private join(table: Table) { return table === 'sync_batches' ? '' : ` JOIN sync_batches s ON s.workspace_id=r.workspace_id AND s.export_id=r.export_id`; }
    async list(table: Table, auth: Auth, url: URL) {
        const integer = (key: string, fallback: number, min: number, max: number) => { const value = url.searchParams.get(key); const parsed = value === null ? fallback : parseInt(value, 10); return Number.isFinite(parsed) ? Math.min(max, Math.max(min, parsed)) : fallback; };
        const limit = integer('limit', 100, 1, 500), offset = integer('offset', 0, 0, 100000), keys = await this.selectKeys(table, auth, url, limit, offset), f = this.filter(table, auth, url), o = this.order(table), items: Row[] = [];
        const pageKeys = keys.slice(0, limit), chunkSize = Math.floor((100 - f.values.length) / o.keys.length);
        for (const part of chunks(pageKeys, chunkSize)) {
            const selected = part.map(() => `(${placeholders(o.keys.length)})`).join(',');
            const predicates = o.keys.map(k => `r.${k}=selected.${k}`).join(' AND ');
            const rows = await this.read(auth, `WITH selected(${o.keys.join(',')}) AS (VALUES ${selected}) SELECT r.*${table === 'sync_batches' ? '' : ',s.timezone'} FROM selected CROSS JOIN ${table} r${this.join(table)} WHERE ${f.sql} AND ${predicates}`, [...part.flatMap(key => o.keys.map(k => key[k])), ...f.values]);
            items.push(...rows);
        }
        const byKey = new Map(items.map(row => [identity(row), row]));
        if (pageKeys.some(key => byKey.get(identity(key))?.[o.stamp] !== key[o.stamp]))
            throw new HttpError(503, 'Data changed during pagination; retry');
        const confirmation = await this.selectKeys(table, auth, url, limit, offset);
        if (JSON.stringify(keys) !== JSON.stringify(confirmation))
            throw new HttpError(503, 'Data changed during pagination; retry');
        return { items: pageKeys.map(key => this.toAgent(byKey.get(identity(key))!, table)), page: { limit, offset, has_more: keys.length > limit } };
    }
    private toAgent(row: Row, table: Table): Row {
        const result = { ...row };
        delete result.workspace_id;
        for (const field of ['start_at', 'end_at', 'generated_at', 'received_at', 'date_range_start', 'date_range_end'])
            if (result[field])
                result[field] = wireTimestamp(result[field]);
        if (table !== 'sync_batches') {
            result.metadata = JSON.parse(result.metadata ?? '{}');
            result.local_date = this.dates.get(row.start_at, row.timezone);
        }
        return result;
    }
    async catalog(auth: Auth) {
        const unique = async (table: string, column: string) => ([...new Set<string>((await this.read(auth, `SELECT ${column} value FROM ${table} WHERE workspace_id=? LIMIT 5000`, [auth.workspaceId])).map(r => String(r.value)).filter(Boolean))]).sort();
        const metric_types = await unique('health_metrics', 'type'), activity_types = await unique('health_workouts', 'activity_type'), timezones = await unique('sync_batches', 'timezone');
        const devices = await this.read(auth, 'SELECT device_id,label FROM workspace_devices WHERE workspace_id=? LIMIT ?', [auth.workspaceId, capacity.devices + 1]);
        if (devices.length > capacity.devices)
            throw new HttpError(503, 'Device catalog capacity exceeded');
        devices.sort((a, b) => this.collation.compare(a.device_id, b.device_id));
        return { metric_types, activity_types, timezones, devices };
    }
    async summaries(auth: Auth, url: URL) {
        const summary = new Summaries(this.dates, capacity.groups, capacity.groupBytes, this.collation);
        for (const table of ['health_metrics', 'health_workouts'] as const) {
            const f = this.filter(table, auth, url);
            let cursor: Row | undefined;
            const projection = table === 'health_metrics' ? "r.type,r.unit,r.value,CASE WHEN json_type(r.metadata)='object' AND json_extract(r.metadata,'$.aggregation') IN ('daily_sum','daily_average') THEN 1 ELSE 0 END preferred" : 'r.activity_type,r.duration_seconds,r.distance_meters,r.total_energy_kcal,r.active_energy_kcal';
            do {
                const predicate = cursor ? ' AND r.start_at<=? AND (r.start_at<? OR (r.device_id,r.id)>(?,?))' : '';
                const values = cursor ? [cursor.start_at, cursor.start_at, cursor.device_id, cursor.id] : [];
                const rows = await this.read(auth, `SELECT r.start_at,r.device_id,r.id,s.timezone,${projection} FROM ${table} r${this.join(table)} WHERE ${f.sql}${predicate} ORDER BY r.start_at DESC,r.device_id COLLATE BINARY,r.id COLLATE BINARY LIMIT ?`, [...f.values, ...values, capacity.pageRows]);
                this.stats.summaryRows += rows.length;
                for (const row of rows)
                    if (table === 'health_metrics')
                        summary.metric(row);
                    else
                        summary.workout(row);
                if (rows.length < capacity.pageRows)
                    break;
                cursor = rows[rows.length - 1];
            } while (true);
        }
        this.stats.summaryGroups = summary.groupCount;
        this.stats.summaryKeyBytes = summary.groupKeyBytes;
        return summary.finish();
    }
    finish(responseBytes: number) { this.stats.responseBytes = responseBytes; this.stats.durationMs = Date.now() - this.started; return this.stats; }
}
