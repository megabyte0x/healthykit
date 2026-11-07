# feat(hosted): move hosted storage to Cloudflare with legacy forwarding

This is the controller's cutover and recovery runbook. Commands below are operational instructions, not evidence that they have run. Task 3 performs local synthetic verification only. Record subsequent hosted results, timestamps, resource IDs, versions and sanitized counts/digests in the evidence section before declaring cutover complete.

The authoritative endpoint after accepted cutover is `https://api.healthysync.app`. The released application still uses `https://dtzydnjnqkruxaacgkio.supabase.co/functions/v1/healthsync`; that Supabase-owned hostname requires a live `healthsync` Edge Function. The bridge forwards server-side to the owned domain without redirecting or replaying a request. Preserve the existing HMAC secret and all seven application tables; existing opaque bearer tokens must continue to work. Never rotate credentials to perform this migration.

Future app builds use the owned domain. Changing `AppSettings.hostedBackendURL` does not edit saved settings or Keychain entries. `prepareHostedStorageIfNeeded` checks saved endpoint/token presence, not equality with the new URL. A complete saved workspace remains ready; its existing agent endpoint continues through the bridge until the user deliberately refreshes it.

## Private working area and gates

Run from the repository root in a shell without tracing. Use existing controller authentication; never paste bearer values, database passwords or the HMAC secret into commands, logs, issue comments or tracked files. Private files contain health data even when tokens are hashed.

```bash
set +x
umask 077
recovery="$PWD/.healthsync-backups/2026-11-07-recovery"
initial="$PWD/.healthsync-backups/2026-11-08-verified-initial"
run="$PWD/.healthsync-backups/$(date -u +%Y-%m-%dT%H%M%SZ)-cutover"
mkdir -m 700 "$run"
wrangler="$PWD/web/node_modules/.bin/wrangler"
schema="$PWD/cloudflare/migrations/0001_hosted.sql"
```

Keep private directories mode 0700 and all snapshot/SQL/export/log/config/manifest files mode 0600, including files created by third-party tools. Precreate redirected outputs under this umask and check permissions with `stat -f '%Lp %N' FILE`. Never pipe a D1 dump to stdout, `cat` snapshots, or print SQL containing data. Store digests privately; tracked evidence contains only aggregate counts, digest comparisons and timing. Do not read private helpers casually: their named interfaces below are supplied by the controller, who validates their current code before running them.

Before any production change, require reviewed application/bridge commits, successful local tests, verified backups, an isolated restored PostgreSQL 17 reference, full seven-table D1 digest equality, source/runtime collation and boundary acceptance, measured summary costs and resource limits, and an explicit rollback owner. Check that `healthsync-hosted` is the intended isolated database in account `1378ab230486e0367cbcb49a0f4cec1d` (`d66fac78-02c1-4012-9bfa-2f3e38644852`, US jurisdiction/ENAM). The controller reported existing Workers Paid; verify current account capacity instead of purchasing another plan. Confirm domain/Worker ownership and unrelated resources before editing configuration.

```bash
node --test cloudflare/test/legacy.test.mjs
npm --prefix cloudflare test
npm --prefix cloudflare run typecheck
python3 -m unittest scripts/test_cloudflare_snapshot.py
```

`npm test` currently runs the Worker suite only; run the bridge command separately. The synthetic suites must not contact production or mutate existing app/simulator data.

## Consistent PostgreSQL backup and independent restores

For a fresh privileged backup, use a PostgreSQL 17 client with a controller-created mode-0600 `PGSERVICEFILE`/passfile outside tracked files. The service entry supplies credentials and TLS settings. `pg_dump` uses a consistent database snapshot; do not replace it with unrelated per-table live queries. Capture public schema plus all eight public tables, including the nonapplication table. Retain original roles/configuration information separately and protect it as a secret.

```bash
PGSERVICE=healthsync-source pg_dump --format=custom --schema=public \
  --file="$run/public.pgdump" >"$run/pg-dump.log" 2>&1
chmod 600 "$run/public.pgdump" "$run/pg-dump.log"
shasum -a 256 "$run/public.pgdump" >"$run/public.pgdump.sha256"
pg_restore --list "$run/public.pgdump" >"$run/archive-list.txt"
```

