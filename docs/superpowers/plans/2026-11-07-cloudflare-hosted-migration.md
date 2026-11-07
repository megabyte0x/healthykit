# Cloudflare Hosted Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move hosted HealthSync data and compute to Cloudflare after a verified backup and real-data rehearsal, preserving existing tokens and URLs.

**Architecture:** Workers owns the API and D1 owns the seven application tables. A Supabase function forwards legacy URLs server-side. A frozen final snapshot prevents loss of concurrent upserts and deletions during cutover.

**Tech Stack:** TypeScript, Cloudflare Workers/D1, installed Wrangler 4.151.3/Miniflare 5, PostgreSQL 17/Docker, Python standard library.

**Spec:** `docs/superpowers/specs/2026-11-07-cloudflare-hosted-migration-design.md`

## Global Constraints

- Preserve every existing custom bearer token, workspace and health record. No user action is required.
- Preserve the deployed function version 10 response contract, including `workspace_id` on list responses and deterministic ordering on tied timestamps.
- Never print credentials, bearer tokens, token hashes, health records or request bodies in logs or reports.
- Do not modify production application data or deploy the new backend before a current consistent source backup has been restored and verified locally.
- Bind at most 100 SQL parameters per statement.
- Never issue reset or token-rotation tests against real workspaces.
- Do not silently purchase an upgrade or modify the unrelated `still-reading` project.

## File responsibilities

- `scripts/cloudflare_snapshot.py`: private portable snapshot canonicalization, manifest verification and SQLite import/export; no embedded credentials.
- `scripts/test_cloudflare_snapshot.py`: synthetic round-trip, precision, null, FK and corruption tests.
- `cloudflare/migrations/0001_hosted.sql`: D1 schema and indexes.
- `cloudflare/src/index.ts`: HTTP API, validation, authentication and route wiring.
- `cloudflare/src/store.ts`: parameterized D1 transactions, joins and pagination.
- `cloudflare/src/summaries.ts`: bounded projected-row scans and incremental summary statistics.
- `cloudflare/src/collation.ts`: source-compatible text comparison and bounded timestamp-tie selection.
- `cloudflare/test/hosted.test.mjs`: actual Miniflare/D1 behavior tests against synthetic fixtures.
- `cloudflare/wrangler.jsonc`, `package.json`, `tsconfig.json`, `worker-configuration.d.ts`: isolated backend build/deploy/runtime configuration using existing web toolchain.
- `supabase/functions/healthsync/index.ts`: small legacy forwarder after final data migration.
- `HealthSync/AppSettings.swift`: owned hostname for future app releases.
- `docs/operations/cloudflare-hosted.md`: verified backup, rehearsal, cutover, rollback and billing runbook.

### Task 1: Build and verify private snapshot tooling

**Files:** Create `scripts/cloudflare_snapshot.py`, `scripts/test_cloudflare_snapshot.py`.

**Interfaces:** `python3 scripts/cloudflare_snapshot.py manifest SNAPSHOT.json OUTPUT.json`; `verify SNAPSHOT.json MANIFEST.json`; `sqlite-import SNAPSHOT.json DATABASE.sqlite SCHEMA.sql`; `sqlite-export DATABASE.sqlite OUTPUT.json`. Portable JSON is `{ "tables": { "table_name": [rowObjects] } }`. The seven tables are in FK order: workspaces, devices, workspace_devices, access_tokens, sync_batches, health_metrics, health_workouts. The manifest contains only counts and SHA-256 digests, never row values. All created data files are mode 0600.

- [ ] Write failing unittest cases for canonical equivalence across timestamp offsets and JSON key ordering, preserved microseconds/nulls/Unicode/composite keys, deterministic row ordering and corruption detection. Use `2026-11-07T10:00:00.123456+05:30` versus `2026-11-07T04:30:00.123456Z` in a fixture. A SQLite round trip must compare equal. Floats must not be rounded to fewer than their round-trip precision.
- [ ] Run `python3 -m unittest scripts/test_cloudflare_snapshot.py`; record the expected missing implementation failure.
- [ ] Implement canonical values using timezone-aware datetime without millisecond truncation, recursive JSON sorting and primary-key ordering. SQLite stores metadata as JSON text and timestamps as canonical UTC strings. Compare parsed JSON metadata rather than serialized whitespace. Table definitions/columns come from the snapshot; reject unknown table/column identifiers and incomplete table sets. Import inside a transaction with FK validation, fail on integrity violation, and do not silently replace a populated destination.
- [ ] Run the focused unittest suite and self-review the diff for accidental sensitive outputs. Do not connect to production. Do not read the private secret file.
- [ ] Commit only these scripts with a conventional subject and report the exact RED/GREEN evidence.

