import XCTest
import SQLite3
@testable import HealthSync

final class LocalStoreTests: XCTestCase {
    func testLegacyHostedSettingsMoveToCloudflareAndPersistWithoutResettingLocalState() async throws {
        let url = temporaryDatabaseURL()
        let store = try SQLiteLocalStore(url: url)
        var original = AppSettings.default
        original.backendURL = "https://dtzydnjnqkruxaacgkio.supabase.co/functions/v1/healthsync"
        original.hostedAgentEndpoint = original.backendURL + "/api/agent/health-data?limit=50&tag=a%2Fb"
        original.hostedWorkspaceID = "wk_existing_migration_fixture"
        original.selectedTypes = [.stepCount, .heartRate]
        original.syncFrequency = .manualOnly
        original.hasRequestedHealthPermissions = true
        try await store.saveSettings(original)
        let deviceID = try await store.deviceID()
        try await store.saveAnchor("existing-anchor", for: .stepCount)
        let queued = legacyBatch()
        try await store.enqueueBatch(queued)

        var expected = original
        expected.backendURL = "https://api.healthysync.app"
        expected.hostedAgentEndpoint = "https://api.healthysync.app/api/agent/health-data?limit=50&tag=a%2Fb"
        let migrated = try await store.loadSettings()
        XCTAssertEqual(migrated, expected)
        XCTAssertEqual(try persistedSettings(at: url), expected)

        let reopened = try SQLiteLocalStore(url: url)
        let afterRestart = try await reopened.loadSettings()
        let restoredDeviceID = try await reopened.deviceID()
        let restoredAnchor = try await reopened.loadAnchor(for: .stepCount)
        let restoredQueue = try await reopened.pendingBatches()
        XCTAssertEqual(afterRestart, expected)
        XCTAssertEqual(restoredDeviceID, deviceID)
        XCTAssertEqual(restoredAnchor, "existing-anchor")
        XCTAssertEqual(restoredQueue, [queued])
    }

    func testLegacyAgentPathsAndEncodedFiltersMigrateButUnrelatedEndpointsDoNot() async throws {
        let store = try SQLiteLocalStore(url: temporaryDatabaseURL())
        let old = "https://dtzydnjnqkruxaacgkio.supabase.co/functions/v1/healthsync"
        for path in ["health-data", "metrics", "workouts", "syncs"] {
            var settings = AppSettings.default
            settings.hostedAgentEndpoint = old + "/api/agent/\(path)?from=2026-10-01&tag=a%2Fb#details"
            try await store.saveSettings(settings)
            let migrated = try await store.loadSettings()
            XCTAssertEqual(migrated.hostedAgentEndpoint, "https://api.healthysync.app/api/agent/\(path)?from=2026-10-01&tag=a%2Fb#details")
        }
        for endpoint in [
            "https://my-server.example/api/agent/health-data",
            "https://another-project.supabase.co/functions/v1/healthsync/api/agent/health-data",
            old + "/api/agent/health-data-other",
            old + "/api/hosted/agent-token",
            "https://user:password@dtzydnjnqkruxaacgkio.supabase.co/functions/v1/healthsync/api/agent/health-data",
            "https://api.healthysync.app/api/agent/health-data"
        ] {
            var settings = AppSettings.default
            settings.hostedAgentEndpoint = endpoint
            try await store.saveSettings(settings)
            let unchanged = try await store.loadSettings()
            XCTAssertEqual(unchanged, settings)
        }
    }

    func testSettingsMigrationKeepsCredentialsUsableWhenPersistenceFailsAndRetriesOnReload() async throws {
        let url = temporaryDatabaseURL()
        let store = try SQLiteLocalStore(url: url)
        var original = AppSettings.default
        original.backendURL = "https://dtzydnjnqkruxaacgkio.supabase.co/functions/v1/healthsync"
        original.hostedAgentEndpoint = original.backendURL + "/api/agent/health-data"
        original.hostedWorkspaceID = "wk_existing_migration_fixture"
        try await store.saveSettings(original)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TRIGGER reject_migration BEFORE UPDATE ON settings WHEN NEW.key='app_settings' BEGIN SELECT RAISE(ABORT, 'disk write failed'); END", nil, nil, nil), SQLITE_OK)

        let usable = try await store.loadSettings()
        XCTAssertEqual(usable.backendURL, "https://api.healthysync.app")
        XCTAssertEqual(usable.hostedAgentEndpoint, "https://api.healthysync.app/api/agent/health-data")
        XCTAssertEqual(usable.hostedWorkspaceID, original.hostedWorkspaceID)
        XCTAssertEqual(try persistedSettings(at: url), original)
        XCTAssertEqual(sqlite3_exec(db, "DROP TRIGGER reject_migration", nil, nil, nil), SQLITE_OK)
        let retried = try await store.loadSettings()
        XCTAssertEqual(retried, usable)
        XCTAssertEqual(try persistedSettings(at: url), usable)
    }

