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
    let workspaceID: String?
    let exportID: String?

    private enum CodingKeys: String, CodingKey {
        case ok
        case received
        case duplicates
        case workspaceID = "workspace_id"
        case exportID = "export_id"
    }

    init(ok: Bool, received: Int, duplicates: Int, workspaceID: String? = nil, exportID: String? = nil) {
        self.ok = ok
        self.received = received
        self.duplicates = duplicates
        self.workspaceID = workspaceID
        self.exportID = exportID
    }
}
