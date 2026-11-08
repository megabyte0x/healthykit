import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';

const require = createRequire(new URL('../../web/package.json', import.meta.url));
const { transform } = require('esbuild');
const source = await readFile(new URL('../../supabase/functions/healthsync/index.ts', import.meta.url), 'utf8');
const script = (await transform(source, { loader: 'ts', format: 'cjs' })).code;

function bridge(upstream, { deadline } = {}) {
    let handle;
    const logs = [], timers = new Set(), delays = [];
    runInNewContext(script, {
        Request, Response, Headers, URL, ReadableStream, AbortController, Error,
        fetch: upstream,
        Deno: { serve(handler) { handle = handler; } },
        console: Object.fromEntries(['error', 'warn', 'info', 'log'].map(level => [level, (...args) => logs.push(args)])),
        setTimeout(fn, delay) {
            delays.push(delay);
            const timer = setTimeout(() => { timers.delete(timer); fn(); }, deadline ?? delay);
            timers.add(timer);
            return timer;
        },
        clearTimeout(timer) { timers.delete(timer); clearTimeout(timer); },
    });
    return { handle, logs, timers, delays };
}

function request(path, init = {}) {
    return new Request('https://legacy.example' + path, { ...init, duplex: 'half' });
}

test('forwards exact bytes, headers, methods and queries for both prefixes and direct paths', async () => {
    for (const path of ['/functions/v1/healthsync/api/apple-health/sync', '/healthsync/api/apple-health/sync', '/api/apple-health/sync']) {
        for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
            const bytes = new Uint8Array([0, 255, 13, 10, 123, 32, 125]);
            const incoming = request(path + '?type=a%2Fb&x=1&x=2&empty=', {
                method, body: bytes,
                headers: { Authorization: 'Bearer synthetic-token', 'Content-Type': 'application/octet-stream', 'X-App-Version': 'synthetic', 'X-Device-ID': 'synthetic-device' },
            });
            let calls = 0;
            const proxy = bridge(async (url, init) => {
                calls++;
                assert.equal(String(url), 'https://api.healthysync.app/api/apple-health/sync?type=a%2Fb&x=1&x=2&empty=');
                assert.equal(init.method, method);
                assert.equal(init.redirect, 'manual');
                assert.equal(init.body, incoming.body);
                const forwarded = new Request(url, { ...init, duplex: 'half' });
                assert.equal(forwarded.headers.get('authorization'), 'Bearer synthetic-token');
                assert.equal(forwarded.headers.get('content-type'), 'application/octet-stream');
                assert.equal(forwarded.headers.get('x-app-version'), 'synthetic');
                assert.equal(forwarded.headers.get('x-device-id'), 'synthetic-device');
                assert.deepEqual(new Uint8Array(await forwarded.arrayBuffer()), bytes);
                return new Response('{"detail":"synthetic conflict"}', { status: 409, statusText: 'Conflict', headers: { 'Content-Type': 'application/json', 'X-Request-ID': 'synthetic-id', 'Retry-After': '5' } });
            });
            const response = await proxy.handle(incoming);
            assert.equal(response.status, 409);
            assert.equal(response.statusText, 'Conflict');
            assert.equal(await response.text(), '{"detail":"synthetic conflict"}');
            assert.equal(response.headers.get('content-type'), 'application/json');
            assert.equal(response.headers.get('x-request-id'), 'synthetic-id');
            assert.equal(response.headers.get('retry-after'), '5');
            assert.equal(response.headers.get('access-control-allow-origin'), '*');
            assert.equal(calls, 1);
            assert.equal(proxy.timers.size, 0);
            assert.deepEqual(proxy.logs, []);
        }
    }
});

test('strips only complete prefix segments and cannot change the fixed upstream origin', async () => {
    const cases = [
        ['/healthsync', '/'], ['/functions/v1/healthsync/', '/'],
        ['/healthsync-extra/api/agent/metrics', '/healthsync-extra/api/agent/metrics'],
        ['/functions/v1/healthsync-extra/health', '/functions/v1/healthsync-extra/health'],
        ['/api/agent/metrics', '/api/agent/metrics'],
        ['/healthsync//evil.example/api', '//evil.example/api'],
        ['//evil.example/api', '//evil.example/api'],
        ['/functions/v1/healthsync/https://evil.example/api', '/https://evil.example/api'],
        ['/healthsync/%2F%2Fevil.example/api', '/%2F%2Fevil.example/api'],
    ];
    for (const [path, expected] of cases) {
        let calls = 0;
        const proxy = bridge(async (target, init) => {
            calls++;
            const url = new URL(target);
            assert.equal(url.origin, 'https://api.healthysync.app');
            assert.equal(url.pathname, expected);
            assert.equal(url.search, '?target=https%3A%2F%2Fevil.example');
            assert.equal(init.method, 'GET');
            assert.equal(init.body, undefined);
            return new Response(null, { status: 204 });
        });
        assert.equal((await proxy.handle(request(path + '?target=https%3A%2F%2Fevil.example'))).status, 204);
        assert.equal(calls, 1);
        assert.equal(proxy.timers.size, 0);
    }
});

