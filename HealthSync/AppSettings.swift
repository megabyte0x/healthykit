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
}

struct AppSettings: Codable, Equatable {
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
        selectedTypes: [
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
        ],
        syncFrequency: .manualOnly,
        hasRequestedHealthPermissions: false,
        storageMode: .customBackend,
        hostedWorkspaceID: nil,
        hostedAgentEndpoint: nil
    )

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
        selectedTypes = try container.decode(Set<HealthDataType>.self, forKey: .selectedTypes)
        syncFrequency = try container.decode(SyncFrequency.self, forKey: .syncFrequency)
        hasRequestedHealthPermissions = try container.decode(Bool.self, forKey: .hasRequestedHealthPermissions)
        storageMode = try container.decodeIfPresent(StorageMode.self, forKey: .storageMode) ?? .customBackend
        hostedWorkspaceID = try container.decodeIfPresent(String.self, forKey: .hostedWorkspaceID)
        hostedAgentEndpoint = try container.decodeIfPresent(String.self, forKey: .hostedAgentEndpoint)
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
