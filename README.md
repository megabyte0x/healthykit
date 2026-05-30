# HealthSync

HealthSync is a native SwiftUI iOS app that reads selected Apple Health data on-device through HealthKit and syncs queued JSON batches to a private REST backend.

There is no iCloud or server-side Apple Health REST API. Apple Health reads happen only on the iPhone after the user grants HealthKit read permissions. Health data stays on-device until the user configures a backend URL and auth token.

## What It Syncs

- Steps, heart rate, resting heart rate, HRV SDNN
- Active energy, basal energy
- Body mass, body fat percentage
- Sleep analysis
- Workouts
- Optional dietary energy, macros, and water when available

The app requests read-only HealthKit permissions. It does not request write permissions, does not include analytics, and does not use third-party telemetry or health SDKs.

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

Every metric and workout uses a deterministic ID of `healthkit:{sample_uuid}`. Every upload batch has its own `export_id`, and failed batches remain queued locally for retry.

## Local Persistence

The app uses SQLite for settings, selected data types, sync frequency, HealthKit anchors, queued upload batches, sync logs, and the stable local device ID. Auth tokens are stored only in Keychain.

Successful batches are marked uploaded and pruned after 7 days. Failed network/server uploads remain queued.

## Open And Build

1. Open `HealthSync.xcodeproj` in Xcode 16 or newer.
2. Select the `HealthSync` target.
3. Set your development team for signing.
4. Confirm the HealthKit capability is enabled.
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
2. Tap **Connect Apple Health** and grant read permissions.
3. Open **Settings**.
4. Enter the backend URL.
5. Enter the auth token. It is saved in Keychain.
6. Choose data type toggles and sync frequency.
7. Tap **Test connection**.
8. Tap **Sync last 24 hours** or open **Backfill date range**.

## Background Limitations

HealthSync uses `HKObserverQuery` and HealthKit background delivery where iOS permits it. It also supports hourly/daily best-effort sync while the app is alive. iOS does not guarantee background sync timing, especially while the phone is locked, in Low Power Mode, recently rebooted, or when the system suppresses background work.

Manual sync and backfill are the reliable paths.

## Deployment Notes

- Test HealthKit permissions on a real iPhone. Simulators are useful for UI and unit tests but do not represent real Apple Health data availability.
- Use HTTPS for production backends.
- The backend should dedupe by `device_id`, `export_id`, and record IDs.
- The app never prints auth tokens or raw health payloads to console logs.