Restore twice into separately named PostgreSQL 17 containers with no published ports. These containers are disposable clones, never production. Use the matching image digest recorded by the controller; configure clone-only roles/extensions required by the archived public schema if necessary. `--exit-on-error` is mandatory; inspect exit status and the private logs before proceeding.

```bash
docker run -d --name healthsync-cutover-restore-a --network none \
  -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17 >"$run/restore-a-container.txt"
docker run -d --name healthsync-cutover-restore-b --network none \
  -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17 >"$run/restore-b-container.txt"
docker exec healthsync-cutover-restore-a pg_isready -U postgres
docker exec healthsync-cutover-restore-b pg_isready -U postgres
docker exec -i healthsync-cutover-restore-a pg_restore -U postgres -d postgres \
  --exit-on-error --no-owner --no-privileges <"$run/public.pgdump" >"$run/restore-a.log" 2>&1
docker exec -i healthsync-cutover-restore-b pg_restore -U postgres -d postgres \
  --exit-on-error --no-owner --no-privileges <"$run/public.pgdump" >"$run/restore-b.log" 2>&1
python3 "$recovery/stream_rehearsal.py" export healthsync-cutover-restore-a "$run/canonical-a" >"$run/export-a.log" 2>&1
python3 "$recovery/stream_rehearsal.py" export healthsync-cutover-restore-b "$run/canonical-b" >"$run/export-b.log" 2>&1
cmp "$run/canonical-a/manifest.json" "$run/canonical-b/manifest.json"
```

Wait for each clone's readiness before the restore; a failed `pg_isready` means stop and retry readiness, not the restore. Confirm counts for all eight public tables through the controller's backup verification. The canonical application manifest covers exactly seven tables in FK order: `workspaces`, `devices`, `workspace_devices`, `access_tokens`, `sync_batches`, `health_metrics`, `health_workouts`. Compare canonical row digests, not just counts, and preserve microseconds, nullable values, JSON, Unicode and numeric precision.

The controller's initial backup was verified at **2026-11-08 00:57 IST**: all eight public tables, **1,743,287 rows**, two independent PostgreSQL 17 restores; all seven D1 application-table digests matched **1,743,286 rows**, and **36/36** local real-data read cases matched. This is initial rehearsal evidence supplied by the controller. It is not a final frozen snapshot or hosted cutover result.

## Portable manifests and local D1 rehearsal

The tracked snapshot utility supports a small/private portable JSON snapshot shaped as `{"tables":{"workspaces":[],...}}`. Its manifest contains counts and SHA-256 digests only. These commands never print rows:

```bash
python3 scripts/cloudflare_snapshot.py manifest "$run/snapshot.json" "$run/manifest.json"
python3 scripts/cloudflare_snapshot.py verify "$run/snapshot.json" "$run/manifest.json"
python3 scripts/cloudflare_snapshot.py sqlite-import "$run/snapshot.json" "$run/rehearsal.sqlite" "$schema"
python3 scripts/cloudflare_snapshot.py sqlite-export "$run/rehearsal.sqlite" "$run/roundtrip.json"
python3 scripts/cloudflare_snapshot.py verify "$run/roundtrip.json" "$run/manifest.json"
```

For the full large dataset, use the controller's bounded canonical JSONL exporter/importer instead of materializing every row in one process. Do not interchange its manifest format with the portable utility without an explicit conversion and comparison.

```bash
python3 "$recovery/stream_rehearsal.py" import "$run/canonical-a" "$run/rehearsal.sqlite" "$schema" >"$run/local-import.log" 2>&1
python3 "$recovery/stream_rehearsal.py" verify "$run/canonical-a" "$run/rehearsal.sqlite" >"$run/local-verify.log" 2>&1
python3 "$recovery/build_d1_sql.py" "$run/canonical-a" "$schema" "$run/rehearsal.sql" >"$run/build-sql.log" 2>&1
chmod 600 "$run/rehearsal.sqlite" "$run/rehearsal.sql"
python3 - "$run/local-wrangler.json" <<'PY'
import json, sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({
    "name": "healthsync-rehearsal", "compatibility_date": "2026-11-07",
    "d1_databases": [{"binding": "DB", "database_name": "healthsync-hosted",
                      "database_id": "synthetic-rehearsal"}]
}))
PY
"$wrangler" d1 execute healthsync-hosted --config "$run/local-wrangler.json" --local \
  --file "$run/rehearsal.sql" --yes >"$run/local-d1-import.log" 2>&1
"$wrangler" d1 export healthsync-hosted --config "$run/local-wrangler.json" --local \
  --output "$run/local-d1.sql" --table workspaces devices workspace_devices access_tokens sync_batches health_metrics health_workouts >"$run/local-d1-export.log" 2>&1
chmod 600 "$run/local-d1.sql"
sqlite3 "$run/local-d1-export.sqlite" <"$run/local-d1.sql" >"$run/local-d1-restore.log" 2>&1
python3 "$recovery/stream_rehearsal.py" verify "$run/canonical-a" "$run/local-d1-export.sqlite" >"$run/local-d1-verify.log" 2>&1
```

