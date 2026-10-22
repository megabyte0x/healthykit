# HealthSync

HealthSync is a native SwiftUI iOS app that reads selected Apple Health data on-device through HealthKit and syncs queued JSON batches to a private REST backend.

There is no iCloud or server-side Apple Health REST API. Apple Health reads happen only on the iPhone after the user grants HealthKit read permissions. Health data stays on-device until the user accepts the default private hosted destination or configures a backend URL and auth token.

Website: https://healthysync.app

User documentation: https://healthysync.app/docs

Apple Health app sync guide: https://healthysync.app/apple-health-app-sync

Privacy policy: https://healthysync.app/privacy

Support: https://healthysync.app/support

## What It Syncs

- Steps, heart rate, resting heart rate, HRV SDNN
- Active energy, basal energy
- Body mass, body fat percentage
- Sleep analysis
- Workouts
- Optional dietary energy, macros, and water when available

The app requests read-only HealthKit permissions. It does not request write permissions, does not include analytics, and does not use third-party telemetry or health SDKs.

## Setup

Prerequisites:

- macOS with Xcode 16 or newer
- An iOS 17+ simulator or a real iPhone for HealthKit testing
- Python 3.11+ for backend scripts and tests
- Docker Desktop if you want the local Postgres backend

From the repo root, open the iOS project:

```bash
open HealthSync.xcodeproj
```

In Xcode, select the `HealthSync` target, set your development team for signing, confirm HealthKit Background Delivery and Background Modes (Background fetch) are enabled, then build for an iOS 17+ simulator or device.

For local persistent sync storage, copy the backend environment template and generate separate secrets for the app ingest token and hosted-token HMAC secret:

```bash
cp .env.example .env
python3 -m backend.scripts.generate_token
python3 -m backend.scripts.generate_token
```

Edit `.env`, replace `POSTGRES_PASSWORD`, paste the first generated value as `API_TOKEN`, paste the second generated value as `TOKEN_HASH_SECRET`, and keep `.env` uncommitted. Start the local API and Postgres stack:

```bash
docker compose up --build
```

Configure HealthSync settings with:

- Simulator backend URL: `http://127.0.0.1:8080`
- Real iPhone local test URL: `http://<mac-lan-ip>:8080`
- Production URL: an HTTPS endpoint
- Auth token: the same value as backend `API_TOKEN`

