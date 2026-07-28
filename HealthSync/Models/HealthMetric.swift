import Foundation

struct HealthMetric: Codable, Identifiable, Equatable {
    let id: String
    let type: String
    let value: Double
    let unit: String
    let startAt: Date
    let endAt: Date
    let sourceName: String
    let sourceBundleID: String?
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
        case unit
        case startAt = "start_at"
        case endAt = "end_at"
        case sourceName = "source_name"
        case sourceBundleID = "source_bundle_id"
        case metadata
    }
}

struct SyncDateRange: Codable, Equatable {
    let start: Date
    let end: Date
}

struct HealthRecordDeletion: Codable, Equatable, Hashable {
    enum Kind: String, Codable {
        case metric
        case workout
    }

    let id: String
    let kind: Kind

    static func healthKit(uuid: UUID, type: HealthDataType) -> HealthRecordDeletion {
        HealthRecordDeletion(
            id: "healthkit:\(uuid.uuidString)",
            kind: type == .workouts ? .workout : .metric
        )
    }
}

struct SyncPayload: Codable, Equatable {
    let deviceID: String
    let exportID: UUID
    let generatedAt: Date
    let timezone: String
    let source: String
    let schemaVersion: Int
    let dateRange: SyncDateRange
    let metrics: [HealthMetric]
    let workouts: [HealthWorkout]
    let deletions: [HealthRecordDeletion]

    var isEmpty: Bool {
        metrics.isEmpty && workouts.isEmpty && deletions.isEmpty
    }

    func chunked(maxRecords: Int) -> [SyncPayload] {
        let recordLimit = max(1, maxRecords)
        guard metrics.count + workouts.count + deletions.count > recordLimit else { return [self] }

        var chunks: [SyncPayload] = []
        var metricIndex = metrics.startIndex
        while metricIndex < metrics.endIndex {
            let nextIndex = metrics.index(metricIndex, offsetBy: recordLimit, limitedBy: metrics.endIndex) ?? metrics.endIndex
            chunks.append(copy(metrics: Array(metrics[metricIndex..<nextIndex]), workouts: [], deletions: []))
            metricIndex = nextIndex
        }

        var workoutIndex = workouts.startIndex
        while workoutIndex < workouts.endIndex {
            let nextIndex = workouts.index(workoutIndex, offsetBy: recordLimit, limitedBy: workouts.endIndex) ?? workouts.endIndex
            chunks.append(copy(metrics: [], workouts: Array(workouts[workoutIndex..<nextIndex]), deletions: []))
            workoutIndex = nextIndex
        }

        var deletionIndex = deletions.startIndex
        while deletionIndex < deletions.endIndex {
            let nextIndex = deletions.index(deletionIndex, offsetBy: recordLimit, limitedBy: deletions.endIndex) ?? deletions.endIndex
            chunks.append(copy(metrics: [], workouts: [], deletions: Array(deletions[deletionIndex..<nextIndex])))
            deletionIndex = nextIndex
        }

        return chunks
    }

    private func copy(
        metrics: [HealthMetric],
        workouts: [HealthWorkout],
        deletions: [HealthRecordDeletion]
    ) -> SyncPayload {
        SyncPayload(
            deviceID: deviceID,
            exportID: UUID(),
            generatedAt: generatedAt,
            timezone: timezone,
            source: source,
            schemaVersion: schemaVersion,
            dateRange: dateRange,
            metrics: metrics,
            workouts: workouts,
            deletions: deletions
        )
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case exportID = "export_id"
        case generatedAt = "generated_at"
        case timezone
        case source
        case schemaVersion = "schema_version"
        case dateRange = "date_range"
        case metrics
        case workouts
        case deletions
    }

    init(
        deviceID: String,
        exportID: UUID,
        generatedAt: Date,
        timezone: String,
        source: String,
        schemaVersion: Int,
        dateRange: SyncDateRange,
        metrics: [HealthMetric],
        workouts: [HealthWorkout],
        deletions: [HealthRecordDeletion] = []
    ) {
        self.deviceID = deviceID
        self.exportID = exportID
        self.generatedAt = generatedAt
        self.timezone = timezone
        self.source = source
        self.schemaVersion = schemaVersion
        self.dateRange = dateRange
        self.metrics = metrics
        self.workouts = workouts
        self.deletions = deletions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        exportID = try container.decode(UUID.self, forKey: .exportID)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        timezone = try container.decode(String.self, forKey: .timezone)
        source = try container.decode(String.self, forKey: .source)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        dateRange = try container.decode(SyncDateRange.self, forKey: .dateRange)
        metrics = try container.decode([HealthMetric].self, forKey: .metrics)
        workouts = try container.decode([HealthWorkout].self, forKey: .workouts)
        deletions = try container.decodeIfPresent([HealthRecordDeletion].self, forKey: .deletions) ?? []
    }

    static func empty(deviceID: String, dateRange: SyncDateRange, timezone: String) -> SyncPayload {
        SyncPayload(
            deviceID: deviceID,
            exportID: UUID(),
            generatedAt: Date(),
            timezone: timezone,
            source: "ios-healthkit",
            schemaVersion: 1,
            dateRange: dateRange,
            metrics: [],
            workouts: [],
            deletions: []
        )
    }
}

enum PayloadJSON {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(PayloadDateFormatter.string(from: date))
        }
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = PayloadDateFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
        }
        return decoder
    }
}

private enum PayloadDateFormatter {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}
