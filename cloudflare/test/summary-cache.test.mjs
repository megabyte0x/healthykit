import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(new URL('../../web/package.json', import.meta.url));
const { build } = require('esbuild');
const source = (await build({ entryPoints: [new URL('../src/summary-cache.ts', import.meta.url).pathname], bundle: true, write: false, format: 'esm', platform: 'neutral' })).outputFiles[0].text;
const { SummaryCache } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));

test('summary cache expires without extending lifetime on a hit and evicts least recently used entries', () => {
    let time = 0;
    const cache = new SummaryCache({ bytes: 100, entryBytes: 50, entries: 2, ttlMs: 10 }, () => time);
    cache.put('a', '{"value":1}', 1, 8);
    cache.put('b', '{"value":2}', 1, 8);
    time = 5;
    assert.equal(cache.get('a').body, '{"value":1}');
    cache.put('c', '{"value":3}', 1, 8);
    assert.equal(cache.get('b'), undefined);
    time = 10;
    assert.equal(cache.get('a'), undefined);
    assert.equal(cache.get('c').body, '{"value":3}');
    time = 15;
    assert.equal(cache.get('c'), undefined);
});

test('summary cache bounds UTF-8 bytes and skips oversized results without losing other entries', () => {
    const cache = new SummaryCache({ bytes: 12, entryBytes: 10, entries: 10, ttlMs: 10 }, () => 0);
    cache.put('a', 'ééé', 1, 2);
    cache.put('b', 'ééé', 1, 2);
    assert.equal(cache.get('a'), undefined);
    assert.equal(cache.get('b').body, 'ééé');
    cache.put('huge', '😀😀', 1, 2);
    assert.equal(cache.get('huge'), undefined);
    assert.equal(cache.get('b').body, 'ééé');
    cache.put('b', 'x', 1, 2);
    cache.put('c', 'ééé', 1, 2);
    assert.equal(cache.get('b').body, 'x');
    assert.equal(cache.get('c').body, 'ééé');
});
