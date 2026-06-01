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
        switch type.kind {
        case .quantity:
            guard let rawValue = type.healthKitIdentifierRawValue else { return nil }
            return HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: rawValue))
        case .category:
            guard let rawValue = type.healthKitIdentifierRawValue else { return nil }
            return HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: rawValue))
        case .workout:
            return HKObjectType.workoutType()
        }
    }

    static func preferredQuantityUnit(for type: HealthDataType) -> (hkUnit: HKUnit, sampleUnit: HealthSampleUnit)? {
        guard let sampleUnit = type.preferredSampleUnit else { return nil }
        return (HKUnit(from: sampleUnit.healthKitUnitString), sampleUnit)
    }
}
