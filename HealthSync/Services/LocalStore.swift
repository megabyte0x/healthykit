import Foundation
import SQLite3

enum SQLiteStoreError: LocalizedError {
    case openFailed(String)
    case statementFailed(String)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case let .openFailed(message):
            "Could not open local database: \(message)"
        case let .statementFailed(message):
            "Local database error: \(message)"
        case .encodingFailed:
            "Could not encode local data."
        }
    }
}

actor SQLiteLocalStore: BatchPersisting {
    private var db: OpaquePointer?

    init(url: URL? = nil) throws {
        let databaseURL = try url ?? Self.defaultDatabaseURL()
        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            throw SQLiteStoreError.openFailed(Self.message(from: db))
        }
        try Self.migrate(db: db)
    }

    deinit {
        sqlite3_close(db)
    }

    func loadSettings() async throws -> AppSettings {
        guard let value = try selectSetting("app_settings"), let data = value.data(using: .utf8) else {
            return .default
        }
        var settings = try JSONDecoder().decode(AppSettings.self, from: data)
        if settings.migrateHostedEndpoints() {
            // Keep loaded credentials usable if the local write fails; the next load retries persistence.
            try? await saveSettings(settings)
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        guard let value = String(data: data, encoding: .utf8) else {
            throw SQLiteStoreError.encodingFailed
        }
        try upsertSetting(key: "app_settings", value: value)
    }

    func deviceID() async throws -> String {
        if let existing = try selectSetting("device_id"), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        try upsertSetting(key: "device_id", value: id)
        return id
    }

    func loadAnchor(for type: HealthDataType) async throws -> String? {
        try selectAnchor(type.rawValue)
    }

    func saveAnchor(_ anchor: String, for type: HealthDataType) async throws {
        try upsertAnchor(key: type.rawValue, value: anchor)
    }

    func enqueueBatch(_ batch: SyncBatch) async throws {
        try replaceSupersededRecords(with: batch.payload, batches: [batch])
    }

    func enqueuePayloadChunks(_ payload: SyncPayload, maxRecords: Int) throws -> [SyncBatch] {
        let batches = payload.chunked(maxRecords: maxRecords).map { SyncBatch(payload: $0) }
        try replaceSupersededRecords(with: payload, batches: batches)
        return batches
    }

    private func replaceSupersededRecords(with payload: SyncPayload, batches: [SyncBatch]) throws {
        let metricIDs = Set(payload.metrics.map(\.id))
            .union(payload.deletions.filter { $0.kind == .metric }.map(\.id))
        let workoutIDs = Set(payload.workouts.map(\.id))
            .union(payload.deletions.filter { $0.kind == .workout }.map(\.id))
        try Self.execute("BEGIN IMMEDIATE", db: db)
        do {
            for pending in try readPendingBatches() where pending.payload.deviceID == payload.deviceID {
                let remaining = pending.payload.excludingRecords(metricIDs: metricIDs, workoutIDs: workoutIDs)
                guard remaining != pending.payload else { continue }
                try deleteBatch(id: pending.id)
                if !remaining.isEmpty {
                    try insertBatch(SyncBatch(payload: remaining, createdAt: pending.createdAt))
                }
            }
            for batch in batches {
                try insertBatch(batch)
            }
            try Self.execute("COMMIT", db: db)
        } catch {
            try? Self.execute("ROLLBACK", db: db)
            throw error
        }
    }

    private func insertBatch(_ batch: SyncBatch) throws {
        let payloadData = try PayloadJSON.encoder.encode(batch.payload)
        guard let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            throw SQLiteStoreError.encodingFailed
        }
        let sql = """
        INSERT INTO batches (id, payload_json, created_at, uploaded_at, attempt_count, last_error)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindText(batch.id.uuidString, to: statement, at: 1)
        try bindText(payloadJSON, to: statement, at: 2)
        sqlite3_bind_double(statement, 3, batch.createdAt.timeIntervalSince1970)
        if let uploadedAt = batch.uploadedAt {
            sqlite3_bind_double(statement, 4, uploadedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_int(statement, 5, Int32(batch.attemptCount))
        if let lastError = batch.lastError {
            try bindText(lastError, to: statement, at: 6)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        try stepDone(statement)
    }

    func pendingBatches() async throws -> [SyncBatch] {
        try readPendingBatches()
    }

    private func readPendingBatches(oldestFirst: Bool = false) throws -> [SyncBatch] {
        let sql = """
        SELECT id, payload_json, created_at, uploaded_at, attempt_count, last_error
        FROM batches
        WHERE uploaded_at IS NULL
        ORDER BY \(oldestFirst ? "created_at ASC, rowid ASC" : "attempt_count ASC, created_at ASC, rowid ASC")
        """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var batches: [SyncBatch] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            batches.append(try readBatch(from: statement))
        }
        return batches
    }

    func splitOversizedPendingBatches(maxRecords: Int) throws {
        try normalizePendingRecords()
        for batch in try readPendingBatches() {
            let chunks = batch.payload.chunked(maxRecords: maxRecords)
            guard chunks.count > 1 else { continue }
            try Self.execute("BEGIN IMMEDIATE", db: db)
            do {
                for payload in chunks {
                    try insertBatch(SyncBatch(payload: payload, createdAt: batch.createdAt))
                }
                try deleteBatch(id: batch.id)
                try Self.execute("COMMIT", db: db)
            } catch {
                try? Self.execute("ROLLBACK", db: db)
                throw error
            }
        }
    }

    private func normalizePendingRecords() throws {
        try Self.execute("BEGIN IMMEDIATE", db: db)
        do {
            var metricIDs: [String: Set<String>] = [:]
            var workoutIDs: [String: Set<String>] = [:]
            for batch in try readPendingBatches(oldestFirst: true).reversed() {
                let device = batch.payload.deviceID
                let remaining = batch.payload.excludingRecords(metricIDs: metricIDs[device, default: []], workoutIDs: workoutIDs[device, default: []])
                metricIDs[device, default: []].formUnion(batch.payload.metrics.map(\.id))
                workoutIDs[device, default: []].formUnion(batch.payload.workouts.map(\.id))
                for deletion in batch.payload.deletions {
                    if deletion.kind == .metric {
                        metricIDs[device, default: []].insert(deletion.id)
                    } else {
                        workoutIDs[device, default: []].insert(deletion.id)
                    }
                }
                guard remaining != batch.payload else { continue }
                try deleteBatch(id: batch.id)
                if !remaining.isEmpty {
                    try insertBatch(SyncBatch(payload: remaining, createdAt: batch.createdAt))
                }
            }
            try Self.execute("COMMIT", db: db)
        } catch {
            try? Self.execute("ROLLBACK", db: db)
            throw error
        }
    }

    func claimDailyMaintenance(_ key: String, now: Date, calendar: Calendar) throws -> Bool {
        let settingKey = "maintenance_\(key)_attempted_at"
        if let previous = try dateSetting(settingKey), previous >= calendar.startOfDay(for: now) {
            return false
        }
        try upsertSetting(key: settingKey, value: String(now.timeIntervalSince1970))
        return true
    }

    private func deleteBatch(id: UUID) throws {
        let statement = try prepare("DELETE FROM batches WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        try bindText(id.uuidString, to: statement, at: 1)
        try stepDone(statement)
    }

    func markBatchUploaded(id: UUID, result: UploadResult) async throws {
        let sql = "UPDATE batches SET uploaded_at = ?, last_error = NULL WHERE id = ?"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        try bindText(id.uuidString, to: statement, at: 2)
        try stepDone(statement)
    }

    func markBatchFailed(id: UUID, errorMessage: String) async throws {
        let sql = "UPDATE batches SET attempt_count = attempt_count + 1, last_error = ? WHERE id = ?"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindText(errorMessage, to: statement, at: 1)
        try bindText(id.uuidString, to: statement, at: 2)
        try stepDone(statement)
    }

    func appendLog(_ log: SyncLogEntry) async throws {
        let sql = "INSERT INTO logs (id, created_at, level, message) VALUES (?, ?, ?, ?)"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindText(log.id.uuidString, to: statement, at: 1)
        sqlite3_bind_double(statement, 2, log.createdAt.timeIntervalSince1970)
        try bindText(log.level.rawValue, to: statement, at: 3)
        try bindText(log.message, to: statement, at: 4)
        try stepDone(statement)
    }

    func recentLogs(limit: Int = 25) async throws -> [SyncLogEntry] {
        let sql = "SELECT id, created_at, level, message FROM logs ORDER BY created_at DESC LIMIT ?"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))

        var logs: [SyncLogEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let id = UUID(uuidString: columnText(statement, 0)),
                let level = SyncLogLevel(rawValue: columnText(statement, 2))
            else { continue }
            logs.append(
                SyncLogEntry(
                    id: id,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                    level: level,
                    message: columnText(statement, 3)
                )
            )
        }
        return logs
    }

    func recordSyncAttempt(at date: Date) async throws {
        try upsertSetting(key: "last_attempted_sync_at", value: String(date.timeIntervalSince1970))
    }

    func recordSyncSuccess(at date: Date) async throws {
        try upsertSetting(key: "last_successful_sync_at", value: String(date.timeIntervalSince1970))
    }

    func syncStatus() async throws -> SyncStatus {
        SyncStatus(
            lastSuccessfulSyncAt: try dateSetting("last_successful_sync_at"),
            lastAttemptedSyncAt: try dateSetting("last_attempted_sync_at"),
            pendingUploadCount: try pendingBatchCount(),
            lastError: try latestError()
        )
    }

    func pruneUploaded(olderThan cutoff: Date) async throws {
        let sql = "DELETE FROM batches WHERE uploaded_at IS NOT NULL AND uploaded_at < ?"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, cutoff.timeIntervalSince1970)
        try stepDone(statement)
    }

    private static func defaultDatabaseURL() throws -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HealthSync", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("HealthSync.sqlite")
    }

    private static func migrate(db: OpaquePointer?) throws {
        try execute("PRAGMA journal_mode = WAL", db: db)
        try execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)", db: db)
        try execute("CREATE TABLE IF NOT EXISTS anchors (type TEXT PRIMARY KEY, value TEXT NOT NULL)", db: db)
        try execute("""
        CREATE TABLE IF NOT EXISTS batches (
            id TEXT PRIMARY KEY,
            payload_json TEXT NOT NULL,
            created_at REAL NOT NULL,
            uploaded_at REAL,
            attempt_count INTEGER NOT NULL,
            last_error TEXT
        )
        """, db: db)
        try execute("""
        CREATE TABLE IF NOT EXISTS logs (
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            level TEXT NOT NULL,
            message TEXT NOT NULL
        )
        """, db: db)
    }

    private static func execute(_ sql: String, db: OpaquePointer?) throws {
        var error: UnsafeMutablePointer<Int8>?
        let status = sqlite3_exec(db, sql, nil, nil, &error)
        if status != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? message(from: db)
            sqlite3_free(error)
            throw SQLiteStoreError.statementFailed(message)
        }
    }

    private func upsertSetting(key: String, value: String) throws {
        let statement = try prepare("INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
        defer { sqlite3_finalize(statement) }
        try bindText(key, to: statement, at: 1)
        try bindText(value, to: statement, at: 2)
        try stepDone(statement)
    }

    private func selectSetting(_ key: String) throws -> String? {
        let statement = try prepare("SELECT value FROM settings WHERE key = ?")
        defer { sqlite3_finalize(statement) }
        try bindText(key, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return columnText(statement, 0)
    }

    private func upsertAnchor(key: String, value: String) throws {
        let statement = try prepare("INSERT INTO anchors (type, value) VALUES (?, ?) ON CONFLICT(type) DO UPDATE SET value = excluded.value")
        defer { sqlite3_finalize(statement) }
        try bindText(key, to: statement, at: 1)
        try bindText(value, to: statement, at: 2)
        try stepDone(statement)
    }

    private func selectAnchor(_ key: String) throws -> String? {
        let statement = try prepare("SELECT value FROM anchors WHERE type = ?")
        defer { sqlite3_finalize(statement) }
        try bindText(key, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return columnText(statement, 0)
    }

    private func dateSetting(_ key: String) throws -> Date? {
        guard let value = try selectSetting(key), let interval = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private func pendingBatchCount() throws -> Int {
        let statement = try prepare("SELECT COUNT(*) FROM batches WHERE uploaded_at IS NULL")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func latestError() throws -> String? {
        let statement = try prepare("SELECT level, message FROM logs ORDER BY created_at DESC LIMIT 1")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard columnText(statement, 0) == SyncLogLevel.error.rawValue else { return nil }
        return columnText(statement, 1)
    }

    private func readBatch(from statement: OpaquePointer?) throws -> SyncBatch {
        let id = UUID(uuidString: columnText(statement, 0)) ?? UUID()
        let payloadData = Data(columnText(statement, 1).utf8)
        let payload = try PayloadJSON.decoder.decode(SyncPayload.self, from: payloadData)
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        let uploadedAt = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
        let attemptCount = Int(sqlite3_column_int(statement, 4))
        let lastError = sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : columnText(statement, 5)
        return SyncBatch(
            id: id,
            payload: payload,
            createdAt: createdAt,
            uploadedAt: uploadedAt,
            attemptCount: attemptCount,
            lastError: lastError
        )
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.statementFailed(Self.message(from: db))
        }
        return statement
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw SQLiteStoreError.statementFailed(Self.message(from: db))
        }
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.statementFailed(Self.message(from: db))
        }
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private static func message(from db: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(db) else { return "Unknown SQLite error" }
        return String(cString: message)
    }
}
