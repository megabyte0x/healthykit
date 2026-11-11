# perf(cloudflare): reuse unchanged agent summaries

`GET /api/agent/health-data` keeps its existing response schema, authentication, pagination, filters, date boundaries, summary ordering and daily-preference rules. Only the two summary arrays are cached. Raw metric/workout/sync pages and discovery catalogs are still read on every request, and token authorization is checked before returning a response.

Each Worker isolate keeps up to 128 serialized summary entries, with an 8 MiB total UTF-8 byte budget, a 1 MiB entry limit and a fixed 60-second lifetime. Least recently used entries are evicted first. Oversized summaries use the existing scan path. The key contains the workspace, a database-generated revision and normalized metric/workout filters; `limit` and `offset` do not affect summaries. Entries contain no bearer credentials or I/O objects. Cold isolates and requests with different filters perform their normal first scan.

Migration `0004_summary_revisions.sql` adds one small revision row per workspace and invalidation triggers. A summary request atomically clears the dirty marker and reads the current revision under the existing authorization guard. The first subsequent data change replaces the revision and sets the marker; further writes do not rewrite it until another summary read. This coalesces invalidation during a large upload while preserving invalidation across isolates and administrative SQL. A scan is cached only if its revision is still current at completion. Failed transactions roll revision changes back with the data.

Metric/workout changes, export timezone changes and cascaded deletions invalidate summaries. Workspace-device writes invalidate before ingest deletions, preserving the previous Worker's `meta.changes` deletion counts during rollout. The updated Worker counts `DELETE ... RETURNING` rows directly so its deletion count excludes trigger writes. Token rotation and workspace reset retain their existing authorization behavior.

## Rollout

Run the existing Worker suite, typecheck and dry run. Test invalidation, concurrent changes, reset/revocation and pre-migration fallback using isolated synthetic data. No production health rows are needed for these checks.

Apply the additive migration to `healthsync-hosted`, then deploy the Worker using the repository's pinned Wrangler:

```sh
web/node_modules/.bin/wrangler d1 migrations apply healthsync-hosted --config cloudflare/wrangler.jsonc --remote
web/node_modules/.bin/wrangler deploy --config cloudflare/wrangler.jsonc
```

The updated Worker also runs against the previous schema: if the revision table is absent, it computes summaries normally without using the cache. Other database errors retain their existing error handling. Existing Workers continue operating with the migration installed, so either rollout order and a Worker-only rollback are supported. Keep the revision table and triggers on rollback; do not drop the table while its triggers remain installed.

Inspect the existing `healthsync_capacity` events. Cache hits have `summaryCacheHits: 1` and `summaryRows: 0`; misses have `summaryCacheMisses: 1`. Compare `rowsRead` for equivalent ranges and verify that an upload makes the next request miss. These fields are operational logs only and do not change the public JSON response. Saved bytes and hit rate depend on isolate reuse, filter reuse, cache capacity and concurrent writes; catalogs and raw pagination still incur reads.
