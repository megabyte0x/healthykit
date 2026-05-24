import Foundation

enum HealthDataType: String, CaseIterable, Codable, Identifiable, Equatable {
    case stepCount = "step_count"
    case heartRate = "heart_rate"
    case restingHeartRate = "resting_heart_rate"
    case hrvSDNN = "hrv_sdnn"
    case activeEnergy = "active_energy"
    case basalEnergy = "basal_energy"
    case bodyMass = "body_mass"
    case bodyFatPercentage = "body_fat_percentage"
    case dietaryEnergy = "dietary_energy"
    case dietaryProtein = "dietary_protein"
    case dietaryCarbohydrates = "dietary_carbs"
    case dietaryFat = "dietary_fat"
    case water = "water"
    case sleepAnalysis = "sleep_analysis"
    case workouts = "workouts"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stepCount: "Steps"
        case .heartRate: "Heart rate"
        case .restingHeartRate: "Resting heart rate"
        case .hrvSDNN: "HRV"
        case .activeEnergy: "Active energy"
        case .basalEnergy: "Basal energy"
        case .bodyMass: "Weight/body mass"
        case .bodyFatPercentage: "Body fat percentage"
        case .dietaryEnergy: "Dietary energy"
        case .dietaryProtein: "Dietary protein"
        case .dietaryCarbohydrates: "Dietary carbohydrates"
        case .dietaryFat: "Dietary fat"
        case .water: "Water"
        case .sleepAnalysis: "Sleep"
        case .workouts: "Workouts"
        }
    }
}

enum HealthSampleUnit: String, Codable, Equatable {
    case count
    case countPerMinute
    case countPerSecond
    case millisecond
    case second
    case kilocalorie
    case kilojoule
    case joule
    case kilogram
    case gram
    case percent
    case fraction
    case milliliter
    case liter
    case meter
}

struct HealthQuantitySampleDTO: Equatable {
    let uuid: UUID
    let type: HealthDataType
    let value: Double
    let unit: HealthSampleUnit
    let startAt: Date
    let endAt: Date
    let sourceName: String
    let sourceBundleIdentifier: String?
    let metadata: [String: String]
}

struct HealthSleepSampleDTO: Equatable {
    let uuid: UUID
    let startAt: Date
    let endAt: Date
    let sourceName: String
    let sourceBundleIdentifier: String?
    let stage: String
    let metadata: [String: String]
}

struct HealthWorkoutSampleDTO: Equatable {
    let uuid: UUID
    let activityType: String
    let startAt: Date
    let endAt: Date
    let durationSeconds: Double
    let totalEnergyKcal: Double?
    let activeEnergyKcal: Double?
    let distanceMeters: Double?
    let sourceName: String
    let sourceBundleIdentifier: String?
    let metadata: [String: String]
}

enum NormalizationError: LocalizedError, Equatable {
    case unsupportedUnit(type: HealthDataType, unit: HealthSampleUnit)

    var errorDescription: String? {
        switch self {
        case let .unsupportedUnit(type, unit):
            "Cannot convert \(type.label) from \(unit.rawValue)"
        }
    }
}

struct HealthNormalizer {
    func metrics(from samples: [HealthQuantitySampleDTO]) throws -> [HealthMetric] {
        try samples.map { sample in
            let converted = try convert(value: sample.value, unit: sample.unit, type: sample.type)
            return HealthMetric(
                id: stableID(for: sample.uuid),
                type: sample.type.rawValue,
                value: converted.value,
                unit: converted.unit,
                startAt: sample.startAt,
                endAt: sample.endAt,
                sourceName: sample.sourceName,
                sourceBundleID: sample.sourceBundleIdentifier,
                metadata: sample.metadata
            )
        }
    }

    func sleepMetrics(from samples: [HealthSleepSampleDTO]) -> [HealthMetric] {
        samples.map { sample in
            var metadata = sample.metadata
            metadata["sleep_stage"] = sample.stage
            return HealthMetric(
                id: stableID(for: sample.uuid),
                type: HealthDataType.sleepAnalysis.rawValue,
                value: sample.endAt.timeIntervalSince(sample.startAt),
                unit: "seconds",
                startAt: sample.startAt,
                endAt: sample.endAt,
                sourceName: sample.sourceName,
                sourceBundleID: sample.sourceBundleIdentifier,
                metadata: metadata
            )
        }
    }

    func workouts(from samples: [HealthWorkoutSampleDTO]) -> [HealthWorkout] {
        samples.map { sample in
            HealthWorkout(
                id: stableID(for: sample.uuid),
                activityType: sample.activityType,
                startAt: sample.startAt,
                endAt: sample.endAt,
                durationSeconds: sample.durationSeconds,
                totalEnergyKcal: sample.totalEnergyKcal,
                activeEnergyKcal: sample.activeEnergyKcal,
                distanceMeters: sample.distanceMeters,
                sourceName: sample.sourceName,
                sourceBundleID: sample.sourceBundleIdentifier,
                metadata: sample.metadata
            )
        }
    }

    func payload(
        deviceID: String,
        dateRange: SyncDateRange,
        timezone: String = TimeZone.current.identifier,
        quantitySamples: [HealthQuantitySampleDTO],
        sleepSamples: [HealthSleepSampleDTO],
        workoutSamples: [HealthWorkoutSampleDTO],
        generatedAt: Date = Date()
    ) throws -> SyncPayload {
        SyncPayload(
            deviceID: deviceID,
            exportID: UUID(),
            generatedAt: generatedAt,
            timezone: timezone,
            source: "ios-healthkit",
            schemaVersion: 1,
            dateRange: dateRange,
            metrics: try metrics(from: quantitySamples) + sleepMetrics(from: sleepSamples),
            workouts: workouts(from: workoutSamples)
        )
    }

    private func stableID(for uuid: UUID) -> String {
        "healthkit:\(uuid.uuidString)"
    }

    private func convert(value: Double, unit: HealthSampleUnit, type: HealthDataType) throws -> (value: Double, unit: String) {
        switch type {
        case .stepCount:
            guard unit == .count else { throw NormalizationError.unsupportedUnit(type: type, unit: unit) }
            return (value, "count")
        case .heartRate, .restingHeartRate:
            switch unit {
            case .countPerMinute: return (value, "count/min")
            case .countPerSecond: return (value * 60, "count/min")
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .hrvSDNN:
            switch unit {
            case .millisecond: return (value, "ms")
            case .second: return (value * 1_000, "ms")
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .activeEnergy, .basalEnergy, .dietaryEnergy:
            switch unit {
            case .kilocalorie: return (value, "kcal")
            case .kilojoule: return (value / 4.184, "kcal")
            case .joule: return (value / 4_184, "kcal")
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .bodyMass:
            guard unit == .kilogram else { throw NormalizationError.unsupportedUnit(type: type, unit: unit) }
            return (value, "kg")
        case .bodyFatPercentage:
            switch unit {
            case .percent: return (value, "percent")
            case .fraction: return (value * 100, "percent")
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFat:
            guard unit == .gram else { throw NormalizationError.unsupportedUnit(type: type, unit: unit) }
            return (value, "g")
        case .water:
            switch unit {
            case .milliliter: return (value, "mL")
            case .liter: return (value * 1_000, "mL")
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .sleepAnalysis, .workouts:
            throw NormalizationError.unsupportedUnit(type: type, unit: unit)
        }
    }
}
