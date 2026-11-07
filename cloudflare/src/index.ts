import { Store, HttpError, capacity, now, record, type Auth, type Kind, type Row, type Table } from './store';
type WorkerEnv = {
    DB: D1Database;
    TOKEN_HASH_SECRET?: string;
    HOSTED_PUBLIC_BASE_URL?: string;
    MIGRATION_STATE?: string;
};
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-app-version, x-device-id', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };
const encoder = new TextEncoder();
function json(payload: unknown, status = 200) {
    const body = JSON.stringify(payload);
    if (encoder.encode(body).length > capacity.responseBytes)
        throw new HttpError(503, 'Result capacity exceeded; narrow the requested range');
    return new Response(body, { status, headers: { ...cors, 'Content-Type': 'application/json', ...(status === 503 ? { 'Retry-After': '5' } : {}) } });
}
async function jsonBody(request: Request): Promise<Row> {
    const reader = request.body?.getReader();
    const parts: Uint8Array[] = [];
    let bytes = 0;
    if (reader)
        try {
            while (true) {
                const result = await reader.read();
                if (result.done)
                    break;
                bytes += result.value.byteLength;
                if (bytes > capacity.requestBytes) {
                    await reader.cancel();
                    throw new HttpError(413, 'Request body too large');
                }
                parts.push(result.value);
            }
        }
        finally {
            reader.releaseLock();
        }
    const input = new Uint8Array(bytes);
    let offset = 0;
    for (const part of parts) {
        input.set(part, offset);
        offset += part.byteLength;
    }
    let payload: unknown;
    try {
        payload = JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(input));
    }
    catch {
        throw new HttpError(400, 'Invalid JSON body');
    }
    if (!record(payload))
        throw new HttpError(400, 'Expected JSON object');
    return payload;
}
function randomToken(prefix: string) { const bytes = crypto.getRandomValues(new Uint8Array(32)); return prefix + '_' + btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', ''); }
async function tokenHash(token: string, secret: string) { const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']); return [...new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(token)))].map(b => b.toString(16).padStart(2, '0')).join(''); }
function normalizePath(path: string) { for (const prefix of ['/functions/v1/healthsync', '/healthsync'])
    if (path.startsWith(prefix))
        return path.slice(prefix.length) || '/'; return path; }
export default {
    async fetch(request: Request, env: WorkerEnv, _ctx: ExecutionContext): Promise<Response> {
        if (request.method === 'OPTIONS')
            return new Response(null, { status: 204, headers: cors });
        const store = new Store(env.DB);
        let route = 'unknown';
        try {
            const url = new URL(request.url), path = normalizePath(url.pathname);
            if (path === '/health' && request.method === 'GET') {
                route = 'health';
                let database = false;
                try {
                    database = await store.health();
                }
                catch { }
                const active = env.MIGRATION_STATE === 'active', ready = database && active && !!env.TOKEN_HASH_SECRET;
                return json({ ok: ready, ready, database, migration_state: active ? 'active' : 'locked' }, ready ? 200 : 503);
            }
            if (env.MIGRATION_STATE !== 'active')
                throw new HttpError(503, 'Migration in progress; retry later');
            if (!env.TOKEN_HASH_SECRET)
                throw new HttpError(503, 'Service is not ready');
            const secret = env.TOKEN_HASH_SECRET, base = (env.HOSTED_PUBLIC_BASE_URL ?? 'https://api.healthysync.app').replace(/\/$/, '');
            const authenticate = async (kind: Kind) => {
                const authorization = request.headers.get('Authorization') ?? '', token = authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : '';
                if (!token)
                    throw new HttpError(401, 'Missing bearer token');
                return store.authenticate(await tokenHash(token, secret), kind);
            };
            const create = async (payload: Row, oldAuth?: Auth) => {
                const at = now(), workspace_id = randomToken('wk'), ingest_token = randomToken('hs_ingest'), agent_token = randomToken('hs_agent');
                const tokens = await Promise.all(([['ingest', ingest_token], ['agent_read', agent_token]] as const).map(async ([kind, token]) => ({ id: randomToken('tok'), workspace_id, kind, token_hash: await tokenHash(token, secret), created_at: at })));
                await store.provision({ id: workspace_id, created_at: at, label: typeof payload.label === 'string' ? payload.label : null }, tokens, oldAuth);
                return { workspace_id, backend_url: base, ingest_token, agent_endpoint: base + '/api/agent/health-data', agent_token };
            };
            let result: unknown;
            if (path === '/api/hosted/workspaces' && request.method === 'POST') {
                route = 'provision';
                result = await create(await jsonBody(request));
            }
            else if (path === '/api/hosted/workspaces/reset' && request.method === 'POST') {
                route = 'reset';
                const auth = await authenticate('ingest');
                result = await create(await jsonBody(request), auth);
            }
            else if (path === '/api/hosted/agent-token' && request.method === 'POST') {
                route = 'rotate';
                const auth = await authenticate('ingest'), agent_token = randomToken('hs_agent');
                await store.rotate(auth, { id: randomToken('tok'), workspace_id: auth.workspaceId, kind: 'agent_read', token_hash: await tokenHash(agent_token, secret), created_at: now() });
                result = { workspace_id: auth.workspaceId, agent_endpoint: base + '/api/agent/health-data', agent_token };
            }
            else if (path === '/api/apple-health/sync' && request.method === 'POST') {
                route = 'ingest';
                const auth = await authenticate('ingest');
                result = await store.ingest(auth, await jsonBody(request), request.headers.get('X-App-Version'));
            }
            else if (request.method === 'GET' && ['/api/agent/health-data', '/api/agent/metrics', '/api/agent/workouts', '/api/agent/syncs'].includes(path)) {
                route = path.split('/').at(-1)!;
                const auth = await authenticate('agent_read');
                if (route === 'health-data') {
                    const metrics = await store.list('health_metrics', auth, url), workouts = await store.list('health_workouts', auth, url), syncs = await store.list('sync_batches', auth, url);
                    result = { agent_schema_version: 2, workspace_id: auth.workspaceId, range: { from: url.searchParams.get('from'), to: url.searchParams.get('to') }, page: { ...metrics.page, has_more: metrics.page.has_more || workouts.page.has_more || syncs.page.has_more }, catalog: await store.catalog(auth), metrics: metrics.items, workouts: workouts.items, syncs: syncs.items, ...await store.summaries(auth, url) };
                }
                else {
                    const table: Table = route === 'metrics' ? 'health_metrics' : route === 'workouts' ? 'health_workouts' : 'sync_batches';
                    result = { workspace_id: auth.workspaceId, ...await store.list(table, auth, url) };
                }
                await store.recheck(auth);
            }
            else
                return json({ detail: 'Not found' }, 404);
            const response = json(result);
            console.info('healthsync_capacity', { route, ...store.finish(encoder.encode(JSON.stringify(result)).length) });
            return response;
        }
        catch (error) {
            const status = error instanceof HttpError ? error.status : 500;
            console.error('healthsync_request_failed', { route, status });
            return json({ detail: error instanceof HttpError ? error.message : 'Internal server error' }, status);
        }
    },
};
