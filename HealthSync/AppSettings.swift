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

struct AppSettings: Codable, Equatable {
    var backendURL: String
    var selectedTypes: Set<HealthDataType>
    var syncFrequency: SyncFrequency
    var hasRequestedHealthPermissions: Bool

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
        hasRequestedHealthPermissions: false
    )
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