    private func persistedSettings(at url: URL) throws -> AppSettings {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw SQLiteStoreError.encodingFailed }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM settings WHERE key='app_settings'", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.encodingFailed
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else {
            throw SQLiteStoreError.encodingFailed
        }
        return try JSONDecoder().decode(AppSettings.self, from: Data(String(cString: text).utf8))
    }

    func testOversizedLegacyQueueIsReplacedAtomicallyAndChunksRemainStableAfterRestart() async throws {
        let url = temporaryDatabaseURL()
        let store = try SQLiteLocalStore(url: url)
        let original = legacyBatch()
        try await store.enqueueBatch(original)
        try await store.splitOversizedPendingBatches(maxRecords: 100)
        let chunks = try await store.pendingBatches()
        let reopened = try SQLiteLocalStore(url: url)
        try await reopened.splitOversizedPendingBatches(maxRecords: 100)
        let afterRestart = try await reopened.pendingBatches()

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(afterRestart, chunks)
        XCTAssertFalse(chunks.contains { $0.id == original.id })
        XCTAssertEqual(Set(chunks.flatMap { $0.payload.metrics.map(\.id) }), Set(original.payload.metrics.map(\.id)))
        XCTAssertTrue(chunks.allSatisfy { $0.payload.metrics.count <= 100 && $0.attemptCount == 0 })
        XCTAssertTrue(chunks.allSatisfy { $0.payload.deviceID == original.payload.deviceID && $0.payload.schemaVersion == 1 })
        XCTAssertTrue(chunks.flatMap { $0.payload.metrics }.allSatisfy { $0.sourceBundleID == "com.example.fitness" })
    }

    func testFailedLegacyQueueReplacementRollsBackEveryPartialChunk() async throws {
        let url = temporaryDatabaseURL()
        let store = try SQLiteLocalStore(url: url)
        let original = legacyBatch()
        try await store.enqueueBatch(original)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TRIGGER fail_chunk BEFORE INSERT ON batches WHEN (SELECT count(*) FROM batches) >= 2 BEGIN SELECT RAISE(ABORT, 'disk write failed'); END", nil, nil, nil), SQLITE_OK)

        do {
            try await store.splitOversizedPendingBatches(maxRecords: 100)
            XCTFail("A failed chunk write must abort the replacement")
        } catch {}
        let reopened = try SQLiteLocalStore(url: url)
        let pending = try await reopened.pendingBatches()
        XCTAssertEqual(pending, [original])
    }

    func testExistingLegacyDeletionWinsBeforeAttemptCountReordering() async throws {
        let url = temporaryDatabaseURL()
        let store = try SQLiteLocalStore(url: url)
        let original = legacyBatch()
        try await store.enqueueBatch(original)
        let deletion = SyncPayload(deviceID: original.payload.deviceID, exportID: UUID(), generatedAt: original.createdAt,
            timezone: "UTC", source: "ios-healthkit", schemaVersion: 2, dateRange: original.payload.dateRange,
            metrics: [], workouts: [], deletions: [HealthRecordDeletion(id: original.payload.metrics[0].id, kind: .metric)])
        let json = String(data: try PayloadJSON.encoder.encode(deletion), encoding: .utf8)!
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "INSERT INTO batches VALUES (?, ?, ?, NULL, 1, 'Timed out')", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, UUID().uuidString, -1, transient)
        sqlite3_bind_text(statement, 2, json, -1, transient)
        sqlite3_bind_double(statement, 3, original.createdAt.timeIntervalSince1970)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)

        try await store.splitOversizedPendingBatches(maxRecords: 100)
        let pending = try await store.pendingBatches()
        XCTAssertFalse(pending.flatMap { $0.payload.metrics }.contains { $0.id == original.payload.metrics[0].id })
        XCTAssertEqual(pending.flatMap { $0.payload.metrics }.count, 204)
        XCTAssertEqual(pending.flatMap { $0.payload.deletions }, deletion.deletions)
    }

    func testFailedSupersedingWriteRetainsOriginalPendingBatch() async throws {
        let url = temporaryDatabaseURL()
        let store = try SQLiteLocalStore(url: url)
        let original = legacyBatch()
        try await store.enqueueBatch(original)
        let metric = original.payload.metrics[0]
        let replacement = HealthMetric(id: metric.id, type: metric.type, value: 999, unit: metric.unit,
            startAt: metric.startAt, endAt: metric.endAt, sourceName: metric.sourceName,
            sourceBundleID: metric.sourceBundleID, metadata: ["test": "reject-new"])
        let newPayload = SyncPayload(deviceID: original.payload.deviceID, exportID: UUID(), generatedAt: metric.endAt,
            timezone: "UTC", source: "ios-healthkit", schemaVersion: 1, dateRange: original.payload.dateRange,
            metrics: [replacement], workouts: [])
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TRIGGER reject_new BEFORE INSERT ON batches WHEN NEW.payload_json LIKE '%reject-new%' BEGIN SELECT RAISE(ABORT, 'disk write failed'); END", nil, nil, nil), SQLITE_OK)
        do {
            try await store.enqueueBatch(SyncBatch(payload: newPayload))
            XCTFail("A failed replacement must leave the older data durable")
        } catch {}
        let reopened = try SQLiteLocalStore(url: url)
        let pending = try await reopened.pendingBatches()
        XCTAssertEqual(pending, [original])
    }

    func testDailyMaintenanceUsesCalendarDaysAcrossDaylightSavingTime() async throws {
        let store = try SQLiteLocalStore(url: temporaryDatabaseURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let first = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0, minute: 30))!
        let later = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23))!
        let nextDay = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 30))!
        let firstClaim = try await store.claimDailyMaintenance("test", now: first, calendar: calendar)
        let sameDayClaim = try await store.claimDailyMaintenance("test", now: later, calendar: calendar)
        let nextDayClaim = try await store.claimDailyMaintenance("test", now: nextDay, calendar: calendar)
        XCTAssertTrue(firstClaim)
        XCTAssertFalse(sameDayClaim)
        XCTAssertTrue(nextDayClaim)
        XCTAssertEqual(nextDay.timeIntervalSince(first), 23 * 3600)
    }

    private func legacyBatch() -> SyncBatch {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let metrics = (0..<205).map { index in
            HealthMetric(id: "healthkit:\(index)", type: "step_count", value: Double(index), unit: "count",
                startAt: start, endAt: start, sourceName: "Mi Fitness", sourceBundleID: "com.example.fitness", metadata: [:])
        }
        return SyncBatch(payload: SyncPayload(deviceID: "existing-device", exportID: UUID(), generatedAt: start,
            timezone: "UTC", source: "ios-healthkit", schemaVersion: 1, dateRange: SyncDateRange(start: start, end: start),
            metrics: metrics, workouts: []), createdAt: start, attemptCount: 8, lastError: "Timed out")
    }

    func testFreshBatchesPrecedeFailedBatchesAndSurviveReopening() async throws {
        let url = temporaryDatabaseURL()
        let store = try SQLiteLocalStore(url: url)
        let payload = SyncPayload.empty(deviceID: "existing-device", dateRange: SyncDateRange(start: .distantPast, end: .distantPast), timezone: "UTC")
        let stale = SyncBatch(payload: payload, createdAt: Date(timeIntervalSince1970: 1), attemptCount: 2)
        let fresh = SyncBatch(payload: payload, createdAt: Date(timeIntervalSince1970: 2))
        try await store.enqueueBatch(stale)
        try await store.enqueueBatch(fresh)
        try await store.saveAnchor("existing-anchor", for: .workouts)
        let deviceID = try await store.deviceID()

        let reopened = try SQLiteLocalStore(url: url)
        let pending = try await reopened.pendingBatches()
        let anchor = try await reopened.loadAnchor(for: .workouts)
        let reopenedDeviceID = try await reopened.deviceID()

        XCTAssertEqual(pending.map(\.id), [fresh.id, stale.id])
        XCTAssertEqual(pending.last?.attemptCount, 2)
        XCTAssertEqual(pending.last?.payload.exportID, stale.payload.exportID)
        XCTAssertEqual(anchor, "existing-anchor")
        XCTAssertEqual(reopenedDeviceID, deviceID)
    }

    func testSyncStatusDoesNotShowStaleErrorAfterLaterSuccess() async throws {
        let store = try SQLiteLocalStore(url: temporaryDatabaseURL())
        try await store.appendLog(
            SyncLogEntry(
                level: .error,
                message: "Network unavailable"
            )
        )
        try await store.appendLog(
            SyncLogEntry(
                level: .success,
                message: "Uploaded batch"
            )
        )

        let status = try await store.syncStatus()

        XCTAssertNil(status.lastError)
    }

    func testSettingsPersistHostedStorageMode() async throws {
        let store = try SQLiteLocalStore(url: temporaryDatabaseURL())
        var settings = AppSettings.default
        settings.storageMode = .hostedHealthSync
        settings.hostedWorkspaceID = "wk_test"
        settings.hostedAgentEndpoint = "https://api.example.com/api/agent/health-data"

        try await store.saveSettings(settings)
        let loaded = try await store.loadSettings()

        XCTAssertEqual(loaded.storageMode, .hostedHealthSync)
        XCTAssertEqual(loaded.hostedWorkspaceID, "wk_test")
        XCTAssertEqual(loaded.hostedAgentEndpoint, "https://api.example.com/api/agent/health-data")
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthSyncTests-\(UUID().uuidString).sqlite")
    }
}
