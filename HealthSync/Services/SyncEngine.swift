import Foundation

protocol BatchPersisting {
    func enqueueBatch(_ batch: SyncBatch) async throws
    func pendingBatches() async throws -> [SyncBatch]
    func markBatchUploaded(id: UUID, result: UploadResult) async throws
    func markBatchFailed(id: UUID, errorMessage: String) async throws
    func appendLog(_ log: SyncLogEntry) async throws
    func recordSyncAttempt(at date: Date) async throws
    func recordSyncSuccess(at date: Date) async throws
}

struct SyncRunResult: Equatable {
    let uploadedCount: Int
    let failedCount: Int
    let messages: [String]

    static let empty = SyncRunResult(uploadedCount: 0, failedCount: 0, messages: [])
}

actor SyncEngine {
    private let store: BatchPersisting
    private let uploader: SyncUploading
    private var isUploading = false

    init(store: BatchPersisting, uploader: SyncUploading = APIClient()) {
        self.store = store
        self.uploader = uploader
    }

    @discardableResult
    func queue(payload: SyncPayload) async throws -> SyncBatch {
        let batch = SyncBatch(payload: payload)
        try await store.enqueueBatch(batch)
        try await store.appendLog(
            SyncLogEntry(
                level: .info,
                message: "Queued \(payload.metrics.count) metrics and \(payload.workouts.count) workouts."
            )
        )
        return batch
    }

    func uploadPending(configuration: UploadConfiguration) async -> SyncRunResult {
        guard !isUploading else { return .empty }
        isUploading = true
        defer { isUploading = false }

        let attemptedAt = Date()
        do {
            try await store.recordSyncAttempt(at: attemptedAt)
            let pending = try await store.pendingBatches()
            guard !pending.isEmpty else { return .empty }

            var uploaded = 0
            var failed = 0
            var messages: [String] = []

            for batch in pending {
                do {
                    let result = try await uploader.upload(batch: batch, configuration: configuration)
                    try await store.markBatchUploaded(id: batch.id, result: result)
                    try await store.recordSyncSuccess(at: Date())
                    uploaded += 1
                    let message = "Uploaded batch \(batch.payload.exportID.uuidString) (\(result.received) received, \(result.duplicates) duplicates)."
                    messages.append(message)
                    try await store.appendLog(SyncLogEntry(level: .success, message: message))
                } catch {
                    failed += 1
                    let message = safeMessage(from: error, token: configuration.token)
                    messages.append(message)
                    try? await store.markBatchFailed(id: batch.id, errorMessage: message)
                    try? await store.appendLog(SyncLogEntry(level: .error, message: message))
                }
            }

            return SyncRunResult(uploadedCount: uploaded, failedCount: failed, messages: messages)
        } catch {
            let message = safeMessage(from: error, token: configuration.token)
            try? await store.appendLog(SyncLogEntry(level: .error, message: message))
            return SyncRunResult(uploadedCount: 0, failedCount: 1, messages: [message])
        }
    }

    private func safeMessage(from error: Error, token: String) -> String {
        var message: String
        if let apiError = error as? APIClientError {
            message = apiError.userMessage
        } else {
            message = error.localizedDescription
        }
        if !token.isEmpty {
            message = message.replacingOccurrences(of: token, with: "[redacted]")
        }
        return message
    }
}