Run the backend test setup when changing persistence code:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
python3 -m pytest Tests/backend/test_backend_api.py -q
```

### Historical sync detail

Historical Sync offers **Daily summaries** (the existing default) or **Original blood
oxygen & HRV**. The latter exports individual blood oxygen and HRV records, retaining
sample UUIDs, timestamps, source attribution, units, and metadata. All other quantity
metrics retain daily sums/averages, including steps, energy, distance, and heart rate.
This preserves HealthKit statistics' overlap handling for cumulative metrics.

Both modes retain 30-day date windows. Blood oxygen and HRV in original mode are read
in bounded 100-record HealthKit pages; each page is queued and uploaded before the next
read. The existing durable queue, upload chunking, retries, and deduplication are reused.
Workouts and category samples crossing a window boundary are selected by start time in
original mode and retain their full end time. Sleep keeps its existing overlap query.
Empty windows do not each add a log row; a completely empty backfill logs once.

Large ranges can take longer; keep the app open while backfilling. Existing summary
records are not deleted. The backend summary view prefers existing aggregates; consumers
requiring original records should distinguish `metadata.aggregation` rather than add
summaries to samples. Blood oxygen records are discrete, not continuous monitoring.

## Backend Contract

The app posts to:

```text
POST {configured_backend_url}/api/apple-health/sync
```

Headers:

```text
Authorization: Bearer {token_from_keychain}
Content-Type: application/json
X-Device-Id: {stable_local_device_id}
X-App-Version: {app_version}
```

Every metric and workout uses a deterministic ID of `healthkit:{sample_uuid}`. Incremental payloads also include HealthKit deletions as `deletions: [{"id":"healthkit:{sample_uuid}","kind":"metric|workout"}]`. The backend scopes deletions to the authenticated workspace and originating device, so retries are safe and cannot remove another device's records.

Every upload batch has its own `export_id`. Failed additions and deletions remain queued locally for retry.

### Workout summaries

Workout activity names follow HealthKit's lowerCamelCase names, such as `elliptical`, `rowing`, and `highIntensityIntervalTraining`. Explicit Other workouts use `other`; unrecognized types use `hk_<rawValue>`. The original numeric type is always retained as the string `metadata.hk_workout_activity_type`.

Workout exports include the following values when the source records them and the user grants read access:

| Field | Meaning |
| --- | --- |
| `active_energy_kcal` | Active energy from workout statistics, falling back to HealthKit's legacy workout energy value. |
| `total_energy_kcal` | Active plus basal energy associated with the workout; omitted when either component is unavailable. |
| `distance_meters` | Recorded workout distance, with a fallback to the sum of associated distance statistics, including rowing on supported iOS versions. Elliptical distance is preserved when recorded by the source. |
| `metadata.average_heart_rate_bpm` | Average heart rate from associated workout statistics. |
| `metadata.max_heart_rate_bpm` | Maximum heart rate from associated workout statistics. |
| `metadata.average_mets` | Average METs from workout metadata, falling back to associated physical-effort statistics, in kcal/(kg·hour). |
| `metadata.workout_effort_score` | Latest related effort rating, with associated workout statistics as a fallback, in Apple's effort-score units on iOS 18+. |
| `metadata.estimated_workout_effort_score` | Latest available estimated effort rating, with associated workout statistics as a fallback, in Apple's effort-score units on iOS 18+. |

All metadata values remain **strings**, including numeric summaries. Missing values are omitted rather than filled with zero. Raw source metadata is retained alongside these summaries. The current export schema remains version 2, and the backend continues accepting legacy version 1 payloads; no backend migration is required.

Earlier app builds copied active calories into `total_energy_kcal`. Newly read workouts correct that meaning; already queued payloads retain their saved contents. Consumers should use `active_energy_kcal` for active calories and treat an absent total as unknown.

Selecting Workouts also requests read access to the supporting heart-rate, energy, distance, and effort types. Existing users can request these permissions again from Settings → Apple Health Access. Denying optional effort access does not prevent workout export. Other read errors keep the operation retryable.

Summaries are snapshots taken during incremental workout reads, recent rereads, and backfill. The daily reread revisits today and the previous three local calendar days. Later edits to older workout metrics or effort relationships require manually backfilling the affected dates. Raw heart-rate samples remain a separate selected metric; the workout metadata contains summaries.

The statistics and effort reads use Apple's [workout statistics API](https://developer.apple.com/documentation/healthkit/hkworkout/statistics(for:)) and [related effort predicate](https://developer.apple.com/documentation/healthkit/hkquery/predicateforworkouteffortsamplesrelated(workout:activity:)).

## Local Persistence

The app uses SQLite for settings, selected data types, sync frequency, HealthKit anchors, queued upload batches, sync logs, and the stable local device ID. Auth tokens are stored only in Keychain.

Successful batches are marked uploaded and pruned after 7 days. Failed network/server uploads remain queued and are retried by the next manual, foreground, HealthKit observer, or scheduled background sync.

## Open And Build

1. Open `HealthSync.xcodeproj` in Xcode 16 or newer.
2. Select the `HealthSync` target.
3. Set your development team for signing.
4. Confirm HealthKit Background Delivery and Background Modes (Background fetch) are enabled.
5. Build for an iOS 17+ simulator or device.

CLI build:

```bash
xcodebuild build -project HealthSync.xcodeproj -scheme HealthSync -destination 'generic/platform=iOS Simulator' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO
```

## Run Tests

Build tests without launching a simulator:

```bash
xcodebuild build-for-testing -project HealthSync.xcodeproj -scheme HealthSync -destination 'generic/platform=iOS Simulator' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO
```

Run the full XCTest suite with an available simulator:

```bash
xcodebuild test -project HealthSync.xcodeproj -scheme HealthSync -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO
```

`PopulatedWorkoutExportTests` supplies in-memory elliptical and rowing fixtures with heart rate, active/basal energy, distance, METs, and both effort scores. It checks native HealthKit unit conversion, activity mapping, latest related effort selection, SQLite queue persistence after reopening, and the final HTTP request JSON. These fixtures run on simulator or device without saving workouts to HealthKit or sending the synthetic request. Run just these cases by adding `-only-testing:HealthSyncTests/PopulatedWorkoutExportTests` to an XCTest command. They validate the export pipeline when statistics are provided; actual source-app recording and HealthKit statistic population remain device acceptance checks.

An opt-in integration test also compares the latest 20 readable workouts on a connected iPhone with their HealthKit statistics and verifies JSON export. First grant HealthSync read access on the phone, then run this with its device ID and your signing team:

```bash
TEST_RUNNER_HEALTHSYNC_DEVICE_VALIDATION=1 xcodebuild test \
  -project HealthSync.xcodeproj -scheme HealthSync -configuration Release \
  -destination 'id=YOUR_IPHONE_UDID' \
  -derivedDataPath /tmp/HealthSyncDeviceTests \
  -resultBundlePath /tmp/HealthSyncDeviceTests.xcresult \
  -only-testing:HealthSyncTests/PhysicalWorkoutValidationTests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  CODE_SIGN_STYLE=Automatic ENABLE_TESTABILITY=YES
