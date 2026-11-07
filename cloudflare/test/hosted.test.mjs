import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../web/package.json', import.meta.url));
const { Miniflare, convertV4MiniflareOptions } = require('miniflare');
const { build } = require('esbuild');
let mf, db, directory;
const stamp = '2026-03-08T06:30:00.000001Z';
const metric = (id, extra = {}) => ({ id, type: 'steps', value: 1, unit: 'count', start_at: stamp, end_at: stamp, source_name: 'Synthetic', metadata: { note: 'é 😀' }, ...extra });
const payload = (metrics = [], extra = {}) => ({ device_id: 'test-device', export_id: 'test-export', generated_at: stamp, timezone: 'America/New_York', source: 'test', date_range: { start: '2026-03-08T00:00:00Z', end: '2026-03-09T00:00:00Z' }, metrics, ...extra });
async function call(path, token, body, extraHeaders = {}) {
    const response = await mf.dispatchFetch('https://example.test' + path, { method: body === undefined ? 'GET' : 'POST', headers: { ...(token ? { Authorization: 'Bearer ' + token } : {}), ...extraHeaders }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, headers: response.headers, body: await response.json() };
}
async function provision() { const r = await call('/api/hosted/workspaces', null, { label: 'Synthetic' }); assert.equal(r.status, 200); return r.body; }
before(async () => {
    directory = await mkdtemp(tmpdir() + '/healthsync-runtime-');
    const script = (await build({ stdin: { contents: `import worker from './src/index.ts';
import { capacity, Store } from './src/store.ts';
import { SourceCollation } from './src/collation.ts';
export default {async fetch(request, env, ctx) {
 const scenario=request.headers.get('X-Test-Scenario'), workspace=request.headers.get('X-Test-Workspace');
 const saved={...capacity};let fired=false,billedRows=0,maxBindings=0;
 const original=env.DB, sql=new WeakMap();
 if(scenario==='nul-app-version')request=new Proxy(request,{get(target,key){if(key==='headers')return {get(name){return name.toLowerCase()==='x-app-version'?'invalid\\u0000version'.replace('\\u0000',String.fromCharCode(0)):target.headers.get(name)}};return Reflect.get(target,key,target)}});
 if(scenario==='fingerprint')return Response.json(new SourceCollation().fingerprint());
 if(scenario==='locked')env={...env,MIGRATION_STATE:'locked'};
 if(scenario==='missing-state')env={...env,MIGRATION_STATE:undefined};
 if(scenario==='unknown-state')env={...env,MIGRATION_STATE:'enabled'};
 if(scenario==='missing-secret')env={...env,TOKEN_HASH_SECRET:undefined};
 if(scenario==='small-tie-budget')capacity.tieKeys=1;
 if(scenario==='small-group-budget')capacity.groups=1;
 if(scenario==='small-group-byte-budget')capacity.groupBytes=1;
 if(scenario==='small-response-budget')capacity.responseBytes=1000;
 if(scenario==='small-query-budget')capacity.statements=5;
 if(scenario==='database-failed')env={...env,DB:{prepare(){throw new Error('PRIVATE database failure')}}};
 if(scenario!=='database-failed') {
  env={...env,DB:{prepare(query){const statement=original.prepare(query);const bind=statement.bind.bind(statement);statement.bind=(...args)=>{maxBindings=Math.max(maxBindings,args.length);if(args.length>100)throw new Error('Synthetic binding limit assertion failed');const bound=bind(...args);sql.set(bound,query);return bound};sql.set(statement,query);return statement},async batch(statements){
   const writing=statements.some(s=>(sql.get(s)||'').startsWith('INSERT INTO devices'));
   const fetching=statements.some(s=>(sql.get(s)||'').startsWith('WITH selected('));
   const reading=statements.some(s=>(sql.get(s)||'').includes('ORDER BY r.start_at DESC'));
   if(!fired&&((writing&&scenario!=='mutate-selection'&&scenario!=='revoke-during-read')||(fetching&&['mutate-selection','insert-selection','delete-selection'].includes(scenario))||(reading&&scenario==='revoke-during-read'))) {
    fired=true;
    if(scenario==='wrong-workspace-before-write')await original.prepare('UPDATE access_tokens SET workspace_id=? WHERE workspace_id=?').bind(request.headers.get('X-Test-Other-Workspace'),workspace).run();
    if(scenario==='wrong-kind-before-write')await original.prepare("UPDATE access_tokens SET kind='agent_read' WHERE workspace_id=?").bind(workspace).run();
    if(scenario==='revoke-before-write'||scenario==='revoke-during-read')await original.prepare('UPDATE access_tokens SET revoked_at=? WHERE workspace_id=?').bind('2026-01-01T00:00:00.000000Z',workspace).run();
    if(scenario==='reset-before-write')await original.prepare('DELETE FROM workspaces WHERE id=?').bind(workspace).run();
    if(scenario==='fail-final-statement')statements=[...statements,original.prepare("SELECT json('invalid final statement')")];
    if(scenario==='insert-selection')await original.prepare("INSERT INTO health_metrics SELECT workspace_id,device_id,'inserted',type,value,unit,start_at,end_at,source_name,source_bundle_id,metadata,export_id FROM health_metrics WHERE workspace_id=? LIMIT 1").bind(workspace).run();
    if(scenario==='delete-selection')await original.prepare('DELETE FROM health_metrics WHERE workspace_id=?').bind(workspace).run();
    if(scenario==='mutate-selection')await original.prepare('UPDATE health_metrics SET start_at=? WHERE workspace_id=?').bind('2020-01-01T00:00:00.000000Z',workspace).run();
   }
   const results=await original.batch(statements);for(const result of results)billedRows+=result.meta.rows_read||0;return results
  }}};
 }
 try{const response=await worker.fetch(request,env,ctx);response.headers.set('X-Test-Rows-Read',String(billedRows));response.headers.set('X-Test-Max-Bindings',String(maxBindings));return response}finally{Object.assign(capacity,saved)}
}};`, resolveDir: new URL('..', import.meta.url).pathname, sourcefile: 'runtime-test-wrapper.ts' }, bundle: true, write: false, format: 'esm', platform: 'browser', logLevel: 'silent' })).outputFiles[0].text;
    mf = new Miniflare({ ...convertV4MiniflareOptions({ modules: true, script, compatibilityDate: '2026-10-26', d1Databases: { DB: 'synthetic' }, bindings: { TOKEN_HASH_SECRET: 'synthetic-test-secret', HOSTED_PUBLIC_BASE_URL: 'https://api.healthysync.app', MIGRATION_STATE: 'active' }, outboundService: () => new Response('Network disabled', { status: 502 }) }), resourcePersistencePath: directory });
    db = await mf.getD1Database('DB');
    const migrations = new URL('../migrations/', import.meta.url);
    for (const name of (await readdir(migrations)).filter(name=>name.endsWith('.sql')).sort()) {
        await db.exec(await readFile(new URL(name,migrations),'utf8'));
    }
});
after(async () => { await mf?.dispose(); await rm(directory, { recursive: true, force: true }); });
test('all routes preserve auth, wire fields, durable retry, rotation and reset', async () => {
    const a = await provision(), b = await provision();
    assert.equal(a.backend_url, 'https://api.healthysync.app');
    assert.match(a.ingest_token, /^hs_ingest_/);
    assert.match(a.agent_token, /^hs_agent_/);
    assert.equal((await call('/health')).body.ok, true);
    assert.equal((await call('/api/agent/metrics')).status, 401);
    assert.equal((await call('/api/agent/metrics', 'incorrect')).status, 403);
    assert.equal((await call('/api/agent/metrics', a.ingest_token)).status, 403);
    const input = payload(Array.from({ length: 130 }, (_, i) => metric('m' + i)), { workouts: [{ id: 'w', activity_type: 'walk', start_at: stamp, end_at: stamp, duration_seconds: 60, source_name: 'Synthetic', distance_meters: null, total_energy_kcal: null, active_energy_kcal: 0 }] });
    let r = await call('/api/apple-health/sync', a.ingest_token, input);
    assert.deepEqual(r.body, { ok: true, received: 131, duplicates: 0, deleted: 0, workspace_id: a.workspace_id, export_id: 'test-export' });
    r = await call('/api/apple-health/sync', a.ingest_token, input);
    assert.equal(r.body.duplicates, 131);
    assert.equal((await call('/api/agent/metrics', b.agent_token)).body.items.length, 0);
    r = await call('/api/agent/health-data?limit=1', a.agent_token);
    assert.equal(r.status, 200);
    assert.equal(r.body.workspace_id, a.workspace_id);
    assert.equal(r.body.agent_schema_version, 2);
    assert.equal(r.body.page.has_more, true);
    assert.equal(r.body.metrics[0].metadata.note, 'é 😀');
    assert.equal(r.body.metrics[0].start_at, '2026-03-08T06:30:00.000001+00:00');
    assert.equal(r.body.metric_daily_summaries[0].sample_count, 130);
    assert.equal(r.body.workout_daily_summaries[0].distance_km, null);
    assert.equal(r.body.workout_daily_summaries[0].active_energy_kcal, 0);
    assert.equal((await call('/api/agent/workouts', a.agent_token)).body.items[0].local_date, '2026-03-08');
    assert.equal((await call('/api/agent/syncs', a.agent_token)).body.items.length, 1);
    r = await call('/api/apple-health/sync', a.ingest_token, payload([], { deletions: Array.from({ length: 130 }, (_, i) => ({ id: 'm' + i, kind: 'metric' })) }));
    assert.equal(r.body.deleted, 130);
    const used = await db.prepare('SELECT last_used_at FROM access_tokens WHERE workspace_id=?').bind(a.workspace_id).all();
    assert(used.results.every(t => t.last_used_at));
    const rotation = await call('/api/hosted/agent-token', a.ingest_token, {});
    assert.equal(rotation.status, 200);
    assert.equal((await call('/api/agent/metrics', a.agent_token)).status, 403);
    const reset = await call('/api/hosted/workspaces/reset', a.ingest_token, {});
    assert.equal(reset.status, 200);
    assert.notEqual(reset.body.workspace_id, a.workspace_id);
    assert.equal((await call('/api/apple-health/sync', a.ingest_token, input)).status, 403);
    assert.equal((await db.prepare('SELECT count(*) n FROM devices').first()).n, 1);
});
test('atomic failure rolls back deletes, batches and device updates', async () => {
    const a = await provision();
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('keep')]));
    const r = await call('/api/apple-health/sync', a.ingest_token, payload([metric('bad', { end_at: '2020-01-01T00:00:00Z' })], { deletions: [{ id: 'keep', kind: 'metric' }] }));
    assert.equal(r.status, 500);
    assert.equal((await call('/api/agent/metrics', a.agent_token)).body.items[0].id, 'keep');
});
test('ICU ordering repairs huge timestamp ties and preserves microsecond boundaries', async () => {
    const a = await provision();
    const ids = ['A', 'a', 'Z', 'z', '-', '_', '.', ':', '2', '10', 'é', 'é', '中', '😀', '𐀀', ...Array.from({ length: 1050 }, (_, i) => 'r' + i)];
    for (let i = 0; i < ids.length; i += 200)
        assert.equal((await call('/api/apple-health/sync', a.ingest_token, payload(ids.slice(i, i + 200).map(id => metric(id))))).status, 200);
    const collator = new Intl.Collator('en-US', { usage: 'sort', sensitivity: 'variant', numeric: false, ignorePunctuation: false });
    const expected = [...ids].sort((a, b) => collator.compare(a, b) || Buffer.compare(Buffer.from(a), Buffer.from(b)));
    let actual = [];
    for (let offset = 0; offset < ids.length; offset += 500) {
        const r = await call('/api/agent/metrics?limit=500&offset=' + offset, a.agent_token);
        assert.equal(r.status, 200);
        actual.push(...r.body.items.map(x => x.id));
    }
    assert.deepEqual(actual, expected);
    assert.equal((await call('/api/agent/metrics?limit=1&offset=100000', a.agent_token)).body.items.length, 0);
    assert.equal((await call('/api/agent/metrics?from=2026-03-08T06:30:00.000002Z', a.agent_token)).body.items.length, 0);
});
test('streamed preference spans pages, respects partial ranges and current export timezone', async () => {
    const a = await provision();
    for (let i = 0; i < 5100; i += 300)
        assert.equal((await call('/api/apple-health/sync', a.ingest_token, payload(Array.from({ length: 300 }, (_, j) => metric('raw' + (i + j)))))).status, 200);
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('zz-daily', { value: 42, metadata: { aggregation: 'daily_sum' }, end_at: '2026-03-08T23:00:00Z' })]));
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('other', { value: 3 })], { device_id: 'other-device', export_id: 'other-export' }));
    let r = await call('/api/agent/health-data?limit=1', a.agent_token);
    assert.equal(r.body.metric_daily_summaries[0].total_value, 45);
    assert.equal(r.body.metric_daily_summaries[0].sample_count, 2);
    r = await call('/api/agent/health-data?to=2026-03-08T07:00:00Z', a.agent_token);
    assert.equal(r.body.metric_daily_summaries[0].total_value, 5103);
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('new', { value: 0 })], { timezone: 'Pacific/Honolulu' }));
    r = await call('/api/agent/metrics?limit=500', a.agent_token);
    assert.equal(r.body.items.find(x => x.device_id === 'test-device').local_date, '2026-03-07');
});
test('locked and missing configuration fail before auth; health checks D1; CORS', async () => {
    for (const scenario of ['locked', 'missing-state', 'unknown-state', 'missing-secret']) {
        assert.equal((await call('/api/hosted/workspaces', null, {}, { 'X-Test-Scenario': scenario })).status, 503);
        const r = await call('/health', null, undefined, { 'X-Test-Scenario': scenario });
        assert.equal(r.status, 503);
        assert.equal(r.body.ready, false);
        assert.equal(r.body.database, true);
    }
    const r = await call('/health', null, undefined, { 'X-Test-Scenario': 'database-failed' });
    assert.equal(r.status, 503);
    assert.equal(r.body.database, false);
    assert(!JSON.stringify(r.body).includes('PRIVATE'));
    const preflight = await mf.dispatchFetch('https://example.test/api/apple-health/sync', { method: 'OPTIONS' });
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get('access-control-allow-origin'), '*');
    assert.equal((await call('/missing')).status, 404);
});
test('revoked and reset tokens cannot commit stale writes; failed final statement rolls back', async () => {
    for (const scenario of ['revoke-before-write', 'wrong-kind-before-write', 'reset-before-write', 'fail-final-statement']) {
        const a = await provision();
        await call('/api/apple-health/sync', a.ingest_token, payload([metric('before')]));
        const r = await call('/api/apple-health/sync', a.ingest_token, payload([metric('after')], { deletions: [{ id: 'before', kind: 'metric' }] }), { 'X-Test-Scenario': scenario, 'X-Test-Workspace': a.workspace_id });
        assert.equal(r.status, scenario === 'fail-final-statement' ? 500 : 403);
        const rows = await db.prepare('SELECT id FROM health_metrics WHERE workspace_id=?').bind(a.workspace_id).all();
        assert.deepEqual(rows.results.map(x => x.id), scenario === 'reset-before-write' ? [] : ['before']);
        if (scenario === 'reset-before-write')
            assert.equal(await db.prepare('SELECT id FROM workspaces WHERE id=?').bind(a.workspace_id).first(), null);
    }
});
test('concurrent reset and ingest cannot resurrect a workspace; concurrent rotations leave one agent', async () => {
    const a = await provision();
    const results = await Promise.all([call('/api/hosted/workspaces/reset', a.ingest_token, {}), call('/api/apple-health/sync', a.ingest_token, payload([metric('racing')]))]);
    assert.equal(results[0].status, 200);
    assert([200, 403].includes(results[1].status));
    assert.equal(await db.prepare('SELECT id FROM workspaces WHERE id=?').bind(a.workspace_id).first(), null);
    const b = results[0].body;
    const rotations = await Promise.all([call('/api/hosted/agent-token', b.ingest_token, {}), call('/api/hosted/agent-token', b.ingest_token, {})]);
    assert(rotations.every(r => r.status === 200));
    const valid = await Promise.all(rotations.map(r => call('/api/agent/metrics', r.body.agent_token)));
    assert.deepEqual(valid.map(r => r.status).sort(), [200, 403]);
});
test('read revocation and changed selection fail explicitly without a partial body', async () => {
    for (const scenario of ['revoke-during-read', 'mutate-selection', 'insert-selection', 'delete-selection']) {
        const a = await provision();
        await call('/api/apple-health/sync', a.ingest_token, payload([metric('before')]));
        const r = await call('/api/agent/metrics', a.agent_token, undefined, { 'X-Test-Scenario': scenario, 'X-Test-Workspace': a.workspace_id });
        assert.equal(r.status, scenario === 'revoke-during-read' ? 403 : 503);
        assert.equal(r.body.items, undefined);
    }
});
test('explicit budgets fail without truncation, request parsing is bounded and invalid dates rejected', async () => {
    const a = await provision();
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('one'), metric('two', { type: 'other' })]));
    for (const scenario of ['small-tie-budget', 'small-group-budget', 'small-group-byte-budget', 'small-response-budget', 'small-query-budget'])
        assert.equal((await call('/api/agent/health-data', a.agent_token, undefined, { 'X-Test-Scenario': scenario })).status, 503);
    assert.equal((await call('/api/agent/metrics?from=2026-02-30T00:00:00Z', a.agent_token)).status, 400);
    assert.equal((await call('/api/hosted/workspaces', null, { label: 'a'.repeat(8 * 1024 * 1024) })).status, 413);
    const malformed = await mf.dispatchFetch('https://example.test/api/hosted/workspaces', { method: 'POST', body: '{' });
    assert.equal(malformed.status, 400);
});
test('more than 500 exports enrich via joins and empty uploads preserve the old sync', async () => {
    const a = await provision();
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('seed')]));
    await db.prepare("WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<601) INSERT INTO sync_batches SELECT workspace_id,'export-'||x,device_id,generated_at,received_at,schema_version,timezone,source,date_range_start,date_range_end,metrics_count,workouts_count FROM sync_batches,n WHERE workspace_id=? AND export_id='test-export'").bind(a.workspace_id).run();
    await db.prepare("INSERT INTO health_metrics SELECT workspace_id,device_id,'metric-'||export_id,'steps',1,'count',generated_at,generated_at,'Synthetic',NULL,'{}',export_id FROM sync_batches WHERE workspace_id=? AND export_id<>'test-export'").bind(a.workspace_id).run();
    const r = await call('/api/agent/health-data?offset=500&limit=500', a.agent_token);
    assert.equal(r.status, 200);
    assert.equal(r.body.metrics.length, 102);
    assert.equal(r.body.metric_daily_summaries[0].sample_count, 602);
    assert.equal(r.body.syncs.length, 102);
    const old = await db.prepare('SELECT * FROM sync_batches WHERE workspace_id=? AND export_id=?').bind(a.workspace_id, 'test-export').first();
    assert.equal((await call('/api/apple-health/sync', a.ingest_token, { device_id: 'test-device', export_id: 'test-export', metrics: [] })).status, 200);
    assert.deepEqual(await db.prepare('SELECT * FROM sync_batches WHERE workspace_id=? AND export_id=?').bind(a.workspace_id, 'test-export').first(), old);
});
test('large offset within a 100600-key timestamp tie returns exact ranks and lookahead', async () => {
    const a = await provision();
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('seed')]));
    await db.prepare("WITH RECURSIVE n(x) AS (SELECT 0 UNION ALL SELECT x+1 FROM n WHERE x<100599) INSERT INTO health_metrics SELECT workspace_id,device_id,printf('r%06d',x),type,value,unit,start_at,end_at,source_name,source_bundle_id,metadata,export_id FROM health_metrics,n WHERE workspace_id=? AND id='seed'").bind(a.workspace_id).run();
    await db.prepare("DELETE FROM health_metrics WHERE workspace_id=? AND id='seed'").bind(a.workspace_id).run();
    const r = await call('/api/agent/metrics?offset=100000&limit=500', a.agent_token);
    assert.equal(r.status, 200);
    assert.equal(r.body.items.length, 500);
    assert.equal(r.body.items[0].id, 'r100000');
    assert(Number(r.headers.get('X-Test-Rows-Read')) > 0);
    assert(Number(r.headers.get('X-Test-Rows-Read')) < 900000, 'Tie pagination must use bounded indexed key ranges');
    assert.equal(r.body.items.at(-1).id, 'r100499');
    assert.equal(r.body.page.has_more, true);
    const first = await call('/api/agent/metrics?limit=1', a.agent_token);
    assert.equal(first.body.items[0].id, 'r000000');
    const reset = await call('/api/hosted/workspaces/reset',a.ingest_token,{});
    assert.equal(reset.status,200);
    assert.equal((await db.prepare('SELECT count(*) n FROM health_metrics WHERE workspace_id=?').bind(a.workspace_id).first()).n,0);
});
test('both partial boundary groups, interior groups, ICU-equal devices and sync IDs', async () => {
    const a = await provision();
    const rows = [...['A', 'a', 'z'].map(id => metric('top' + id, { start_at: '2026-03-08T09:00:00Z', end_at: '2026-03-08T09:00:00Z' })), ...['a', 'Z'].map(id => metric('middle' + id, { start_at: '2026-03-08T08:00:00Z', end_at: '2026-03-08T08:00:00Z' })), ...['a', 'z', 'A'].map(id => metric('bottom' + id))];
    await call('/api/apple-health/sync', a.ingest_token, payload(rows));
    const cmp = new Intl.Collator('en-US', { sensitivity: 'variant', numeric: false, ignorePunctuation: false });
    const expected = [...rows].sort((a, b) => Date.parse(b.start_at) - Date.parse(a.start_at) || cmp.compare(a.id, b.id) || Buffer.compare(Buffer.from(a.id), Buffer.from(b.id))).map(x => x.id);
    const r = await call('/api/agent/metrics?offset=1&limit=5', a.agent_token);
    assert.deepEqual(r.body.items.map(x => x.id), expected.slice(1, 6));
    assert.equal(r.body.page.has_more, true);
    assert.equal((await call('/api/agent/metrics?limit=3', a.agent_token)).body.items.length, 3);
    const b = await provision();
    await call('/api/apple-health/sync', b.ingest_token, payload([metric('Z')], { device_id: 'é', export_id: 'é' }));
    await call('/api/apple-health/sync', b.ingest_token, payload([metric('A')], { device_id: 'é', export_id: 'é' }));
    await db.prepare('UPDATE sync_batches SET received_at=? WHERE workspace_id=?').bind(stamp, b.workspace_id).run();
    const health = await call('/api/agent/health-data', b.agent_token);
    assert.deepEqual(health.body.metrics.map(x => x.device_id), ['é', 'é']);
    assert.deepEqual(health.body.catalog.devices.map(x => x.device_id), ['é', 'é']);
    assert.deepEqual(health.body.syncs.map(x => x.export_id), ['é', 'é']);
});
test('daily preference is per device and unit; both markers combine; metadata scalars stay ordinary', async () => {
    const a = await provision();
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('raw', { value: 100 }), metric('sum', { value: 12, metadata: { aggregation: 'daily_sum' } }), metric('avg', { value: 6, metadata: { aggregation: 'daily_average' } }), metric('other-unit', { value: 4, unit: 'different' }), metric('scalar', { value: 77 })]));
    await db.prepare("UPDATE health_metrics SET metadata=? WHERE workspace_id=? AND id='scalar'").bind('"daily_sum"', a.workspace_id).run();
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('other-device', { value: 3 })], { device_id: 'second', export_id: 'second-export' }));
    let r = await call('/api/agent/health-data?device_id=does-not-filter-metrics', a.agent_token);
    assert.equal(r.body.metrics.length, 6);
    assert.equal(r.body.syncs.length, 0);
    assert.deepEqual(r.body.metric_daily_summaries.find(x => x.unit === 'count'), { local_date: '2026-03-08', type: 'steps', unit: 'count', sample_count: 3, total_value: 21, average_value: 7, minimum_value: 3, maximum_value: 12 });
    r = await call('/api/agent/health-data?type=absent', a.agent_token);
    assert.equal(r.body.metric_daily_summaries.length, 0);
    assert.equal(r.body.syncs.length, 2);
});
test('timezone aliases, fallback, DST, historical offsets, current exports and microsecond wire values', async () => {
    const a = await provision();
    const fixtures = [['gap', 'America/New_York', '2026-03-08T07:00:00Z', '2026-03-08'], ['fold', 'US/Eastern', '2026-11-01T05:30:00Z', '2026-11-01'], ['fraction', 'Asia/Kathmandu', '2026-03-08T23:00:00Z', '2026-03-09'], ['history', 'Pacific/Apia', '2011-12-30T10:00:00Z', '2011-12-31'], ['invalid', 'No/Such_Zone', '2026-03-08T23:59:59.999999Z', '2026-03-08'], ['fraction-wire', 'UTC', '2026-03-08T06:30:00.12+00:00', '2026-03-08']];
    for (const [id, timezone, start_at] of fixtures)
        assert.equal((await call('/api/apple-health/sync', a.ingest_token, payload([metric(id, { start_at, end_at: start_at })], { export_id: id, timezone }))).status, 200);
    let r = await call('/api/agent/metrics', a.agent_token);
    for (const [id, timezone, , date] of fixtures) {
        const row = r.body.items.find(x => x.id === id);
        assert.equal(row.local_date, date);
        assert.equal(row.timezone, timezone);
    }
    assert.equal(r.body.items.find(x => x.id === 'fraction-wire').start_at, '2026-03-08T06:30:00.12+00:00');
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('second-device')], { device_id: 'second', export_id: 'gap', timezone: 'Pacific/Honolulu' }));
    r = await call('/api/agent/metrics', a.agent_token);
    assert.equal(r.body.items.find(x => x.id === 'gap').local_date, '2026-03-07');
    assert.equal(r.body.items.find(x => x.id === 'second-device').local_date, '2026-03-07');
    assert.equal((await call('/api/agent/metrics?from=2026-03-08T06:30:00.120001Z&to=2026-03-08T06:30:00.120001Z', a.agent_token)).body.items.length, 0);
});
test('nullable workout fields sum independently and fractional values retain tight numerical agreement', async () => {
    const a = await provision();
    const workout = (id, extra = {}) => ({ id, activity_type: 'walk', start_at: stamp, end_at: stamp, duration_seconds: 61, source_name: 'Synthetic', total_energy_kcal: null, active_energy_kcal: null, distance_meters: null, ...extra });
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('f1', { value: 0.1 }), metric('f2', { value: 0.2 }), metric('f3', { value: -0.1 })], { workouts: [workout('w1'), workout('w2', { distance_meters: 0, total_energy_kcal: 2 }), workout('w3', { distance_meters: 1000, active_energy_kcal: 0 })] }));
    const r = await call('/api/agent/health-data', a.agent_token);
    assert.deepEqual(r.body.workout_daily_summaries, [{ local_date: '2026-03-08', activity_type: 'walk', workout_count: 3, duration_minutes: 183 / 60, distance_km: 1, total_energy_kcal: 2, active_energy_kcal: 0 }]);
    assert(Math.abs(r.body.metric_daily_summaries[0].total_value - 0.2) < 1e-12);
    const filtered = await call('/api/agent/health-data?activity_type=absent', a.agent_token);
    assert.equal(filtered.body.workouts.length, 0);
    assert.equal(filtered.body.metrics.length, 3);
});
test('actual workerd comparator matches source ICU 153.121 synthetic fingerprint', async () => {
    const expected = ['😀', 'a', 'A', 'å', 'ä', 'a b', 'a_b', 'a-b', 'a:b', 'a.b', 'a10', 'a2', 'æ', 'Æ', 'e', 'é', 'é', 'ss', 'ß', 'z', 'Z', '𐀀', '中文', '日本語'];
    const r = await call('/fingerprint', null, undefined, { 'X-Test-Scenario': 'fingerprint' });
    assert.deepEqual(r.body.order, expected);
    assert.equal(r.body.options.locale, 'en-US');
    assert.equal(r.body.options.numeric, false);
    assert.equal(r.body.options.sensitivity, 'variant');
});
test('deletion counts precede duplicates and duplicate payload IDs obey source chunk boundaries', async () => {
    const a = await provision();
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('same')]));
    let r = await call('/api/apple-health/sync', a.ingest_token, payload([metric('same', { value: 3 })], { deletions: [{ kind: 'metric', id: 'same' }, { kind: 'metric', id: 'same' }] }));
    assert.equal(r.body.deleted, 1);
    assert.equal(r.body.duplicates, 0);
    r = await call('/api/apple-health/sync', a.ingest_token, payload([metric('same'), metric('same')]));
    assert.equal(r.status, 500);
    assert.equal((await call('/api/agent/metrics', a.agent_token)).body.items[0].value, 3);
    const input = [metric('same'), ...Array.from({ length: 99 }, (_, i) => metric('between' + i)), metric('same', { value: 7 })];
    r = await call('/api/apple-health/sync', a.ingest_token, payload(input));
    assert.equal(r.status, 200);
    assert.equal(r.body.received, 101);
    assert.equal(r.body.duplicates, 2);
    assert.equal((await call('/api/agent/metrics?limit=500', a.agent_token)).body.items.find(x => x.id === 'same').value, 7);
});