Use a fresh run directory and empty SQLite destinations. The SQL builder includes schema: do not preapply the same schema/migrations. Both local Wrangler commands use the same private configuration and default persistence rooted beside it, so export addresses the database just imported. Do not add `--persist-to` only to import: the installed export command has no matching option. The controller's direct local SQLite rehearsal and full manifests remain a separate verified gate.

Run private source-boundary comparisons against restored data: all four read routes, unfiltered and type/activity/device filters, limit 1/500, offset 0/100000, both timestamp boundary groups, ICU-equivalent/case/punctuation/accented/non-Latin/supplementary IDs, microsecond containment, DST/historical timezone cases, per-device daily preference, and nullable workout fields. Compare preserved fields and list order exactly; record tight documented tolerances only for derived floating-point sums. Measure worst-case summaries, latency, rows read, response size, tie/group/query budgets and source/runtime collation fingerprint. Test writes, reset/revoke, duplicate retry, stale authorization and drain races only on isolated synthetic clones/workspaces.

## Freeze and capture every final change

Keep target `MIGRATION_STATE=locked` throughout import and full verification. First install the controller-reviewed source barrier on **all eight public tables**, not just ingest routes: reads update `access_tokens.last_used_at`; reset, rotation, deletion, provisioning, administrative SQL and background jobs are also writes. Stop external writers/jobs where applicable. The verified SQL obtains `ACCESS EXCLUSIVE` locks in one transaction and adds statement guards for insert/update/delete/truncate. Existing writers must finish before the barrier commits; subsequent writes must fail. Record the commit time and drain result.

Use the Supabase connector, not guessed CLI database flags:

```javascript
await tools.mcp__codex_apps__supabase_apply_migration({
  project_id: "dtzydnjnqkruxaacgkio",
  name: "healthsync_cloudflare_cutover_freeze",
  query: exactReviewedMigrationBarrierSQL
});
```

`exactReviewedMigrationBarrierSQL` is the exact contents of the private `migration-barrier.sql`, including its transaction/lock statements. The controller must verify the API's transaction behavior before using it. Confirm all eight enabled freeze triggers and run the approved drain/32-mutation barrier tests against a clone. Do not probe real mutation cases destructively. The frozen original v10 can return errors even for authenticated reads because of its last-used write; this maintenance window is expected until the bridge is enabled.

After the barrier has committed and every source write path is confirmed blocked, either take another consistent privileged dump using the procedure above or use the controller's verified frozen HTTPS backup helper. With all eight tables immutable, separately paginated HTTPS exports are consistent; without that proven freeze they are not. The helper checks trigger coverage, compares source schema against the independently restored initial schema, captures all current rows, and restores twice into PostgreSQL 17. Reusing the initial schema archive is allowed only after metadata equality. No new privileged login or role creation is required for this path.

```bash
python3 "$recovery/frozen_backup.py" "$run/final" healthsync-final-restore >"$run/final-backup.log" 2>&1
```

Require successful backup verification, both restore results and canonical manifests. The final snapshot must include every intervening insertion, update, deletion, reset and token revocation, not an append-only delta. Preserve the initial and final artifacts separately. The controller records the helper's exact final output paths and version in private evidence before the next step; set `finalCanonical` to that verified canonical directory.

## Import and verify the locked hosted target

Use the exact intended D1 ID in controller-reviewed configuration; the checked-in Worker remains locked by default. Confirm the target is empty and isolated before an import. Never import over a populated live database or clear a failed/partial import without a retained export and reviewed recovery action. Keep the source frozen.

