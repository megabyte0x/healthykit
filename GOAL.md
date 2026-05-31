Build a native iOS Apple HealthKit sync app.

Goal:
Create a small, reliable iOS app that reads my Apple Health data on-device via HealthKit, gets my explicit permission, and syncs selected metrics/workouts to my private REST backend as JSON. There is no iCloud/server-side Apple Health API, so all reads must happen on iPhone through HealthKit.

Hard requirements:

- Native iOS app only: Swift + SwiftUI + HealthKit.
- Minimum iOS target: iOS 17 unless existing project requires otherwise.
- No React Native, Flutter, Expo, or third-party health SDKs.
- Privacy-first: no analytics, no third-party telemetry, no external SDKs.
- Health data must never be sent anywhere except the configured backend URL.
- Backend URL and auth token must be user-configurable in-app.
- Store auth token securely in Keychain, not UserDefaults.
- Sync must be idempotent and retry-safe.
- App must support manual sync and incremental background-ish sync.
- Include a clear README with setup, permissions, testing, and deployment steps.

Backend endpoint contract:
The app should POST JSON to:

POST {configured_backend_url}/api/apple-health/sync

Headers:
Authorization: Bearer {token_from_keychain}
Content-Type: application/json
X-Device-Id: {stable_local_device_id}
X-App-Version: {app_version}

Payload shape:
{
"device_id": "uuid-string",
"export_id": "uuid-string",
"generated_at": "ISO-8601",
"timezone": "Asia/Kolkata",
"source": "ios-healthkit",
"schema_version": 1,
"date_range": {
"start": "ISO-8601",
"end": "ISO-8601"
},
"metrics": [
{
"id": "stable-id",
"type": "step_count|heart_rate|resting_heart_rate|hrv_sdnn|active_energy|basal_energy|body_mass|body_fat_percentage|dietary_energy|dietary_protein|dietary_carbs|dietary_fat|water|sleep_analysis",
"value": 123.45,
"unit": "count|count/min|ms|kcal|kg|percent|g|mL|seconds",
"start_at": "ISO-8601",
"end_at": "ISO-8601",
"source_name": "Apple Watch|iPhone|app name",
"source_bundle_id": "bundle-id-if-available",
"metadata": {}
}
],
"workouts": [
{
"id": "stable-id",
"activity_type": "running|walking|cycling|traditionalStrengthTraining|functionalStrengthTraining|other",
"start_at": "ISO-8601",
"end_at": "ISO-8601",
"duration_seconds": 3600,
"total_energy_kcal": 300.0,
"active_energy_kcal": 250.0,
"distance_meters": 5000.0,
"source_name": "Apple Watch",
"source_bundle_id": "bundle-id-if-available",
"metadata": {}
}
]
}

Assume backend responses:

- 200/201/202 = accepted
- 401/403 = auth error, show user
- 429/5xx/network failure = retry later
- Response body may be:
  {
  "ok": true,
  "received": 123,
  "duplicates": 3
  }

Core app screens:

1. Onboarding screen
   - Explain what data is read.
   - Button: “Connect Apple Health”
   - Request HealthKit read permissions.

2. Settings screen
   - Backend URL input.
   - Auth token input stored in Keychain.
   - Data type toggles:
     - Steps
     - Heart rate
     - Resting heart rate
     - HRV
     - Active energy
     - Basal energy
     - Weight/body mass
     - Body fat percentage
     - Sleep
     - Workouts
     - Dietary energy/macros/water if available
   - Sync frequency preference:
     - Manual only
     - Hourly best-effort
     - Daily best-effort
   - Button: “Test connection”
   - Button: “Sync last 24 hours”
   - Button: “Backfill date range”

3. Dashboard screen
   - HealthKit permission status
   - Last successful sync time
   - Last attempted sync time
   - Pending upload count
   - Last error, if any
   - Manual sync button
   - Recent sync log list, concise only

HealthKit implementation:

- Create a HealthKitManager.
- Check HKHealthStore.isHealthDataAvailable().
- Request read permissions for:
  - HKQuantityTypeIdentifier.stepCount
  - HKQuantityTypeIdentifier.heartRate
  - HKQuantityTypeIdentifier.restingHeartRate
  - HKQuantityTypeIdentifier.heartRateVariabilitySDNN
  - HKQuantityTypeIdentifier.activeEnergyBurned
- HKQuantityTypeIdentifier.basalEnergyBurned
  - HKQuantityTypeIdentifier.bodyMass
  - HKQuantityTypeIdentifier.bodyFatPercentage
  - HKQuantityTypeIdentifier.dietaryEnergyConsumed
  - HKQuantityTypeIdentifier.dietaryProtein
  - HKQuantityTypeIdentifier.dietaryCarbohydrates
  - HKQuantityTypeIdentifier.dietaryFatTotal
  - HKQuantityTypeIdentifier.dietaryWater
  - HKCategoryTypeIdentifier.sleepAnalysis
  - HKObjectType.workoutType()
- Do not request write permissions unless absolutely needed. Default: read-only.
- Use HKSampleQuery for backfill/manual date ranges.
- Use HKAnchoredObjectQuery for incremental sync.
- Persist anchors locally so future syncs only fetch new samples.
- Use HKObserverQuery / enableBackgroundDelivery where possible, but document iOS limitations clearly.
- Do not pretend background sync is guaranteed. It is best-effort only.

Local persistence:

- Use SwiftData or SQLite. Pick the simplest reliable option for iOS 17.
- Persist:
  - backend_url
  - selected data types
  - sync frequency
  - last anchors per HealthKit type
  - pending upload batches
  - sync logs
  - stable local device_id
- Auth token must be in Keychain only.
- Upload batches should survive app restarts.
- Failed network uploads should remain queued.
- Successful uploads should be marked uploaded and pruned after 7 days.

Idempotency:

- Every metric/workout must have a stable deterministic id.
- Prefer HealthKit sample UUID where available.
- ID format:
  healthkit:{sample_uuid}
- For aggregate/derived records, use:
  aggregate:{type}:{start_at}:{end_at}:{source}
- Every export batch gets export_id UUID.
- Backend should be able to dedupe, but app should also avoid resending uploaded batches.

Sync behavior:

- Manual sync:
  - User picks default last 24h or custom date range.
  - Fetch enabled HealthKit types.
  - Normalize to payload schema.
  - Store batch locally.
  - Upload immediately.
  - Show success/error.

- Incremental sync:
  - For each enabled type, use saved anchor.
  - Fetch changed samples.
  - Normalize.
  - Queue batch.
  - Upload.
  - Save new anchor only after data is safely queued.
  - If upload fails, keep queued batch.

- Backfill:
  - User selects start/end dates.
  - Fetch in chunks by day or week to avoid memory blowups.
  - Queue/upload chunked batches.
  - Show progress.

Networking:

- Create APIClient using URLSession async/await.
- Validate backend URL.
- Add timeout.
- Add retry with exponential backoff for transient failures.
- Do not log auth token.
- Do not print raw health payloads in logs.
- Errors should be user-readable:
  - missing backend URL
  - missing token
  - HealthKit permission denied
  - network unavailable
  - server rejected auth
  - server error

Security/privacy:

- Keychain wrapper for token.
- No analytics.
- No crash reporting SDK.
- No third-party logging.
- README must explicitly say health data stays on-device until user configures backend sync.
- Add Info.plist strings:
  - NSHealthShareUsageDescription: “This app reads selected Apple Health data to sync it to your private health dashboard.”
  - NSHealthUpdateUsageDescription only if write permissions are added; otherwise omit.
- Add HealthKit capability/entitlement.

Project structure:
If no existing Xcode project exists, create:

HealthSync/
HealthSyncApp.swift
AppState.swift
Models/
HealthMetric.swift
HealthWorkout.swift
SyncBatch.swift
SyncLog.swift
AppSettings.swift
Services/
HealthKitManager.swift
HealthKitTypeRegistry.swift
HealthNormalizer.swift
SyncEngine.swift
APIClient.swift
KeychainStore.swift
LocalStore.swift
Views/
OnboardingView.swift
DashboardView.swift
SettingsView.swift
BackfillView.swift
SyncLogView.swift
Tests/
HealthNormalizerTests.swift
APIClientTests.swift
SyncEngineTests.swift
README.md

Implementation details:

- Use async/await.
- Keep code simple and readable.
- Use dependency injection enough to test normalizer/API/sync logic.

- HealthNormalizer must convert HealthKit samples into the payload schema.
- Include unit tests for:
  - stable ID generation
  - unit conversions
  - payload encoding
  - retry classification
  - queue behavior on failed upload
  - token never appears in logs/errors
- If HealthKit types are hard to instantiate in unit tests, test normalization with lightweight internal DTOs.

Units:

- Steps: count
- Heart rate/resting HR: count/min
- HRV SDNN: ms
- Energy: kcal
- Body mass: kg
- Body fat: percent
- Dietary macros: g
- Water: mL
- Sleep: seconds or categorical records with metadata containing sleep stage
- Workout duration: seconds
- Workout distance: meters

Apple limitations to document:

- HealthKit data is local to the device.
- There is no normal server-side Apple Health REST API.
- User must grant permissions on iPhone.
- Background sync is best-effort and may not run while phone is locked, in Low Power Mode, or when iOS suppresses background tasks.
- Manual sync/backfill is the reliable path.

Acceptance criteria:

- App builds in Xcode.
- First launch shows onboarding.
- User can grant HealthKit permissions.
- User can configure backend URL and token.
- Token is stored in Keychain.
- User can run “Test connection”.
- User can manually sync last 24h.
- User can backfill a custom date range.
- Failed uploads are queued and retried.
- Successful sync updates last success timestamp.
- README includes exact setup instructions.
- No third-party telemetry exists.
- No health payloads or auth tokens are printed to console.

Backend stub:
Also include a tiny optional local backend stub for testing if this repo does not already have one:
backend_stub/
main.py
requirements.txt
README.md

Use FastAPI:

- POST /api/apple-health/sync
- Validate Authorization header exists.
- Print only summary counts, not raw data.
- Return {"ok": true, "received": count, "duplicates": 0}
- This is only for local testing, not production.

Commands to include in README:

- How to open/build the Xcode project.
- How to enable HealthKit capability.
- How to run tests.
- How to run backend stub:
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r backend_stub/requirements.txt
  uvicorn backend_stub.main:app --host 0.0.0.0 --port 8080

Development process:

1. Inspect repository first.
2. If an iOS project exists, integrate cleanly.
3. If no iOS project exists, create one.
4. Implement in small commits.
5. Run tests.
6. Provide final summary:
   - changed files
   - build/test status
   - HealthKit permissions implemented
   - known limitations
   - next steps for real device testing

Do not ask questions unless blocked by missing Xcode/project constraints. Make reasonable defaults and build the thing.