test('concurrent resets replace one workspace exactly once', async () => {
 const a=await provision();
 const responses=await Promise.all([call('/api/hosted/workspaces/reset',a.ingest_token,{}),call('/api/hosted/workspaces/reset',a.ingest_token,{})]);
 assert.deepEqual(responses.map(r=>r.status).sort(),[200,403]);
 assert.equal(await db.prepare('SELECT id FROM workspaces WHERE id=?').bind(a.workspace_id).first(),null);
});
test('large Unicode metadata stays exact and explicit payload limits fail cleanly', async () => {
 const a=await provision(),note='健康😀é'.repeat(16000);
 const r=await call('/api/apple-health/sync',a.ingest_token,payload([metric('large',{metadata:{note}})]));assert.equal(r.status,200);
 const page=await call('/api/agent/metrics',a.agent_token);assert.equal(page.body.items[0].metadata.note,note);
 const limited=await call('/api/agent/metrics',a.agent_token,undefined,{'X-Test-Scenario':'small-response-budget'});assert.equal(limited.status,503);assert.equal(limited.body.items,undefined);
});
test('date-only range boundaries mean UTC midnight and preserve raw range fields', async () => {
    const a = await provision();
    await call('/api/apple-health/sync', a.ingest_token, payload([metric('midnight', {start_at:'2026-03-08T00:00:00Z',end_at:'2026-03-08T00:00:00Z'}),metric('daytime')]));
    const from = await call('/api/agent/health-data?from=2026-03-08',a.agent_token);
    assert.equal(from.status,200);
    assert.equal(from.body.metrics.length,2);
    assert.deepEqual(from.body.range,{from:'2026-03-08',to:null});
    const exact = await call('/api/agent/metrics?from=2026-03-08&to=2026-03-08',a.agent_token);
    assert.equal(exact.status,200);
    assert.deepEqual(exact.body.items.map(row=>row.id),['midnight']);
    assert.equal((await call('/api/agent/metrics?from=2026-02-30',a.agent_token)).status,400);
});