test('answers CORS preflight without contacting upstream', async () => {
    const proxy = bridge(() => { assert.fail('Preflight reached upstream'); });
    const response = await proxy.handle(request('/healthsync/api/apple-health/sync', { method: 'OPTIONS' }));
    assert.equal(response.status, 204);
    assert.equal(await response.text(), '');
    assert.equal(response.headers.get('access-control-allow-origin'), '*');
    assert.match(response.headers.get('access-control-allow-methods'), /POST/);
    for (const header of ['authorization', 'x-client-info', 'apikey', 'content-type', 'x-app-version', 'x-device-id'])
        assert(response.headers.get('access-control-allow-headers').split(/,\s*/).includes(header));
    assert.equal(proxy.timers.size, 0);
});

test('passes redirects and JSON errors through once without following or replaying', async () => {
    for (const status of [301, 307, 308, 400, 401, 403, 404, 413, 429, 500, 503]) {
        let calls = 0;
        const proxy = bridge(async (_url, init) => {
            calls++;
            assert.equal(init.redirect, 'manual');
            return new Response('{"detail":"synthetic upstream"}', { status, headers: { Location: 'https://other.example', 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } });
        });
        const response = await proxy.handle(request('/healthsync/api/hosted/workspaces/reset', { method: 'POST', body: '{}' }));
        assert.equal(response.status, status);
        assert.equal(response.headers.get('location'), 'https://other.example');
        assert.equal(await response.text(), '{"detail":"synthetic upstream"}');
        assert.equal(calls, 1);
        assert.equal(proxy.timers.size, 0);
    }
});

test('removes hop-by-hop headers and decoded response encoding/length while preserving end-to-end headers', async () => {
    const proxy = bridge(async (_url, init) => {
        for (const header of ['connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization', 'te', 'trailer', 'transfer-encoding', 'upgrade', 'host', 'x-connection-private'])
            assert.equal(init.headers.get(header), null, header);
        assert.equal(init.headers.get('authorization'), 'Bearer synthetic-token');
        assert.equal(init.headers.get('accept-encoding'), 'identity');
        return new Response('decoded synthetic body', { headers: {
            Connection: 'keep-alive, x-upstream-private', 'Keep-Alive': 'timeout=5', 'X-Upstream-Private': 'remove',
            'Transfer-Encoding': 'chunked', 'Content-Encoding': 'gzip', 'Content-Length': '10', 'Content-Type': 'application/json',
            ETag: '"synthetic-etag"', Vary: 'Accept-Encoding', 'Access-Control-Expose-Headers': 'X-Request-ID',
        } });
    });
    const response = await proxy.handle(request('/healthsync/health', { headers: {
        Connection: 'keep-alive, x-connection-private', 'Keep-Alive': 'timeout=5', 'X-Connection-Private': 'remove',
        'Proxy-Authenticate': 'remove', 'Proxy-Authorization': 'remove', TE: 'trailers', Trailer: 'x-synthetic',
        'Transfer-Encoding': 'chunked', Upgrade: 'websocket', Host: 'evil.example', Authorization: 'Bearer synthetic-token', 'Accept-Encoding': 'gzip',
    } }));
    assert.equal(await response.text(), 'decoded synthetic body');
    for (const header of ['connection', 'keep-alive', 'x-upstream-private', 'transfer-encoding', 'content-encoding', 'content-length'])
        assert.equal(response.headers.get(header), null, header);
    assert.equal(response.headers.get('etag'), '"synthetic-etag"');
    assert.equal(response.headers.get('vary'), 'Accept-Encoding');
    assert.equal(response.headers.get('access-control-expose-headers'), 'X-Request-ID');
});

test('streams response before completion and keeps its deadline until body finishes', async () => {
    let output;
    const proxy = bridge(async () => new Response(new ReadableStream({ start(controller) { output = controller; } })));
    const response = await proxy.handle(request('/api/agent/health-data'));
    assert.equal(proxy.timers.size, 1);
    assert.deepEqual(proxy.delays, [60_000]);
    output.enqueue(new TextEncoder().encode('first'));
    const reader = response.body.getReader();
    assert.equal(new TextDecoder().decode((await reader.read()).value), 'first');
    assert.equal(proxy.timers.size, 1);
    output.enqueue(new TextEncoder().encode('second'));
    output.close();
    assert.equal(new TextDecoder().decode((await reader.read()).value), 'second');
    assert.equal((await reader.read()).done, true);
    assert.equal(proxy.timers.size, 0);
});