```bash
python3 "$recovery/build_d1_sql.py" "$finalCanonical" "$schema" "$run/final.sql" >"$run/final-build.log" 2>&1
chmod 600 "$run/final.sql"
"$wrangler" d1 execute healthsync-hosted --config cloudflare/wrangler.jsonc --remote \
  --file "$run/final.sql" --yes >"$run/remote-import.log" 2>&1
"$wrangler" d1 export healthsync-hosted --config cloudflare/wrangler.jsonc --remote \
  --output "$run/remote-verified.sql" --table workspaces devices workspace_devices access_tokens sync_batches health_metrics health_workouts >"$run/remote-export.log" 2>&1
chmod 600 "$run/remote-verified.sql"
sqlite3 "$run/remote-verified.sqlite" <"$run/remote-verified.sql" >"$run/remote-restore.log" 2>&1
python3 "$recovery/stream_rehearsal.py" verify "$finalCanonical" "$run/remote-verified.sqlite" >"$run/remote-digest-verify.log" 2>&1
```

A successful import command or row total alone is insufficient. Require **all seven canonical count and digest matches**, FK integrity, preserved token records/secret, valid schema and Worker readiness/configuration checks. The controller may use its reviewed bounded hosted-export harness instead if the SQL restore path cannot safely process the full dump; require the same complete comparison. Supply the unchanged HMAC secret through the protected connector/stdin path, with no secret in command arguments or returned tool output. Never copy the Supabase service-role key into the Worker.

## Activate the owned endpoint, then deploy the bridge last

Only after complete final verification, activate the Worker on the owned domain. Preserve the exact D1 binding and public URL, observability redaction and reviewed settings. Record the deployed version; readiness must perform a real D1 query. A locked health response is 503 and must never be labeled healthy.

```bash
"$wrangler" deploy --config cloudflare/wrangler.jsonc \
  --var MIGRATION_STATE:active --var HOSTED_PUBLIC_BASE_URL:https://api.healthysync.app \
  --domain api.healthysync.app >"$run/worker-activate.log" 2>&1
curl --silent --show-error --max-time 65 --output "$run/new-health.json" \
  --write-out '%{http_code}\n' https://api.healthysync.app/health
```

Verify the current Wrangler flag interface and actual domain/conflicts before deployment. Inspect private health output and require `ok/ready/database=true` and `migration_state=active`. From this point D1 is authoritative and may receive writes; never unfreeze the old source merely because the bridge has a problem.

Deploy the reviewed forwarder **last** using the Supabase connector. This replaces the served legacy function immediately. Keep JWT gateway verification disabled as in released v10; the Worker authenticates the unchanged custom bearer in `Authorization`.

```javascript
await tools.mcp__codex_apps__supabase_deploy_edge_function({
  project_id: "dtzydnjnqkruxaacgkio",
  name: "healthsync",
  entrypoint_path: "index.ts",
  files: [{ name: "index.ts", content: exactReviewedForwarderSource }],
  verify_jwt: false
});
```

