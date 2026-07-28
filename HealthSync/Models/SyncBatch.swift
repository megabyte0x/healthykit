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
    let deleted: Int
    let workspaceID: String?
    let exportID: String?

    private enum CodingKeys: String, CodingKey {
        case ok
        case received
        case duplicates
        case deleted
        case workspaceID = "workspace_id"
        case exportID = "export_id"
    }

    init(
        ok: Bool,
        received: Int,
        duplicates: Int,
        deleted: Int = 0,
        workspaceID: String? = nil,
        exportID: String? = nil
    ) {
        self.ok = ok
        self.received = received
        self.duplicates = duplicates
        self.deleted = deleted
        self.workspaceID = workspaceID
        self.exportID = exportID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decode(Bool.self, forKey: .ok)
        received = try container.decode(Int.self, forKey: .received)
        duplicates = try container.decode(Int.self, forKey: .duplicates)
        deleted = try container.decodeIfPresent(Int.self, forKey: .deleted) ?? 0
        workspaceID = try container.decodeIfPresent(String.self, forKey: .workspaceID)
        exportID = try container.decodeIfPresent(String.self, forKey: .exportID)
    }
}