### Task 2: Implement the compatible Workers and D1 backend

**Files:** Create `cloudflare/src/index.ts`, `cloudflare/src/store.ts`, `cloudflare/src/summaries.ts`, `cloudflare/src/collation.ts`, `cloudflare/migrations/0001_hosted.sql`, `cloudflare/test/hosted.test.mjs`, `cloudflare/package.json`, `cloudflare/tsconfig.json`, `cloudflare/wrangler.jsonc`, generated `cloudflare/worker-configuration.d.ts`.

**Interfaces:** Worker default `{fetch(request, env, ctx)}`; bindings `DB: D1Database`, `TOKEN_HASH_SECRET: string`; variables `HOSTED_PUBLIC_BASE_URL=https://api.healthysync.app`, `MIGRATION_STATE=locked`. Only exact `MIGRATION_STATE=active` permits application requests; default/missing/locked returns retryable 503 before auth or state access. Health queries D1 and reports locked/readiness accurately. Controller activates only after the final frozen import is verified. Store owns D1 SQL and mutation batches. Snapshot tools consume the D1 schema path. Use the source baseline in `.healthsync-backups/2026-11-07-recovery/index.ts` (code only; never read `token-hash-secret`). Existing prototype in `/private/tmp/healthsync-cloudflare-rehearsal-20261107` is experimental reference, not production implementation.

- [ ] Read deployed v10 and all seven `backend/models.py` table definitions. Write failing runtime tests that exercise real Miniflare D1 and Worker requests. Use installed `web/node_modules` tooling; no package upgrades. Miniflare 5 needs `convertV4MiniflareOptions` and `resourcePersistencePath`. Synthetic fixtures only; outbound network disabled.
- [ ] Cover all eight v10 API routes plus CORS, missing/incorrect/revoked/wrong-kind tokens, workspace isolation, reset/rotate on synthetic workspaces, >1000 tied timestamp rows, >500 export IDs, 100+ row upserts/deletions, duplicate retry after dropped response, atomic failure rollback, timezone-local dates, preference spanning scan pages, partial-day daily-aggregate exclusion, timezone changes on existing exports with omitted children, daily aggregate preference per device, nullable workout energy/distance and Unicode metadata. Add concurrent reset/ingest and revoked-before-batch guards, plus failed-statement rollback tests in the actual D1 runtime. Assert actual response shapes including `workspace_id` and stable order. Check health against a DB read rather than returning a misleading always-ok result.
- [ ] Run tests before implementation and record RED evidence. Implement request-scoped handlers, independent HMAC secret, parameterized queries, bounded request parsing, exact wire fields/statuses, and atomic logical mutation batches. Handle upsert retry counts compatibly. Use compact keyset pages (initially 5,000 rows) joining each record to its current sync timezone. Project only summary/cursor fields and a boolean preferred-daily marker; retain incremental raw/preferred stats per device/day, never raw-history arrays. Cache Intl formatters per request, preserve arbitrary partial-day filters and reflect timezone changes on existing exports without stale derived dates. Check group/output cardinality, query count, memory, latency and row-read costs against the restored real data before production. Compare preserved record fields exactly and derived floating-point sums with documented tight tolerances where addition order differs. If a compatibility invariant requires an architectural decision, report it before substituting behavior.
- [ ] Preserve source ICU deterministic `en-US` text ordering for timestamp ties and workspace-device ordering. Candidate comparator is request-scoped Intl.Collator with usage sort, sensitivity variant, numeric false, ignorePunctuation false; break ICU-equal strings by UTF-8 bytes for each column before moving to the next. Use bounded compact tie-key selection before fetching selected payloads; sorting an already-truncated binary page is incorrect. Internal summary keysets stay BINARY. Read worker-design-advice.md addendum for the bounded boundary-group approach and source/runtime fingerprint acceptance gate. Cover case/punctuation/digits/accented/non-Latin/supplementary/Unicode-equivalent IDs; huge ties and both boundary groups; offset 0/100000 and limit 1/500; budgets; concurrent selection/fetch changes must retry or fail explicitly. Measure preserved tie groups privately in controller rehearsal.
- [ ] Use `compatibility_date=2026-11-07`, Worker name `healthsync-api`, account `1378ab230486e0367cbcb49a0f4cec1d`, observability/traces enabled with sensitive request invocation logging disabled. Leave production D1 ID unset until controller creates the named isolated resource; do not deploy or mutate remote resources. Generate binding types with project-local Wrangler. Use safe structured error messages without raw request URLs/data.
- [ ] Run runtime suite, typecheck and Wrangler dry-run packaging. Capture exact outputs in report. Commit only task files, no secrets/backups/runtime persistence.

