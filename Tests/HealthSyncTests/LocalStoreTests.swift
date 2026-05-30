import XCTest
@testable import HealthSync

final class LocalStoreTests: XCTestCase {
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
