import Foundation

struct HealthWorkout: Codable, Identifiable, Equatable {
    let id: String
    let activityType: String
    let startAt: Date
    let endAt: Date
    let durationSeconds: Double
    let totalEnergyKcal: Double?
    let activeEnergyKcal: Double?
    let distanceMeters: Double?
    let sourceName: String
    let sourceBundleID: String?
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case activityType = "activity_type"
        case startAt = "start_at"
        case endAt = "end_at"
        case durationSeconds = "duration_seconds"
        case totalEnergyKcal = "total_energy_kcal"
        case activeEnergyKcal = "active_energy_kcal"
        case distanceMeters = "distance_meters"
        case sourceName = "source_name"
        case sourceBundleID = "source_bundle_id"
        case metadata
    }
}
