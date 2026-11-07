import Foundation

enum SyncFrequency: String, CaseIterable, Codable, Identifiable {
    case manualOnly
    case hourlyBestEffort
    case dailyBestEffort

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manualOnly: "Manual only"
        case .hourlyBestEffort: "Hourly best-effort"
        case .dailyBestEffort: "Daily best-effort"
        }
    }

    var intervalSeconds: UInt64? {
        switch self {
        case .manualOnly: nil
        case .hourlyBestEffort: 60 * 60
        case .dailyBestEffort: 24 * 60 * 60
        }
    }
}

enum BackgroundSyncSchedule {
    static func earliestBeginDate(for frequency: SyncFrequency, now: Date = Date()) -> Date? {
        guard let interval = frequency.intervalSeconds else { return nil }
        return now.addingTimeInterval(TimeInterval(interval))
    }
}

enum StorageMode: String, CaseIterable, Codable, Identifiable {
    case customBackend
    case hostedHealthSync

    var id: String { rawValue }

    var label: String {
        switch self {
        case .customBackend: "My own backend"
        case .hostedHealthSync: "Hosted HealthSync storage"
        }
    }

    var showsManualBackendSettings: Bool {
        switch self {
        case .customBackend: true
        case .hostedHealthSync: false
        }
    }
}

struct AppSettings: Codable, Equatable {
    static let hostedBackendURL = "https://api.healthysync.app"

    var backendURL: String
    var selectedTypes: Set<HealthDataType>
    var syncFrequency: SyncFrequency
    var hasRequestedHealthPermissions: Bool
    var storageMode: StorageMode
    var hostedWorkspaceID: String?
    var hostedAgentEndpoint: String?

    private enum CodingKeys: String, CodingKey {
        case backendURL
        case selectedTypes
        case syncFrequency
        case hasRequestedHealthPermissions
        case storageMode
        case hostedWorkspaceID
        case hostedAgentEndpoint
    }

    static let `default` = AppSettings(
        backendURL: "",
        selectedTypes: Set(HealthDataType.allCases),
        syncFrequency: .hourlyBestEffort,
        hasRequestedHealthPermissions: false,
        storageMode: .hostedHealthSync,
        hostedWorkspaceID: nil,
        hostedAgentEndpoint: nil
    )

    private static let legacyDefaultSelectedTypes: Set<HealthDataType> = [
        .stepCount,
        .heartRate,
        .restingHeartRate,
        .hrvSDNN,
        .activeEnergy,
        .basalEnergy,
        .bodyMass,
        .bodyFatPercentage,
        .sleepAnalysis,
        .workouts
    ]

    var effectiveBackendURL: String {
        switch storageMode {
        case .customBackend:
            Self.migratedHostedURL(backendURL, agent: false) ?? backendURL
        case .hostedHealthSync:
            Self.hostedBackendURL
        }
    }

    @discardableResult
    mutating func migrateHostedEndpoints() -> Bool {
        var changed = false
        if let migrated = Self.migratedHostedURL(backendURL, agent: false) {
            backendURL = migrated
            changed = true
        }
        if let endpoint = hostedAgentEndpoint,
           let migrated = Self.migratedHostedURL(endpoint, agent: true) {
            hostedAgentEndpoint = migrated
            changed = true
        }
        return changed
    }

    private static func migratedHostedURL(_ value: String, agent: Bool) -> String? {
        guard let source = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              source.scheme?.lowercased() == "https",
              source.host?.lowercased() == "dtzydnjnqkruxaacgkio.supabase.co",
              source.port == nil || source.port == 443,
              source.user == nil, source.password == nil,
              var target = URLComponents(string: hostedBackendURL) else { return nil }

        let prefix = "/functions/v1/healthsync"
        let path = source.percentEncodedPath.hasSuffix("/")
            ? String(source.percentEncodedPath.dropLast()) : source.percentEncodedPath
        let targetPath: String
        if agent {
            let paths = ["health-data", "metrics", "workouts", "syncs"].map { "/api/agent/" + $0 }
            guard let suffix = paths.first(where: { path == prefix + $0 }) else { return nil }
            targetPath = suffix
        } else {
            guard path == prefix else { return nil }
            targetPath = ""
        }
        target.percentEncodedPath = targetPath
        target.percentEncodedQuery = source.percentEncodedQuery
        target.percentEncodedFragment = source.percentEncodedFragment
        return target.string
    }

    init(
        backendURL: String,
        selectedTypes: Set<HealthDataType>,
        syncFrequency: SyncFrequency,
        hasRequestedHealthPermissions: Bool,
        storageMode: StorageMode,
        hostedWorkspaceID: String?,
        hostedAgentEndpoint: String?
    ) {
        self.backendURL = backendURL
        self.selectedTypes = selectedTypes
        self.syncFrequency = syncFrequency
        self.hasRequestedHealthPermissions = hasRequestedHealthPermissions
        self.storageMode = storageMode
        self.hostedWorkspaceID = hostedWorkspaceID
        self.hostedAgentEndpoint = hostedAgentEndpoint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backendURL = try container.decode(String.self, forKey: .backendURL)
        let decodedSelectedTypes = try container.decode(Set<HealthDataType>.self, forKey: .selectedTypes)
        selectedTypes = Self.selectedTypesWithDefaultDietaryTypes(decodedSelectedTypes)
        syncFrequency = try container.decode(SyncFrequency.self, forKey: .syncFrequency)
        hasRequestedHealthPermissions = try container.decode(Bool.self, forKey: .hasRequestedHealthPermissions)
        storageMode = try container.decodeIfPresent(StorageMode.self, forKey: .storageMode) ?? .customBackend
        hostedWorkspaceID = try container.decodeIfPresent(String.self, forKey: .hostedWorkspaceID)
        hostedAgentEndpoint = try container.decodeIfPresent(String.self, forKey: .hostedAgentEndpoint)
    }

    private static func selectedTypesWithDefaultDietaryTypes(_ selectedTypes: Set<HealthDataType>) -> Set<HealthDataType> {
        guard selectedTypes == legacyDefaultSelectedTypes else { return selectedTypes }
        return selectedTypes.union(HealthDataType.dietaryTypes)
    }
}

struct SyncStatus: Equatable {
    var lastSuccessfulSyncAt: Date?
    var lastAttemptedSyncAt: Date?
    var pendingUploadCount: Int
    var lastError: String?

    static let empty = SyncStatus(
        lastSuccessfulSyncAt: nil,
        lastAttemptedSyncAt: nil,
        pendingUploadCount: 0,
        lastError: nil
    )
}
