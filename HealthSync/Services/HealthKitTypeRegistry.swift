import Foundation
import HealthKit

enum HealthKitTypeRegistry {
    static func readTypes(for selectedTypes: Set<HealthDataType>) -> Set<HKObjectType> {
        Set(selectedTypes.compactMap { objectType(for: $0) })
    }

    static func sampleType(for type: HealthDataType) -> HKSampleType? {
        objectType(for: type) as? HKSampleType
    }

    static func objectType(for type: HealthDataType) -> HKObjectType? {
        switch type {
        case .stepCount:
            HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .heartRate:
            HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .restingHeartRate:
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        case .hrvSDNN:
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .activeEnergy:
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .basalEnergy:
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)
        case .bodyMass:
            HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .bodyFatPercentage:
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        case .dietaryEnergy:
            HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        case .dietaryProtein:
            HKQuantityType.quantityType(forIdentifier: .dietaryProtein)
        case .dietaryCarbohydrates:
            HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)
        case .dietaryFat:
            HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)
        case .water:
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)
        case .sleepAnalysis:
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .workouts:
            HKObjectType.workoutType()
        }
    }

    static func preferredQuantityUnit(for type: HealthDataType) -> (hkUnit: HKUnit, sampleUnit: HealthSampleUnit)? {
        switch type {
        case .stepCount:
            (HKUnit.count(), .count)
        case .heartRate, .restingHeartRate:
            (HKUnit.count().unitDivided(by: .minute()), .countPerMinute)
        case .hrvSDNN:
            (HKUnit.secondUnit(with: .milli), .millisecond)
        case .activeEnergy, .basalEnergy, .dietaryEnergy:
            (HKUnit.kilocalorie(), .kilocalorie)
        case .bodyMass:
            (HKUnit.gramUnit(with: .kilo), .kilogram)
        case .bodyFatPercentage:
            (HKUnit.percent(), .percent)
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFat:
            (HKUnit.gram(), .gram)
        case .water:
            (HKUnit.literUnit(with: .milli), .milliliter)
        case .sleepAnalysis, .workouts:
            nil
        }
    }
}