test('mutation authorization remains bound to the originally authenticated workspace',async()=>{
 const a=await provision(),b=await provision();
 const r=await call('/api/apple-health/sync',a.ingest_token,payload([metric('forbidden')]),{'X-Test-Scenario':'wrong-workspace-before-write','X-Test-Workspace':a.workspace_id,'X-Test-Other-Workspace':b.workspace_id});
 assert.equal(r.status,403);
 assert.equal((await db.prepare('SELECT count(*) n FROM health_metrics WHERE workspace_id=?').bind(a.workspace_id).first()).n,0);
});
test('ICU-equivalent metric summaries retain v10 first-record order across scan pages', async () => {
    const a = await provision();
    const composed = '\u00e9', decomposed = 'e\u0301';
    assert.equal(composed.localeCompare(decomposed), 0);
    await call('/api/apple-health/sync', a.ingest_token, payload([
        metric('A', {type:composed,value:2}),
        metric('a', {type:decomposed,value:100}),
        metric('z', {type:decomposed,value:7,metadata:{aggregation:'daily_sum'}}),
        metric('seed', {type:'padding'})
    ]));
    await db.prepare("WITH RECURSIVE n(x) AS (SELECT 0 UNION ALL SELECT x+1 FROM n WHERE x<5000) INSERT INTO health_metrics SELECT workspace_id,device_id,printf('B%05d',x),type,value,unit,start_at,end_at,source_name,source_bundle_id,metadata,export_id FROM health_metrics,n WHERE workspace_id=? AND id='seed'").bind(a.workspace_id).run();
    const r = await call('/api/agent/health-data?limit=1', a.agent_token);
    assert.equal(r.status,200);
    const equivalent = r.body.metric_daily_summaries.filter(row=>row.type===composed||row.type===decomposed);
    assert.deepEqual(equivalent.map(row=>row.type),[decomposed,composed]);
    assert.equal(equivalent[0].total_value,7);
});
test('ICU-equivalent workout summaries retain v10 first-record order across scan pages', async () => {
    const a = await provision();
    const composed = '\u00e9', decomposed = 'e\u0301';
    const workout = (id,activity_type) => ({id,activity_type,start_at:stamp,end_at:stamp,duration_seconds:60,source_name:'Synthetic'});
    await call('/api/apple-health/sync',a.ingest_token,payload([],{workouts:[workout('A',composed),workout('a',decomposed),workout('seed','padding')]}));
    await db.prepare("WITH RECURSIVE n(x) AS (SELECT 0 UNION ALL SELECT x+1 FROM n WHERE x<5000) INSERT INTO health_workouts SELECT workspace_id,device_id,printf('B%05d',x),activity_type,start_at,end_at,duration_seconds,total_energy_kcal,active_energy_kcal,distance_meters,source_name,source_bundle_id,metadata,export_id FROM health_workouts,n WHERE workspace_id=? AND id='seed'").bind(a.workspace_id).run();
    const r = await call('/api/agent/health-data?limit=1',a.agent_token);
    assert.equal(r.status,200);
    assert.deepEqual(r.body.workout_daily_summaries.filter(row=>row.activity_type===composed||row.activity_type===decomposed).map(row=>row.activity_type),[decomposed,composed]);
});
test('summary ties use the first source record across devices rather than a summary-key fallback', async () => {
    const a = await provision(), composed='\u00e9', decomposed='e\u0301';
    for (const [device_id,id,type] of [['A','a',decomposed],['A','Z',composed],['a','b',composed]]) {
        const workout={id,activity_type:type,start_at:stamp,end_at:stamp,duration_seconds:60,source_name:'Synthetic'};
        assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric(id,{type})],{device_id,export_id:device_id+id,workouts:[workout]}))).status,200);
    }
    const r=await call('/api/agent/health-data',a.agent_token);
    assert.equal(r.status,200);
    assert.deepEqual(r.body.metric_daily_summaries.map(row=>row.type),[composed,decomposed]);
    assert.deepEqual(r.body.workout_daily_summaries.map(row=>row.activity_type),[composed,decomposed]);
});