### Task 3: Implement legacy forwarding and future client configuration

**Files:** Modify `supabase/functions/healthsync/index.ts`, `HealthSync/AppSettings.swift`; create `cloudflare/test/legacy.test.mjs`, `docs/operations/cloudflare-hosted.md`.

**Interfaces:** Legacy server forwards to `https://api.healthysync.app`, stripping only `/functions/v1/healthsync` or `/healthsync` prefix. New backend supports direct `/api/...` routes. No redirects and no Supabase data access remain in the bridge. Controller deploys this only after the final snapshot is verified.

- [ ] Write failing tests using an injected/mock upstream fetch to inspect method, full path/query, Authorization, content-type, exact body bytes and response status/body/headers. Include CORS OPTIONS, upstream timeout/failure and ensure errors disclose no secret or health data. Test both accepted legacy path prefixes and direct path behavior.
- [ ] Implement a streaming server-side proxy with fixed allowlisted upstream, no credential logging, no automatic unsafe replay, response passthrough and a bounded timeout returning retryable 503 on connection failure. Validate upstream by construction; no user-controlled target. Preserve JSON error bodies and HTTP statuses.
- [ ] Change the default hosted URL for future app builds to the owned domain without resetting any saved tokens or settings. Existing released apps remain supported through the bridge.
- [ ] Write concrete runbook commands for consistent PostgreSQL dump/restore, private snapshot manifest, local D1 rehearsal, source write barrier/drain, final snapshot import, digest verification, enabling the bridge, old/new endpoint smoke checks, D1 export and rollback that retains post-cutover writes. Include source-boundary tests and billing checks before a downgrade. Do not claim operations already passed.
- [ ] Run forwarding tests, relevant app/config validation available in this repository, self-review and commit task files.

### Task 4: Rehearse real data and execute controlled production cutover

**Files:** Update `docs/operations/cloudflare-hosted.md` with sanitized measured evidence. Private results remain under `.healthsync-backups/`.

**Interfaces:** Uses the verified PG snapshot, snapshot tools, Worker/D1 schema, and legacy bridge from previous tasks. This operational task belongs to the controller; no implementer may deploy before the controller's backup and simulation gates pass.

- [ ] Wait for actual SQL reads and writes after Pro restart. Take current consistent custom-format PostgreSQL dump privately, restore isolated PostgreSQL 17, export seven tables from the restored copy and verify manifest. Record dump digest, restored table counts/digests, source snapshot time and restoration errors without row values. Preserve roles/config separately if required. Do not restore an older server backup over production.
- [ ] Import into isolated local D1 and verify all seven counts/digests. Compare real snapshot read results through a safe local reference implementation; use only cloned synthetic mutations. Run any existing locally available real bearer privately without printing or persisting it in tracked files. If none is available, explicitly report token-record/secret verification limits.
- [ ] Check actual Cloudflare plan, D1 capacity, worker/domain conflicts and measured execution/row costs. Create only HealthSync-specific resources. Ask for a concrete paid upgrade only if required and not already enabled.
- [ ] Install reversible source write barrier, drain active writes and take final consistent snapshot. Import target D1; verify counts/digests before routing. Deploy Worker with existing HMAC secret through protected stdin, configure owned domain, then deploy old endpoint forwarder. Keep source frozen. Do not delete original data or rotate tokens.
- [ ] Verify old/new endpoints, existing token if available, isolated synthetic workspace upload/read/retry through both routes, D1 persistence and post-cutover export. Remove only synthetic test records created by this task if verified removable; retain real data. Record authoritative backend and rollback strategy.
- [ ] Verify downgrade feasibility and unrelated project impact, then eliminate future Pro renewal only when compatible with existing endpoint continuity and user authorization. If a remaining platform constraint prevents full removal, report the exact dependency and actionable next step. Complete final branch review before declaring migration finished.
