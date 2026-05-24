# HealthKit Sync App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI iOS 17 app that reads selected Apple Health data with explicit HealthKit permission and syncs queued JSON batches to a private REST backend.

**Architecture:** The app has a small SwiftUI shell backed by `AppState`, a HealthKit service that fetches DTOs, a normalizer that produces the backend payload schema, a SQLite local store for settings/anchors/batches/logs, a Keychain token store, and an async `URLSession` API client. Sync is retry-safe because payload batches are persisted before upload and marked uploaded only after accepted responses.

**Tech Stack:** Swift 5, SwiftUI, HealthKit, Security/Keychain, SQLite3, XCTest, FastAPI backend stub.

---

### Task 1: Project Scaffold And Red Tests

**Files:**
- Create: `HealthSync.xcodeproj/project.pbxproj`
- Create: `HealthSync/HealthSyncApp.swift`
- Create: `HealthSync/AppState.swift`
- Create: `HealthSync/Info.plist`
- Create: `HealthSync/HealthSync.entitlements`
- Create: `Tests/HealthSyncTests/HealthNormalizerTests.swift`
- Create: `Tests/HealthSyncTests/APIClientTests.swift`
- Create: `Tests/HealthSyncTests/SyncEngineTests.swift`

- [ ] Create the Xcode project, app shell, entitlements, and failing XCTest coverage for stable IDs, unit conversion, payload encoding, retry classification, queue retention, and token redaction.
- [ ] Run: `xcodebuild test -project HealthSync.xcodeproj -scheme HealthSync -destination 'platform=iOS Simulator,name=iPhone 16'`
- [ ] Expected: tests fail because core production types do not exist yet.

### Task 2: Codable Models And Normalizer

**Files:**
- Create: `HealthSync/Models/HealthMetric.swift`
- Create: `HealthSync/Models/HealthWorkout.swift`
- Create: `HealthSync/Models/SyncBatch.swift`
- Create: `HealthSync/Models/SyncLog.swift`
- Create: `HealthSync/Services/HealthNormalizer.swift`

- [ ] Implement HealthKit-independent DTOs, payload models, deterministic IDs, unit conversion, workout activity mapping, and JSON encoding helpers.
- [ ] Run the normalizer tests and confirm they pass.

### Task 3: API Client And Sync Engine

**Files:**
- Create: `HealthSync/Services/APIClient.swift`
- Create: `HealthSync/Services/KeychainStore.swift`
- Create: `HealthSync/Services/SyncEngine.swift`

- [ ] Implement URL validation, headers, timeout, retry classification, exponential backoff, token-safe errors, and persisted queue upload behavior.
- [ ] Run API and sync engine tests and confirm they pass.

### Task 4: Local Persistence And HealthKit

**Files:**
- Create: `HealthSync/AppSettings.swift`
- Create: `HealthSync/Services/LocalStore.swift`
- Create: `HealthSync/Services/HealthKitTypeRegistry.swift`
- Create: `HealthSync/Services/HealthKitManager.swift`

- [ ] Implement SQLite settings, selected data types, frequency, anchors, queued batches, logs, stable device ID, and pruning.
- [ ] Implement read-only HealthKit permission request, `HKSampleQuery`, `HKAnchoredObjectQuery`, observer registration, and anchor serialization.

### Task 5: SwiftUI Screens

**Files:**
- Create: `HealthSync/Views/OnboardingView.swift`
- Create: `HealthSync/Views/DashboardView.swift`
- Create: `HealthSync/Views/SettingsView.swift`
- Create: `HealthSync/Views/BackfillView.swift`
- Create: `HealthSync/Views/SyncLogView.swift`
- Modify: `HealthSync/AppState.swift`
- Modify: `HealthSync/HealthSyncApp.swift`

- [ ] Implement onboarding, settings, dashboard, sync log, manual sync, test connection, and backfill flows.
- [ ] Confirm no UI path prints auth tokens or raw health payloads.

### Task 6: Backend Stub And Documentation

**Files:**
- Create: `backend_stub/main.py`
- Create: `backend_stub/requirements.txt`
- Create: `backend_stub/README.md`
- Create: `README.md`

- [ ] Add FastAPI local stub that validates the Authorization header and prints summary counts only.
- [ ] Document setup, HealthKit capability, permissions, tests, backend stub, deployment, privacy, and iOS background limitations.

### Task 7: Final Verification

**Files:**
- All files above.

- [ ] Run unit tests with `xcodebuild test`.
- [ ] Run a simulator build with `xcodebuild build`.
- [ ] Run backend stub syntax/import check where possible.
- [ ] Re-read `GOAL.md` acceptance criteria and report build/test status, changed files, implemented HealthKit permissions, known limitations, and real-device next steps.