test('PostgreSQL varchar guards count Unicode codepoints and abort invalid batches', async()=>{
 const a=await provision();
 const atLimit=metric('😀'.repeat(256),{type:'😀'.repeat(128),unit:'😀'.repeat(64),source_name:'😀'.repeat(256),source_bundle_id:'😀'.repeat(256)});
 const ascii=await provision();
 assert.equal((await call('/api/apple-health/sync',ascii.ingest_token,payload([metric('a'.repeat(256),{type:'a'.repeat(128),unit:'a'.repeat(64),source_name:'a'.repeat(256),source_bundle_id:'a'.repeat(256)})]))).status,200);
 assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([atLimit]),{'X-App-Version':'a'.repeat(64)})).status,200);
 for(const character of ['a','😀']) {
  for(const [field,limit] of [['id',256],['type',128],['unit',64],['source_name',256],['source_bundle_id',256]]) {
   const r=await call('/api/apple-health/sync',a.ingest_token,payload([metric('valid-first'),metric('invalid-last',{[field]:character.repeat(limit+1)})],{deletions:[{kind:'metric',id:atLimit.id}]}));
   assert.equal(r.status,500,field+' over limit must fail');assert.deepEqual(r.body,{detail:'Internal server error'});
   const rows=await db.prepare('SELECT id FROM health_metrics WHERE workspace_id=?').bind(a.workspace_id).all();assert.deepEqual(rows.results.map(x=>x.id),[atLimit.id]);
   assert.equal((await db.prepare('SELECT app_version FROM devices WHERE device_id=?').bind('test-device').first()).app_version,'a'.repeat(64));
  }
 }
 assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([]),{'X-App-Version':'a'.repeat(65)})).status,500);
 assert.equal((await call('/api/hosted/workspaces',null,{label:'😀'.repeat(128)})).status,200);
 assert.equal((await call('/api/hosted/workspaces',null,{label:'😀'.repeat(129)})).status,500);
});
test('PostgreSQL text and nested JSON NUL guards preserve literal escape text',async()=>{
 const a=await provision();
 for(const field of ['id','type','unit','source_name','source_bundle_id']) {
  assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric('invalid',{[field]:'bad\u0000value'})]))).status,500,field);
 }
 for(const metadata of [{nested:[{value:'bad\u0000value'}]},{nested:[{['bad\u0000key']:'value'}]},{['\u0000']:null}]) {
  assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric('invalid',{metadata})]))).status,500);
 }
 const metadata={literal:String.raw`\u0000`,nested:{[String.raw`\u0000`]:['😀',null]}};
 assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric('valid',{source_bundle_id:null,metadata})]))).status,200);
 assert.deepEqual((await call('/api/agent/metrics',a.agent_token)).body.items[0].metadata,metadata);
 assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([]),{'X-Test-Scenario':'nul-app-version'})).status,500);
 assert.throws(()=>new Request('https://example.test',{headers:{'X-App-Version':'bad\u0000header'}}));
});
test('PostgreSQL malformed Unicode is rejected before encoding but valid pairs survive',async()=>{
 const a=await provision();
 for(const malformed of ['\ud800','\udfff','x\ud800y']) {
  for(const metadata of [{nested:[{value:malformed}]},{nested:{[malformed]:'value'}}]) {
   assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric('invalid',{metadata})]))).status,500);
  }
  assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric(malformed)]))).status,500);
 }
 const pair='\ud83d\ude00';
 assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric(pair,{metadata:{[pair]:pair}})]))).status,200);
 const row=(await call('/api/agent/metrics',a.agent_token)).body.items[0];assert.equal(row.id,pair);assert.deepEqual(row.metadata,{[pair]:pair});
});
test('PostgreSQL value guards cover INSERT and UPDATE on every original text column',async()=>{
 const limits={
  devices:{device_id:128,app_version:64},workspaces:{id:64,label:128},
  workspace_devices:{workspace_id:64,device_id:128,label:128},
  access_tokens:{id:64,workspace_id:64,kind:32,token_hash:64},
  sync_batches:{workspace_id:64,export_id:36,device_id:128,timezone:128,source:64},
  health_metrics:{workspace_id:64,device_id:128,id:256,type:128,unit:64,source_name:256,source_bundle_id:256,export_id:36},
  health_workouts:{workspace_id:64,device_id:128,id:256,activity_type:128,source_name:256,source_bundle_id:256,export_id:36}
 };
 const a=await provision();
 const workout={id:'guard-workout',activity_type:'walk',start_at:stamp,end_at:stamp,duration_seconds:60,source_name:'Synthetic'};
 assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric('guard-metric')],{workouts:[workout]}))).status,200);
 for(const [table,columns] of Object.entries(limits)) {
  const info=(await db.prepare(`PRAGMA table_info(${table})`).all()).results;
  const where=table==='devices'?'device_id=?':table==='workspaces'?'id=?':'workspace_id=?';
  const identity=table==='devices'?'test-device':a.workspace_id;
  const original=await db.prepare(`SELECT * FROM ${table} WHERE ${where} LIMIT 1`).bind(identity).first();
  const names=Object.keys(original), keyColumns=info.filter(c=>c.pk).sort((a,b)=>a.pk-b.pk).map(c=>c.name);
  const keyWhere=keyColumns.map(c=>`${c}=?`).join(' AND '),keyValues=keyColumns.map(c=>original[c]);
  async function rejectsValue(column,value) {
   await assert.rejects(db.prepare(`UPDATE ${table} SET ${column}=? WHERE ${keyWhere}`).bind(value,...keyValues).run(),/postgres value guard/);
   const candidate={...original,[column]:value};
   await assert.rejects(db.prepare(`INSERT INTO ${table} (${names.join(',')}) VALUES (${names.map(()=>'?').join(',')})`).bind(...names.map(name=>candidate[name])).run(),/postgres value guard/);
  }
  for(const [column,limit] of Object.entries(columns)) {
   await rejectsValue(column,'a'.repeat(limit+1));
   await rejectsValue(column,'😀'.repeat(limit+1));
  }
  for(const column of info.filter(c=>c.type==='TEXT').map(c=>c.name)) await rejectsValue(column,'before\u0000after');
  if('metadata' in original) {
   for(const value of [{nested:[{['nul\u0000key']:'safe'}]},{nested:[{value:'bad\u0000text'}]}]) await rejectsValue('metadata',JSON.stringify(value));
   const literal=JSON.stringify({literal:String.raw`\u0000`,nested:{[String.raw`\u0000`]:null}});
   await db.prepare(`UPDATE ${table} SET metadata=? WHERE ${keyWhere}`).bind(literal,...keyValues).run();
   assert.equal((await db.prepare(`SELECT metadata FROM ${table} WHERE ${keyWhere}`).bind(...keyValues).first()).metadata,literal);
  }
 }
});
test('PostgreSQL integer schema versions reject invalid uploads without changing ingest state',async()=>{
 const a=await provision(),device='integer-device-'+a.workspace_id;
 const workout={id:'keep-workout',activity_type:'walk',start_at:stamp,end_at:stamp,duration_seconds:60,source_name:'Synthetic'};
 assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric('keep-metric')],{device_id:device,workouts:[workout]}),{'X-App-Version':'before'})).status,200);
 async function state() {
  return Promise.all(['devices','workspace_devices','sync_batches','health_metrics','health_workouts'].map(table=>
   db.prepare(`SELECT * FROM ${table} WHERE ${table==='devices'?'device_id IN (?,?)':'workspace_id=?'}`).bind(...(table==='devices'?[device,device+'-new']:[a.workspace_id])).all().then(r=>r.results)));
 }
 const before=await state();
 for(const schema_version of [1.5,2147483648,-2147483649,1e20,'1.5','Infinity','NaN']) {
  for(const device_id of [device,device+'-new']) {
   const r=await call('/api/apple-health/sync',a.ingest_token,payload([metric('new-metric')],{device_id,schema_version,workouts:[{...workout,id:'new-workout'}],deletions:[{kind:'metric',id:'keep-metric'},{kind:'workout',id:'keep-workout'}]}),{'X-App-Version':'after'});
   assert.equal(r.status,500,`${schema_version} on ${device_id}`);
   assert.deepEqual(r.body,{detail:'Internal server error'});
   assert.deepEqual(await state(),before);
  }
 }
});
test('PostgreSQL integer schema versions preserve signed boundaries and source coercions',async()=>{
 const a=await provision();
 for(const [schema_version,want] of [[-2147483648,-2147483648],[2147483647,2147483647],[-1,-1],[0,0],[undefined,1],[null,1],['-2147483648',-2147483648],['2147483647',2147483647],['2',2],[true,1],[false,0]]) {
  assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric('integer-valid')],{schema_version}))).status,200,String(schema_version));
  assert.equal((await db.prepare('SELECT schema_version FROM sync_batches WHERE workspace_id=?').bind(a.workspace_id).first()).schema_version,want);
 }
});
test('PostgreSQL integer guards reject INSERT and UPDATE and roll back an entire D1 batch',async()=>{
 const a=await provision(),device='integer-guard-'+a.workspace_id;
 assert.equal((await call('/api/apple-health/sync',a.ingest_token,payload([metric('integer-guard')],{device_id:device}),{'X-App-Version':'before'})).status,200);
 const original=await db.prepare('SELECT * FROM sync_batches WHERE workspace_id=?').bind(a.workspace_id).first();
 const names=Object.keys(original);
 for(const column of ['schema_version','metrics_count','workouts_count']) {
  for(const value of [1.5,2147483648,-2147483649,1e20,'not-integer']) {
   await assert.rejects(db.prepare(`INSERT INTO sync_batches (${names.join(',')}) VALUES (${names.map(()=>'?').join(',')})`).bind(...names.map(name=>name===column?value:name==='export_id'?'invalid-integer':original[name])).run(),/postgres integer guard/);
   await assert.rejects(db.batch([
    db.prepare("UPDATE devices SET app_version='after' WHERE device_id=?").bind(device),
    db.prepare('DELETE FROM health_metrics WHERE workspace_id=?').bind(a.workspace_id),
    db.prepare(`UPDATE sync_batches SET ${column}=? WHERE workspace_id=?`).bind(value,a.workspace_id)
   ]),/postgres integer guard/);
   assert.deepEqual(await db.prepare('SELECT * FROM sync_batches WHERE workspace_id=?').bind(a.workspace_id).first(),original);
   assert.equal((await db.prepare('SELECT app_version FROM devices WHERE device_id=?').bind(device).first()).app_version,'before');
   assert.equal((await db.prepare('SELECT count(*) n FROM health_metrics WHERE workspace_id=?').bind(a.workspace_id).first()).n,1);
  }
  for(const value of column==='schema_version'?[-2147483648,0,2147483647]:[0,2147483647]) {
   await db.prepare(`UPDATE sync_batches SET ${column}=? WHERE workspace_id=?`).bind(value,a.workspace_id).run();
   assert.equal((await db.prepare(`SELECT ${column} n FROM sync_batches WHERE workspace_id=?`).bind(a.workspace_id).first()).n,value);
  }
  await db.prepare(`UPDATE sync_batches SET ${column}=? WHERE workspace_id=?`).bind(original[column],a.workspace_id).run();
 }
});
