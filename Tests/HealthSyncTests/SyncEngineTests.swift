import XCTest
@testable import HealthSync

final actor SyncEngineTestsStore: BatchPersisting {
    private(set) var batches: [SyncBatch] = []
    private(set) var logs: [SyncLogEntry] = []
    private(set) var lastAttemptedSyncAt: Date?
    private(set) var lastSuccessfulSyncAt: Date?

    func enqueueBatch(_ batch: SyncBatch) async throws {
        batches.append(batch)
    }

    func pendingBatches() async throws -> [SyncBatch] {
        batches.filter { $0.uploadedAt == nil }
    }

    func markBatchUploaded(id: UUID, result: UploadResult) async throws {
        guard let index = batches.firstIndex(where: { $0.id == id }) else { return }
        batches[index].uploadedAt = Date()
        batches[index].lastError = nil
    }

    func markBatchFailed(id: UUID, errorMessage: String) async throws {
        guard let index = batches.firstIndex(where: { $0.id == id }) else { return }
        batches[index].attemptCount += 1
        batches[index].lastError = errorMessage
    }

    func appendLog(_ log: SyncLogEntry) async throws {
        logs.append(log)
    }

    func recordSyncAttempt(at date: Date) async throws {
        lastAttemptedSyncAt = date
    }

    func recordSyncSuccess(at date: Date) async throws {
        lastSuccessfulSyncAt = date
    }
}

final actor FailingUploader: SyncUploading {
    func upload(batch: SyncBatch, configuration: UploadConfiguration) async throws -> UploadResult {
        throw APIClientError.transientFailure("network unavailable")
    }
}

final actor SucceedingUploader: SyncUploading {
    private(set) var uploadedIDs: [UUID] = []

    func upload(batch: SyncBatch, configuration: UploadConfiguration) async throws -> UploadResult {
        uploadedIDs.append(batch.id)
        return UploadResult(ok: true, received: batch.payload.metrics.count + batch.payload.workouts.count, duplicates: 0)
    }
}

final class SyncEngineTests: XCTestCase {
    func testFailedUploadKeepsBatchQueuedForRetry() async throws {
        let store = SyncEngineTestsStore()
        let engine = SyncEngine(store: store, uploader: FailingUploader())
        let payload = SyncPayload.empty(
            deviceID: "device-123",
            dateRange: SyncDateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60)),
            timezone: "Asia/Kolkata"
        )

        let batch = try await engine.queue(payload: payload)
        let result = await engine.uploadPending(
            configuration: UploadConfiguration(baseURL: "https://example.com", token: "secret-token", deviceID: "device-123", appVersion: "1.0")
        )
        let pending = try await store.pendingBatches()

        XCTAssertEqual(result.uploadedCount, 0)
        XCTAssertEqual(result.failedCount, 1)
        XCTAssertEqual(pending.map(\.id), [batch.id])
        XCTAssertEqual(pending.first?.attemptCount, 1)
        XCTAssertFalse((pending.first?.lastError ?? "").contains("secret-token"))
    }

    func testSuccessfulUploadMarksBatchUploadedAndAvoidsResending() async throws {
        let store = SyncEngineTestsStore()
        let uploader = SucceedingUploader()
        let engine = SyncEngine(store: store, uploader: uploader)
        let payload = SyncPayload.empty(
            deviceID: "device-123",
            dateRange: SyncDateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60)),
            timezone: "Asia/Kolkata"
        )

        let batch = try await engine.queue(payload: payload)
        _ = await engine.uploadPending(
            configuration: UploadConfiguration(baseURL: "https://example.com", token: "secret-token", deviceID: "device-123", appVersion: "1.0")
        )
        _ = await engine.uploadPending(
            configuration: UploadConfiguration(baseURL: "https://example.com", token: "secret-token", deviceID: "device-123", appVersion: "1.0")
        )

        let uploadedIDs = await uploader.uploadedIDs
        let pending = try await store.pendingBatches()
        let lastSuccessfulSyncAt = await store.lastSuccessfulSyncAt

        XCTAssertEqual(uploadedIDs, [batch.id])
        XCTAssertTrue(pending.isEmpty)
        XCTAssertNotNil(lastSuccessfulSyncAt)
    }
}
