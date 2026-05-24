import Foundation

struct SyncBatch: Codable, Identifiable, Equatable {
    let id: UUID
    var payload: SyncPayload
    var createdAt: Date
    var uploadedAt: Date?
    var attemptCount: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        payload: SyncPayload,
        createdAt: Date = Date(),
        uploadedAt: Date? = nil,
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.payload = payload
        self.createdAt = createdAt
        self.uploadedAt = uploadedAt
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}

struct UploadResult: Codable, Equatable {
    let ok: Bool
    let received: Int
    let duplicates: Int
}
