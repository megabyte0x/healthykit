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

final actor FailingForDateRangeStartUploader: SyncUploading {
    let failingStart: Date
    private(set) var uploadedIDs: [UUID] = []

    init(failingStart: Date) {
        self.failingStart = failingStart
    }

    func upload(batch: SyncBatch, configuration: UploadConfiguration) async throws -> UploadResult {
        uploadedIDs.append(batch.id)
        if batch.payload.dateRange.start == failingStart {
            throw APIClientError.transientFailure("old batch failed")
        }
        return UploadResult(ok: true, received: batch.payload.metrics.count + batch.payload.workouts.count, duplicates: 0)
    }
}

final actor PausingUploader: SyncUploading {
    private(set) var uploadCount = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var releases: [CheckedContinuation<Void, Never>] = []

    func upload(batch: SyncBatch, configuration: UploadConfiguration) async throws -> UploadResult {
        uploadCount += 1
        resumeSatisfiedWaiters()
        await withCheckedContinuation { continuation in
            releases.append(continuation)
        }
        return UploadResult(ok: true, received: batch.payload.metrics.count + batch.payload.workouts.count, duplicates: 0)
    }

    func waitForUploadCount(_ count: Int) async {
        if uploadCount >= count { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    func releaseUploads() {
        let pending = releases
        releases.removeAll()
        pending.forEach { $0.resume() }
    }

    private func resumeSatisfiedWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for waiter in waiters {
            if uploadCount >= waiter.0 {
                waiter.1.resume()
            } else {
                remaining.append(waiter)
            }
        }
        waiters = remaining
    }
}

final class SyncEngineTests: XCTestCase {
    func testBusyOperationRejectsSecondStart() {
        XCTAssertTrue(BusyOperation.canStart(isBusy: false))
        XCTAssertFalse(BusyOperation.canStart(isBusy: true))
    }

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

    func testUploadingSpecificBackfillBatchDoesNotRetryOlderPendingFailures() async throws {
        let store = SyncEngineTestsStore()
        let staleStart = Date(timeIntervalSince1970: 0)
        let currentStart = Date(timeIntervalSince1970: 60)
        let uploader = FailingForDateRangeStartUploader(failingStart: staleStart)
        let engine = SyncEngine(store: store, uploader: uploader)
        let stalePayload = SyncPayload.empty(
            deviceID: "device-123",
            dateRange: SyncDateRange(start: staleStart, end: currentStart),
            timezone: "Asia/Kolkata"
        )
        let currentPayload = SyncPayload.empty(
            deviceID: "device-123",
            dateRange: SyncDateRange(start: currentStart, end: Date(timeIntervalSince1970: 120)),
            timezone: "Asia/Kolkata"
        )
        let staleBatch = try await engine.queue(payload: stalePayload)
        let currentBatch = try await engine.queue(payload: currentPayload)

        let result = await engine.uploadQueuedBatch(
            currentBatch,
            configuration: UploadConfiguration(baseURL: "https://example.com", token: "secret-token", deviceID: "device-123", appVersion: "1.0")
        )

        let uploadedIDs = await uploader.uploadedIDs
        let pending = try await store.pendingBatches()

        XCTAssertEqual(result.uploadedCount, 1)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertEqual(uploadedIDs, [currentBatch.id])
        XCTAssertEqual(pending.map(\.id), [staleBatch.id])
    }

    func testSuccessfulUploadLogIncludesWorkspaceWhenBackendReturnsIt() async throws {
        let store = SyncEngineTestsStore()
        let engine = SyncEngine(store: store, uploader: WorkspaceIdentifyingUploader())
        let payload = SyncPayload.empty(
            deviceID: "device-123",
            dateRange: SyncDateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60)),
            timezone: "Asia/Kolkata"
        )

        _ = try await engine.queue(payload: payload)
        _ = await engine.uploadPending(
            configuration: UploadConfiguration(baseURL: "https://example.com", token: "secret-token", deviceID: "device-123", appVersion: "1.0")
        )

        let logs = await store.logs
        XCTAssertTrue(logs.contains { $0.message.contains("workspace wk_test") })
        XCTAssertFalse(logs.contains { $0.message.contains("secret-token") })
    }

    func testConcurrentUploadPendingDoesNotUploadSameBatchTwice() async throws {
        let store = SyncEngineTestsStore()
        let uploader = PausingUploader()
        let engine = SyncEngine(store: store, uploader: uploader)
        let payload = SyncPayload.empty(
            deviceID: "device-123",
            dateRange: SyncDateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60)),
            timezone: "Asia/Kolkata"
        )

        try await engine.queue(payload: payload)
        let firstRun = Task {
            await engine.uploadPending(
                configuration: UploadConfiguration(baseURL: "https://example.com", token: "secret-token", deviceID: "device-123", appVersion: "1.0")
            )
        }
        await uploader.waitForUploadCount(1)

        let secondRun = Task {
            await engine.uploadPending(
                configuration: UploadConfiguration(baseURL: "https://example.com", token: "secret-token", deviceID: "device-123", appVersion: "1.0")
            )
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        let uploadCountWhileFirstRunIsActive = await uploader.uploadCount
        await uploader.releaseUploads()
        let firstResult = await firstRun.value
        let secondResult = await secondRun.value

        XCTAssertEqual(uploadCountWhileFirstRunIsActive, 1)
        XCTAssertEqual(firstResult.uploadedCount, 1)
        XCTAssertEqual(secondResult.uploadedCount, 0)
    }
}