```

The test uses existing read permissions and records activity types and field-availability counts in an XCTest attachment and `Library/Application Support/HealthSync/WorkoutValidation.json` inside the app container. Normal app-launch behavior, including configured sync, still applies. The test skips on simulators, without the opt-in variable, or when no workouts are readable. Its coverage depends on the workouts and associated statistics available on that phone; absent fields do not establish that another source's populated fields work on-device.

## Persistent Backend

For real persistent storage, use the backend in `backend/`. It stores uploaded HealthSync data in Postgres and exposes fetch endpoints for metrics, workouts, and sync batches.

Fastest local setup:

```bash
cp .env.example .env
python3 -m backend.scripts.generate_token
```

In `.env`, replace only these local Docker values: `POSTGRES_PASSWORD`, `API_TOKEN`, and `TOKEN_HASH_SECRET`. Paste the generated token as `API_TOKEN`, run the generator again, paste the second token as `TOKEN_HASH_SECRET`, then run:

```bash
docker compose up --build
```

Use `http://127.0.0.1:8080` from the simulator. For a real iPhone, use a private HTTPS endpoint reachable from the phone, or use your Mac's LAN address for same-Wi-Fi testing.

For hosted HealthSync on Supabase Postgres, deploy the FastAPI backend with `DATABASE_URL`, `API_TOKEN`, `TOKEN_HASH_SECRET`, `HOSTED_PUBLIC_BASE_URL`, and `HOSTED_PROVISIONING_ENABLED=true`. The backend provisions HealthSync workspaces and returns an app ingest token plus a private read-only agent endpoint/token. The app's hosted setup flow uses the hosted backend URL and ingest token; AI agents should receive only the agent endpoint and agent token, never Supabase credentials.

For Supabase, Neon, or another managed Postgres database without hosted provisioning, set `DATABASE_URL`, `API_TOKEN`, and `TOKEN_HASH_SECRET`, run `alembic upgrade head`, and deploy `uvicorn backend.main:app`. See `backend/README.md` for the full setup, hosted provisioning, and fetch API examples.

## Backend Stub

The `backend_stub/` service is still available as a local-only request-shape stub. It does not persist data.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend_stub/requirements.txt
uvicorn backend_stub.main:app --host 0.0.0.0 --port 8080
```

For a real iPhone on the same Wi-Fi as this Mac, use the Mac's LAN address instead, for example:

```text
http://192.168.1.24:8080
```

iOS may ask for Local Network access the first time the app connects to a LAN backend. Allow it for local testing.

## App Setup

1. Launch the app.
2. Tap **Continue**. HealthSync creates a private hosted workspace, then asks you to review its read permissions.
3. Tap **Sync last 24 hours** or open **Backfill date range**.
4. Optional: open **Settings** to switch to your own backend, choose data types, or change sync frequency.

## Background Limitations

HealthSync combines three best-effort wake-up paths:

- `HKObserverQuery` background delivery when Apple Health saves or deletes selected samples.
- `BGAppRefreshTask` requests for the chosen hourly or daily cadence, including while the app is suspended or terminated by the system.
- An in-process timer plus a catch-up sync when the app is open or becomes active.

New installs default to hourly best-effort. Choosing Manual only cancels scheduled refreshes and HealthKit background delivery. Each background execution schedules its successor, retries every queued batch, and advances HealthKit anchors only after additions and deletions are durably written to SQLite.

iOS decides when background work runs and does not guarantee an exact hourly/daily time, especially while the phone is locked, in Low Power Mode, recently rebooted, force-quit by the user, or when the system suppresses background work. HealthKit background delivery must be verified on a physical iPhone because the Simulator does not support background server queries.

Manual sync and backfill are the reliable paths.

## Deployment Notes

- Test HealthKit permissions on a real iPhone. Simulators are useful for UI and unit tests but do not represent real Apple Health data availability.
- Use HTTPS for production backends.
- The backend should dedupe by `device_id`, `export_id`, and record IDs.
- The app never prints auth tokens or raw health payloads to console logs.

## TestFlight Access Web App

The `web/` directory contains a small Next.js app where testers can request HealthSync TestFlight access.

```bash
cd web
npm install
npm run dev
```

Local requests are appended to `web/data/testflight-requests.jsonl`, which is ignored by git. Set `TESTFLIGHT_REQUEST_WEBHOOK_URL` to forward validated requests to a production workflow.

Production deployments should use durable storage. The Vercel deployment stores requests in private Vercel Blob records when Blob env vars are configured, and exposes a bearer-token-protected admin export at `/api/access-requests`. See `web/README.md` for Vercel setup, health checks, and export commands.

## License

Copyright 2026 megabyte0x.

HealthSync is licensed under the Apache License, Version 2.0 (`Apache-2.0`). See [LICENSE](LICENSE) for the full terms.