test('connection errors and timeouts return generic retryable 503 without logging or replay', async () => {
    for (const timeout of [false, true]) {
        let calls = 0, signal;
        const proxy = bridge(async (_url, init) => {
            calls++;
            signal = init.signal;
            if (!timeout) throw new Error('PRIVATE synthetic-token private-health-value');
            return await new Promise((_resolve, reject) => init.signal.addEventListener('abort', () => reject(new Error('PRIVATE synthetic-token private-health-value')), { once: true }));
        }, { deadline: 10 });
        const response = await proxy.handle(request('/api/apple-health/sync?private=private-health-value', { method: 'POST', body: 'private-health-value', headers: { Authorization: 'Bearer synthetic-token' } }));
        assert.equal(response.status, 503);
        assert.equal(response.headers.get('retry-after'), '5');
        assert.equal(response.headers.get('access-control-allow-origin'), '*');
        assert.equal(response.headers.get('cache-control'), 'no-store');
        const text = await response.text();
        assert.deepEqual(JSON.parse(text), { detail: 'Hosted service temporarily unavailable' });
        assert(!text.includes('PRIVATE') && !text.includes('synthetic-token') && !text.includes('private-health-value'));
        assert.equal(calls, 1);
        if (timeout) assert.equal(signal.aborted, true);
        assert.equal(proxy.timers.size, 0);
        assert.deepEqual(proxy.logs, []);
    }
});

test('body timeout aborts and cancels upstream without leaking errors after headers are sent', async () => {
    let cancelled = false, signal;
    const proxy = bridge(async (_url, init) => {
        signal = init.signal;
        return new Response(new ReadableStream({ cancel() { cancelled = true; } }));
    }, { deadline: 10 });
    const response = await proxy.handle(request('/api/agent/health-data'));
    assert.equal(response.status, 200);
    await assert.rejects(response.text(), /Hosted service temporarily unavailable/);
    assert.equal(signal.aborted, true);
    assert.equal(cancelled, true);
    assert.equal(proxy.timers.size, 0);
    assert.deepEqual(proxy.logs, []);
});

test('upstream body failures terminate the stream with a generic error and no replay', async () => {
    let output, calls = 0;
    const proxy = bridge(async () => {
        calls++;
        return new Response(new ReadableStream({ start(controller) { output = controller; } }), { status: 206 });
    });
    const response = await proxy.handle(request('/api/agent/metrics'));
    assert.equal(response.status, 206);
    output.error(new Error('PRIVATE synthetic-token private-health-value'));
    await assert.rejects(response.text(), error => error.message === 'Hosted service temporarily unavailable');
    assert.equal(calls, 1);
    assert.equal(proxy.timers.size, 0);
    assert.deepEqual(proxy.logs, []);
});

test('an already aborted request never reaches upstream', async () => {
    const client = new AbortController();
    client.abort(new Error('PRIVATE synthetic-token'));
    const proxy = bridge(() => assert.fail('Aborted request reached upstream'));
    const response = await proxy.handle(request('/api/hosted/workspaces', { method: 'POST', body: '{}', signal: client.signal }));
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { detail: 'Hosted service temporarily unavailable' });
    assert.equal(proxy.timers.size, 0);
    assert.deepEqual(proxy.logs, []);
});

test('downstream cancellation and client abort release the upstream body and timer', async () => {
    for (const clientAbort of [false, true]) {
        let cancelled = false, signal;
        const client = new AbortController();
        const proxy = bridge(async (_url, init) => {
            signal = init.signal;
            return new Response(new ReadableStream({ cancel() { cancelled = true; } }));
        });
        const response = await proxy.handle(request('/api/agent/health-data', { signal: client.signal }));
        if (clientAbort) {
            client.abort(new Error('PRIVATE synthetic-token'));
            await assert.rejects(response.text(), /Hosted service temporarily unavailable/);
        } else {
            await response.body.cancel('PRIVATE synthetic-token');
        }
        assert.equal(signal.aborted, true);
        assert.equal(cancelled, true);
        assert.equal(proxy.timers.size, 0);
        assert.deepEqual(proxy.logs, []);
    }
});

test('HEAD keeps status and headers without a response body or live timer', async () => {
    const proxy = bridge(async (_url, init) => {
        assert.equal(init.method, 'HEAD');
        assert.equal(init.body, undefined);
        return new Response(null, { status: 200, headers: { 'Content-Type': 'application/json', 'X-Request-ID': 'synthetic' } });
    });
    const response = await proxy.handle(request('/healthsync/health', { method: 'HEAD' }));
    assert.equal(response.status, 200);
    assert.equal(response.body, null);
    assert.equal(response.headers.get('x-request-id'), 'synthetic');
    assert.equal(proxy.timers.size, 0);
});
