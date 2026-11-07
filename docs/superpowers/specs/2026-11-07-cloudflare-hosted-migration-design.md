# Hosted Cloudflare migration design

The production Supabase project `dtzydnjnqkruxaacgkio` exhausted its Free disk. The owner purchased Pro and authorized recovery, a verified backup, a real-data simulation, and production migration. Preserve every existing custom bearer token, workspace and health record. No user action is required.

## Compatibility and architecture

Move the hosted API to Cloudflare Workers and its seven application tables to D1. These tables are `workspaces`, `devices`, `workspace_devices`, `access_tokens`, `sync_batches`, `health_metrics`, and `health_workouts`. Supabase Auth, Storage and Realtime are not dependencies of this API. Preserve the deployed function version 10 response contract, including `workspace_id` on list responses and deterministic ordering on tied timestamps.

Preserve existing token hashes and the exact effective HMAC secret. The effective secret was privately verified against the deployed secret metadata; it is the current default secret API key, not the legacy service-role JWT. Store its bytes as the independent Cloudflare `TOKEN_HASH_SECRET`. Never print credentials, bearer tokens, token hashes, health records or request bodies in logs or reports.

Use `https://api.healthysync.app` for the new backend. Existing apps hardcode a Supabase-owned hostname and existing agents have saved URLs there. Retain that function as a server-side forwarder preserving Authorization, method, path, query, body, status and response headers. A redirect does not satisfy this requirement. New app releases and newly provisioned endpoints use the owned hostname. Removing the last Supabase forwarding dependency requires old clients to stop using that hostname. The intention is to remove Pro before the next billing period after checking the unrelated `still-reading` project's needs and Free compatibility.

## Backup and migration safety

Do not modify production application data or deploy the new backend before a current consistent source backup has been restored and verified locally. Configuration-only backup and synthetic simulation are already complete, but they are not database backup verification.

Take one PostgreSQL custom-format dump in a consistent transaction, capturing the application schema/data and database metadata necessary to restore it. Restore into isolated PostgreSQL 17. Export all seven tables from that restored snapshot into a portable manifest with column names, primary keys, counts and SHA-256 digests of canonical rows. JSON objects are recursively key-sorted; timestamps are normalized to UTC preserving microseconds; numbers are compared without avoidable precision loss. Preserve nulls, metadata, composite keys and foreign keys. Keep all data files in ignored mode-0700 directories and mode-0600 files.

Use a second, separate local D1 database for rehearsal. Import the restored real snapshot, compare every table count and digest, and compare representative read responses with the frozen PostgreSQL baseline. Test synthetic mutations in a separate cloned database. Never issue reset or token-rotation tests against real workspaces. Raw bearer tokens cannot be recovered from hashes; test any existing locally available token privately and otherwise report the distinction between token-record/secret preservation and live bearer validation.

A final snapshot must cover changes after the initial backup. Before final export, install a reversible database write barrier on all seven tables in one transaction that drains prior writers. Fail subsequent writes explicitly; never acknowledge writes that were not committed. After final snapshot verification and D1 import, deploy the legacy forwarder and enable Cloudflare as the only writer. Keep source frozen as rollback evidence. Rollback must preserve any writes accepted by Cloudflare; never point traffic at a stale source snapshot. A short retryable maintenance interval is acceptable; silent data loss or a token reset is not.

## Runtime requirements

Use request-scoped state. D1 writes for one logical mutation are atomic in a single `DB.batch`; do not acknowledge partial uploads. Default the target to locked: only exact `MIGRATION_STATE=active` enables application requests. Until the final frozen import is verified, all user routes return retryable 503 before token lookup so a stale snapshot cannot accept revoked tokens. Health reports readiness with a real D1 query.

Preserve source deterministic ICU en-US ordering within public timestamp ties and the device catalog, with per-column UTF-8 tie fallback. Validate the candidate comparator against source ordering and the actual Worker runtime; internal exhaustive scans can use BINARY keysets independently. Bound tie-key memory and query costs, and do not silently substitute binary public ordering.

Preserve ingest retry/upsert/delete semantics and token kind/revocation/workspace isolation. Bind at most 100 SQL parameters per statement. Split large `IN` queries and joins, preserving pagination across tied timestamps. Reject oversized requests before buffering an unbounded body. Paginated reads must not load all raw health history into Worker memory to build summaries. Use compact SQL projections in bounded keyset pages and incremental per-device/day statistics while preserving timezone and daily aggregate preference behavior. Retain one page and fixed statistics per summary group, never raw-history arrays. Gate production on measured worst-workspace memory, group/output cardinality, query count, latency and row costs; use grouped SQL/derived dates only if that rehearsal fails. Preserve exact source-record fields; compare derived floating-point summaries with a tight documented numeric tolerance where the order of additions differs.

Use today's compatibility date for the new Worker, installed Wrangler 4.151.3 and generated binding types. Enable observability and traces without logging sensitive URLs, queries, headers or bodies. Verify D1 capacity and account plan using actual imported size and measured query costs. Cloudflare has quotas and paid tiers; do not assume unlimited compute, storage or logs or silently purchase an upgrade.

## Acceptance

1. Current source backup exists privately, restores successfully, and has a verified seven-table manifest.
2. Real-data D1 rehearsal matches counts/digests and compatible read responses; synthetic tests cover authentication, isolation, large batches, pagination, aggregates, atomic failures and retry durability.
3. Production D1 matches the final frozen source snapshot before traffic cutover.
4. Old and new endpoints serve the same committed data with unchanged existing tokens, and a synthetic workspace can upload/read through both endpoints.
5. A post-cutover D1 export is verified, rollback instructions include accepted writes, and the remaining Supabase billing/hostname dependency is reported accurately.