final class BackfillSyncTests: XCTestCase {
    func testLargeBackfillPayloadSplitsIntoServerSizedUploads() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 60)
        let metrics = (0..<205).map { index in
            HealthMetric(
                id: "healthkit:metric-\(index)",
                type: "step_count",
                value: Double(index),
                unit: "count",
                startAt: start,
                endAt: end,
                sourceName: "Codex",
                sourceBundleID: nil,
                metadata: [:]
            )
        }
        let payload = SyncPayload(
            deviceID: "device-123",
            exportID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            generatedAt: start,
            timezone: "Asia/Kolkata",
            source: "ios-healthkit",
            schemaVersion: 1,
            dateRange: SyncDateRange(start: start, end: end),
            metrics: metrics,
            workouts: []
        )

        let chunks = BackfillSync.uploadPayloads(for: payload)

        XCTAssertEqual(chunks.map(\.metrics.count), [100, 100, 5])
        XCTAssertTrue(chunks.allSatisfy(\.workouts.isEmpty))
        XCTAssertEqual(Set(chunks.map(\.exportID)).count, 3)
        XCTAssertTrue(chunks.allSatisfy { $0.dateRange == payload.dateRange })
    }

    func testEmptyBackfillPayloadDoesNotNeedUpload() {
        let payload = SyncPayload.empty(
            deviceID: "device-123",
            dateRange: SyncDateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60)),
            timezone: "Asia/Kolkata"
        )

        XCTAssertFalse(BackfillSync.shouldUpload(payload))
    }

    func testBackfillUploadFailureThrowsInsteadOfAllowingSuccess() {
        let result = SyncRunResult(
            uploadedCount: 0,
            failedCount: 1,
            messages: ["Cannot connect to the backend."]
        )

        XCTAssertThrowsError(try BackfillSync.validateUpload(result)) { error in
            XCTAssertEqual(error.localizedDescription, "Cannot connect to the backend.")
        }
    }

    func testBackfillUsesMonthSizedChunksForOptimizedHistoricalUploads() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 17))!

        let chunks = BackfillSync.chunks(start: start, end: end)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].start, start)
        XCTAssertEqual(chunks[0].end, calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!)
        XCTAssertEqual(chunks[1].end, calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!)
        XCTAssertEqual(chunks[2].end, end)
    }
}

final actor WorkspaceIdentifyingUploader: SyncUploading {
    func upload(batch: SyncBatch, configuration: UploadConfiguration) async throws -> UploadResult {
        UploadResult(
            ok: true,
            received: batch.payload.metrics.count + batch.payload.workouts.count,
            duplicates: 0,
            workspaceID: "wk_test",
            exportID: batch.payload.exportID.uuidString
        )
    }
}
