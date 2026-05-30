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

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthSyncTests-\(UUID().uuidString).sqlite")
    }
}