The source is `supabase/functions/healthsync/index.ts`. No database client, database credential reads or request logging remain in that file. It strips only complete `/functions/v1/healthsync` or `/healthsync` prefixes, forwards methods/query/Authorization/body, and preserves upstream HTTP status and end-to-end response headers. Hop-by-hop headers and decoded-body encoding/length are removed; identity encoding is requested. The 60-second deadline covers response consumption and client cancellation, below the documented [Free 150-second Edge Function wall-clock limit](https://supabase.com/docs/guides/functions/limits). Before headers, connection failures/timeouts give a generic retryable 503; after headers have streamed, failure terminates the body because HTTP status can no longer change. No automatic replay or redirect following occurs. An ambiguous failed write must be investigated with the existing export/workspace IDs and ordinary durable retry behavior.

## Old/new smoke checks and post-cutover export

```bash
legacy=https://dtzydnjnqkruxaacgkio.supabase.co/functions/v1/healthsync
curl --silent --show-error --max-time 65 --output "$run/old-health.json" \
  --write-out '%{http_code}\n' "$legacy/health"
curl --silent --show-error --max-time 65 --request OPTIONS --output /dev/null \
  --dump-header "$run/old-options.headers" --write-out '%{http_code}\n' "$legacy/api/apple-health/sync"
curl --silent --show-error --max-time 65 --output "$run/new-missing-auth.json" \
  --write-out '%{http_code}\n' https://api.healthysync.app/api/agent/metrics
curl --silent --show-error --max-time 65 --output "$run/old-missing-auth.json" \
  --write-out '%{http_code}\n' "$legacy/api/agent/metrics"
```

Require both health checks to return 200 with matching readiness; OPTIONS 204 with expected CORS; both missing-bearer checks 401 with the compatible JSON error. Do not use `curl -L`. For authenticated reads, use a mode-0600 curl config containing the existing bearer (`curl --config "$run/agent-read.curl" --url URL --output PRIVATE_FILE`), never `-H` with a real token in shell history. Run all four read routes through old/new endpoints with identical query strings; compare canonical JSON privately. If no existing bearer is available, explicitly state that existing-token acceptance is unproven despite secret/hash record checks.

Create one clearly isolated synthetic hosted workspace; store provisioning responses privately. Upload a known synthetic payload through each endpoint, repeat its exact export ID and verify durable duplicate counts, compare old/new reads and pagination, and verify D1 persistence. Exercise rotation/reset/revocation only on that synthetic workspace, including that old tokens fail. Remove only those exact synthetic records after verifying scope; never bulk-delete or touch a real workspace. Capture post-cutover writes in a new private D1 export and verify its full canonical contents independently. Its manifest can differ from the frozen baseline because successful reads update `last_used_at` and writes are now accepted. Record those expected differences rather than claiming the original digest is still equal.

```bash
"$wrangler" d1 export healthsync-hosted --config cloudflare/wrangler.jsonc --remote \
  --output "$run/post-cutover.sql" --table workspaces devices workspace_devices access_tokens sync_batches health_metrics health_workouts >"$run/post-cutover-export.log" 2>&1
chmod 600 "$run/post-cutover.sql"
shasum -a 256 "$run/post-cutover.sql" >"$run/post-cutover.sql.sha256"
```

## Rollback without losing accepted D1 writes

Before activation, a failed verification leaves the target locked and source frozen; repair/rehearse or explicitly restore the original source service and remove only the reviewed freeze objects after proving no target writes were accepted.

After activation, keep D1 as the sole authority. A code rollback should deploy a known compatible Worker version against the **same D1 database**, retaining all accepted writes and the same HMAC secret. Keep the legacy bridge pointed to the owned domain. Do not restore the initial snapshot or original database-serving Edge Function onto live traffic.

If a backend rollback to PostgreSQL is necessary, first deploy `MIGRATION_STATE=locked`, confirm application requests fail closed, drain in-flight Worker requests and freeze other D1 writers. Export all seven current D1 tables privately using the export command above. Restore/export-verify in an isolated SQLite clone, convert to PostgreSQL with an independently tested transactional importer, and compare complete canonical digests after restoring into a fresh PostgreSQL 17 candidate. The reverse importer is an explicit recovery prerequisite, not shipped by Task 3: do not improvise it during an incident. A full replacement must retain D1-only inserts, updates, deleted rows, resets, rotated/revoked tokens and the current HMAC secret. Copying only new rows is insufficient.

Only after full candidate verification may the controller switch the owned-domain backend to the verified PostgreSQL service, preserving the bridge and URL, then remove exactly the eight reviewed freeze triggers and `public.healthsync_migration_block_write` function through a reviewed migration. Avoid broad `CASCADE` or unrelated schema changes. Verify old/new endpoints and tokens again before re-enabling writes. If reverse recovery is not ready, remain locked or repair the Worker in place; retain all exports and frozen source data.

## Billing and legacy-hostname continuity

Do not cancel/delete/pause the Supabase project as a side effect of moving database traffic. The immutable released-client/agent hostname still depends on its Edge Function. A client update alone does not prove all installed clients or copied agent URLs have moved. Keep source data frozen for rollback until a separate retention/recovery decision.

Before any downgrade, inspect the actual subscription, next renewal, add-ons, total database footprint, quotas and all organization projects. The controller reported a retained source database near 1.8 GB, above the current [Free 500 MB per-project database quota](https://supabase.com/docs/guides/platform/billing-on-supabase). Supabase billing is per organization; do not change the plan or transfer/delete an unrelated project that is still in use. Removing stored data or changing retention needs a separate authorized plan after verified independent recovery copies.

[Free project pausing](https://supabase.com/docs/guides/platform/free-project-pausing) depends on sufficient **database** activity over the preceding week. A bridge-only Edge Function does not query Supabase PostgreSQL, so forwarding traffic is not a guarantee against pausing. The [Supabase knowledge base](https://supabase.com/kb/faqs/platform/free-project-pausing) also cautions that a few daily queries do not guarantee exclusion. Do not promise an always-available Free legacy endpoint or silently add a database keepalive. Check current provider terms/support and the measured dependency before eliminating renewal. If reliable legacy continuity still requires paid hosting, report that remaining cost and the concrete exit condition: verified migration of all clients/copied agent endpoints or an agreed supported legacy-hostname strategy. No billing cancellation or future-renewal elimination is claimed here.

## Controller evidence to append after execution

- Final freeze transaction/time, all-eight-trigger coverage, prior-writer drain and final backup/restore verification.
- Final seven table counts/digest equality and schema/token-secret verification, with private artifact locations.
- Hosted resource IDs, Worker/bridge versions, domain, readiness, old/new route/token/synthetic-write acceptance, measured latency/rows and complete post-cutover export verification.
- Authoritative backend, rollback readiness, remaining hostname/retention dependency, actual billing decision and next renewal status.

Until these are populated with actual hosted results, the initial local rehearsal above is the only recorded real-data acceptance evidence in this runbook.

## Verified rehearsal on 8 November 2026

Production remained on Supabase during this rehearsal. The initial source checkpoint was 7 November19:27:18.786167UTC (8 November00:57:18IST). All181 source chunks verified after restoration; the103,416,359-byte public archive passed two independent PostgreSQL17 restores. The eight public tables contained1,743,287 rows, including one Alembic version row.

The seven application tables imported into a private1,801,981,952-byte SQLite/D1 rehearsal database with matching canonical counts/digests. A direct protected hosted D1 export independently matched all1,743,286 application rows. An arbitrary-precision JSONB metadata audit against PostgreSQL matched every metric/workout metadata object, avoiding float-based false positives. Every preserved source identifier was checked against source ICU ordering; the actual hosted November7 runtime fingerprint and HMAC continuity proof also matched.

All36 representative reads passed locally and in hosted Cloudflare across the five largest workspaces and an empty workspace. Hosted synthetic upload, duplicate retry, summary, rotation and reset checks passed; test-only credentials/workspaces/devices were removed. The largest224,353-metric workspace returned matching summaries with a64MiB live memory reserve. API execution is placed near the ENAM primary using the aws:us-east-1 placement hint; this selects Cloudflare infrastructure near that region. Normal and stressed timings are retained privately; this is not an unlimited-capacity claim.

The deployed schema has14 insert/update guards matching all31 PostgreSQL VARCHAR limits and text/JSONB Unicode constraints. Runtime tests:28pass; forwarding tests:12pass; offline snapshot tests:23pass. The saved-settings fixture and11 pure Swift configuration assertions passed without touching app Keychain data. The broader Task3 runtime attempt was sandbox-blocked; the independently executed Worker suite passed.

Source write-barrier rehearsal verified prior-writer drain and32 blocked insert/update/delete/truncate operations across eight tables. Forward-delta fixtures covered resets, parent deletion/cascade, updates, token changes, nullable metadata and exact floats. A native PostgreSQL reverse-import rehearsal passed12 guarded batches with all seven manifests matching and all eight source guards retained.

Final cutover still requires the fresh frozen backup, a fresh exact metadata audit, complete target digests with no harness application calls, and the bridge deployment. The protected harness is temporary and must be removed after final backup verification. Private operational evidence remains under .healthsync-backups/.

The normal compressed largest-history probe returned200:6.91seconds inside the Worker,9.59seconds to headers,10.28seconds total,267,115compressed bytes. This full-history operation is materially heavier than a bounded list; callers should retain their existing long-running-query timeout budget. There was no fixed latency SLA in this migration; the tested envelope remains below the60second forwarding deadline and30second production CPU limit. Do not describe Cloudflare capacity as unlimited.

Before the final delta, run the exact metadata audit again against the fresh frozen PostgreSQL restore and final SQLite. Stop all harness application calls during final verification, then compare every full-column raw SQLite/D1 chunk. The source and target must remain immutable for that comparison. The temporary admin harness is not a global write barrier.
