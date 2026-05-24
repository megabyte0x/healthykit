import Foundation

enum SyncLogLevel: String, Codable, Equatable {
    case info
    case success
    case warning
    case error
}

struct SyncLogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let level: SyncLogLevel
    let message: String

    init(id: UUID = UUID(), createdAt: Date = Date(), level: SyncLogLevel, message: String) {
        self.id = id
        self.createdAt = createdAt
        self.level = level
        self.message = message
    }
}
