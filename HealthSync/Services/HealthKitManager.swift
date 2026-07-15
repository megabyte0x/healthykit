import Foundation
import HealthKit

struct HealthKitFetchResult: Equatable {
    var quantitySamples: [HealthQuantitySampleDTO]
    var categorySamples: [HealthCategorySampleDTO]
    var sleepSamples: [HealthSleepSampleDTO]
    var workoutSamples: [HealthWorkoutSampleDTO]

    static let empty = HealthKitFetchResult(quantitySamples: [], categorySamples: [], sleepSamples: [], workoutSamples: [])

    var isEmpty: Bool {
        quantitySamples.isEmpty && categorySamples.isEmpty && sleepSamples.isEmpty && workoutSamples.isEmpty
    }
}

struct HealthKitIncrementalResult: Equatable {
    let fetchResult: HealthKitFetchResult
    let anchors: [HealthDataType: String]
}

private enum BackfillQuantityAggregationStrategy: String {
    case dailySum = "daily_sum"
    case dailyAverage = "daily_average"

    var statisticsOptions: HKStatisticsOptions {
        switch self {
        case .dailySum:
            .cumulativeSum
        case .dailyAverage:
            .discreteAverage
        }
    }

    func value(from statistics: HKStatistics, unit: HKUnit) -> Double? {
        switch self {
        case .dailySum:
            statistics.sumQuantity()?.doubleValue(for: unit)
        case .dailyAverage:
            statistics.averageQuantity()?.doubleValue(for: unit)
        }
    }
}

enum HealthKitManagerError: LocalizedError {
    case healthDataUnavailable
    case authorizationNotDetermined
    case unsupportedType(HealthDataType)
    case statisticsUnavailable(HealthDataType)
    case missingAnchor

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            "Health data is not available on this device."
        case .authorizationNotDetermined:
            "Health permissions are not set up yet. Tap Continue and review the requested read permissions."
        case let .unsupportedType(type):
            "HealthKit type is not available: \(type.label)."
        case let .statisticsUnavailable(type):
            "HealthKit statistics are not available: \(type.label)."
        case .missingAnchor:
            "HealthKit did not return an incremental sync anchor."
        }
    }

    static func map(_ error: Error) -> Error {
        guard let healthKitError = error as? HKError else { return error }
        if healthKitError.code == .errorAuthorizationNotDetermined {
            return HealthKitManagerError.authorizationNotDetermined
        }
        return error
    }
}

final class HealthKitManager {
    private let healthStore: HKHealthStore
    private var observerQueries: [HKObserverQuery] = []

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestReadPermissions(for selectedTypes: Set<HealthDataType>) async throws {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }
        let readTypes = HealthKitTypeRegistry.readTypes(for: selectedTypes)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitManagerError.healthDataUnavailable)
                }
            }
        }
    }

    func fetchSamples(types: Set<HealthDataType>, start: Date, end: Date) async throws -> HealthKitFetchResult {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }
        var result = HealthKitFetchResult.empty
        for type in types {
            guard HealthKitTypeRegistry.objectType(for: type) != nil else { continue }
            switch type {
            case .sleepAnalysis:
                result.sleepSamples += try await sleepSamples(start: start, end: end)
            case .workouts:
                result.workoutSamples += try await workoutSamples(start: start, end: end)
            default:
                if type.kind == .category {
                    result.categorySamples += try await categorySamples(for: type, start: start, end: end)
                } else {
                    result.quantitySamples += try await quantitySamples(for: type, start: start, end: end)
                }
            }
        }
        return result
    }

    func fetchBackfillSamples(types: Set<HealthDataType>, start: Date, end: Date) async throws -> HealthKitFetchResult {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }
        var result = HealthKitFetchResult.empty
        for type in types {
            guard HealthKitTypeRegistry.objectType(for: type) != nil else { continue }
            switch type {
            case .sleepAnalysis:
                result.sleepSamples += try await sleepSamples(start: start, end: end)
            case .workouts:
                result.workoutSamples += try await workoutSamples(start: start, end: end)
            default:
                if type.kind == .category {
                    result.categorySamples += try await categorySamples(for: type, start: start, end: end)
                } else if let strategy = backfillAggregationStrategy(for: type) {
                    result.quantitySamples += try await aggregatedQuantitySamples(
                        for: type,
                        start: start,
                        end: end,
                        strategy: strategy
                    )
                } else {
                    result.quantitySamples += try await quantitySamples(for: type, start: start, end: end)
                }
            }
        }
        return result
    }

    func fetchIncremental(types: Set<HealthDataType>, anchors: [HealthDataType: String]) async throws -> HealthKitIncrementalResult {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }
        var fetchResult = HealthKitFetchResult.empty
        var updatedAnchors: [HealthDataType: String] = [:]

        for type in types {
            guard let sampleType = HealthKitTypeRegistry.sampleType(for: type) else {
                continue
            }
            let anchor = try anchors[type].flatMap(decodeAnchor)
            let (samples, newAnchor) = try await anchoredSamples(type: sampleType, anchor: anchor)
            guard let newAnchor else {
                throw HealthKitManagerError.missingAnchor
            }
            updatedAnchors[type] = try encodeAnchor(newAnchor)
            let converted = try convert(samples: samples, as: type)
            fetchResult.quantitySamples += converted.quantitySamples
            fetchResult.categorySamples += converted.categorySamples
            fetchResult.sleepSamples += converted.sleepSamples
            fetchResult.workoutSamples += converted.workoutSamples
        }

        return HealthKitIncrementalResult(fetchResult: fetchResult, anchors: updatedAnchors)
    }

    func startObserverQueries(types: Set<HealthDataType>, onUpdate: @escaping @Sendable (HealthDataType) -> Void) throws {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()

        for type in types {
            guard let sampleType = HealthKitTypeRegistry.sampleType(for: type) else { continue }
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                if error == nil {
                    onUpdate(type)
                }
                completionHandler()
            }
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { _, _ in }
            observerQueries.append(query)
        }
    }

    private func quantitySamples(for type: HealthDataType, start: Date, end: Date) async throws -> [HealthQuantitySampleDTO] {
        guard
            let quantityType = HealthKitTypeRegistry.sampleType(for: type) as? HKQuantityType,
            let unit = HealthKitTypeRegistry.preferredQuantityUnit(for: type)
        else {
            throw HealthKitManagerError.unsupportedType(type)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        let samples = try await samples(sampleType: quantityType, predicate: predicate)
        return samples.compactMap { sample in
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthQuantitySampleDTO(
                uuid: quantitySample.uuid,
                type: type,
                value: quantitySample.quantity.doubleValue(for: unit.hkUnit),
                unit: unit.sampleUnit,
                startAt: quantitySample.startDate,
                endAt: quantitySample.endDate,
                sourceName: quantitySample.sourceRevision.source.name,
                sourceBundleIdentifier: quantitySample.sourceRevision.source.bundleIdentifier,
                metadata: metadata(from: quantitySample)
            )
        }
    }

    private func aggregatedQuantitySamples(
        for type: HealthDataType,
        start: Date,
        end: Date,
        strategy: BackfillQuantityAggregationStrategy
    ) async throws -> [HealthQuantitySampleDTO] {
        guard
            let quantityType = HealthKitTypeRegistry.sampleType(for: type) as? HKQuantityType,
            let unit = HealthKitTypeRegistry.preferredQuantityUnit(for: type)
        else {
            throw HealthKitManagerError.unsupportedType(type)
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: start)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        let collection = try await statisticsCollection(
            for: type,
            quantityType: quantityType,
            predicate: predicate,
            options: strategy.statisticsOptions,
            anchorDate: dayStart,
            intervalComponents: DateComponents(day: 1)
        )

        var samples: [HealthQuantitySampleDTO] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            guard let value = strategy.value(from: statistics, unit: unit.hkUnit) else { return }
            let aggregateStart = max(statistics.startDate, start)
            let aggregateEnd = min(statistics.endDate, end)
            let dayKey = Self.localDayKey(for: statistics.startDate, calendar: calendar)
            let metadata = [
                "aggregation": strategy.rawValue,
                "aggregation_period": "day",
                "aggregation_start": Self.isoString(from: aggregateStart),
                "aggregation_end": Self.isoString(from: aggregateEnd)
            ]

            samples.append(
                HealthQuantitySampleDTO(
                    uuid: UUID(),
                    type: type,
                    value: value,
                    unit: unit.sampleUnit,
                    startAt: aggregateStart,
                    endAt: aggregateEnd,
                    sourceName: "Apple Health",
                    sourceBundleIdentifier: nil,
                    metadata: metadata,
                    stableIDOverride: "healthkit:aggregate:\(type.rawValue):\(dayKey)"
                )
            )
        }
        return samples
    }

    private func sleepSamples(start: Date, end: Date) async throws -> [HealthSleepSampleDTO] {
        guard let categoryType = HealthKitTypeRegistry.sampleType(for: .sleepAnalysis) as? HKCategoryType else {
            throw HealthKitManagerError.unsupportedType(.sleepAnalysis)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        let samples = try await samples(sampleType: categoryType, predicate: predicate)
        return samples.compactMap { sample in
            guard let categorySample = sample as? HKCategorySample else { return nil }
            return HealthSleepSampleDTO(
                uuid: categorySample.uuid,
                startAt: categorySample.startDate,
                endAt: categorySample.endDate,
                sourceName: categorySample.sourceRevision.source.name,
                sourceBundleIdentifier: categorySample.sourceRevision.source.bundleIdentifier,
                stage: sleepStageName(categorySample.value),
                metadata: metadata(from: categorySample)
            )
        }
    }

    private func categorySamples(for type: HealthDataType, start: Date, end: Date) async throws -> [HealthCategorySampleDTO] {
        guard let categoryType = HealthKitTypeRegistry.sampleType(for: type) as? HKCategoryType else {
            throw HealthKitManagerError.unsupportedType(type)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        let samples = try await samples(sampleType: categoryType, predicate: predicate)
        return samples.compactMap { sample in
            guard let categorySample = sample as? HKCategorySample else { return nil }
            return HealthCategorySampleDTO(
                uuid: categorySample.uuid,
                type: type,
                value: categorySample.value,
                valueLabel: categoryValueLabel(for: type, value: categorySample.value),
                startAt: categorySample.startDate,
                endAt: categorySample.endDate,
                sourceName: categorySample.sourceRevision.source.name,
                sourceBundleIdentifier: categorySample.sourceRevision.source.bundleIdentifier,
                metadata: metadata(from: categorySample)
            )
        }
    }

    private func workoutSamples(start: Date, end: Date) async throws -> [HealthWorkoutSampleDTO] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        let samples = try await samples(sampleType: workoutType, predicate: predicate)
        return samples.compactMap { sample in
            guard let workout = sample as? HKWorkout else { return nil }
            let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
            return HealthWorkoutSampleDTO(
                uuid: workout.uuid,
                activityType: activityName(workout.workoutActivityType),
                startAt: workout.startDate,
                endAt: workout.endDate,
                durationSeconds: workout.duration,
                totalEnergyKcal: energy,
                activeEnergyKcal: energy,
                distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                sourceName: workout.sourceRevision.source.name,
                sourceBundleIdentifier: workout.sourceRevision.source.bundleIdentifier,
                metadata: metadata(from: workout)
            )
        }
    }

    private func samples(sampleType: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitManagerError.map(error))
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private func anchoredSamples(type: HKSampleType, anchor: HKQueryAnchor?) async throws -> ([HKSample], HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    continuation.resume(throwing: HealthKitManagerError.map(error))
                } else {
                    continuation.resume(returning: (samples ?? [], newAnchor))
                }
            }
            healthStore.execute(query)
        }
    }

    private func statisticsCollection(
        for type: HealthDataType,
        quantityType: HKQuantityType,
        predicate: NSPredicate?,
        options: HKStatisticsOptions,
        anchorDate: Date,
        intervalComponents: DateComponents
    ) async throws -> HKStatisticsCollection {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: intervalComponents
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: HealthKitManagerError.map(error))
                } else if let collection {
                    continuation.resume(returning: collection)
                } else {
                    continuation.resume(throwing: HealthKitManagerError.statisticsUnavailable(type))
                }
            }
            healthStore.execute(query)
        }
    }

    private func convert(samples: [HKSample], as type: HealthDataType) throws -> HealthKitFetchResult {
        switch type {
        case .sleepAnalysis:
            let sleep = samples.compactMap { sample -> HealthSleepSampleDTO? in
                guard let categorySample = sample as? HKCategorySample else { return nil }
                return HealthSleepSampleDTO(
                    uuid: categorySample.uuid,
                    startAt: categorySample.startDate,
                    endAt: categorySample.endDate,
                    sourceName: categorySample.sourceRevision.source.name,
                    sourceBundleIdentifier: categorySample.sourceRevision.source.bundleIdentifier,
                    stage: sleepStageName(categorySample.value),
                    metadata: metadata(from: categorySample)
                )
            }
            return HealthKitFetchResult(quantitySamples: [], categorySamples: [], sleepSamples: sleep, workoutSamples: [])
        case .workouts:
            let workouts = samples.compactMap { sample -> HealthWorkoutSampleDTO? in
                guard let workout = sample as? HKWorkout else { return nil }
                let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                return HealthWorkoutSampleDTO(
                    uuid: workout.uuid,
                    activityType: activityName(workout.workoutActivityType),
                    startAt: workout.startDate,
                    endAt: workout.endDate,
                    durationSeconds: workout.duration,
                    totalEnergyKcal: energy,
                    activeEnergyKcal: energy,
                    distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                    sourceName: workout.sourceRevision.source.name,
                    sourceBundleIdentifier: workout.sourceRevision.source.bundleIdentifier,
                    metadata: metadata(from: workout)
                )
            }
            return HealthKitFetchResult(quantitySamples: [], categorySamples: [], sleepSamples: [], workoutSamples: workouts)
        default:
            if type.kind == .category {
                let categories = samples.compactMap { sample -> HealthCategorySampleDTO? in
                    guard let categorySample = sample as? HKCategorySample else { return nil }
                    return HealthCategorySampleDTO(
                        uuid: categorySample.uuid,
                        type: type,
                        value: categorySample.value,
                        valueLabel: categoryValueLabel(for: type, value: categorySample.value),
                        startAt: categorySample.startDate,
                        endAt: categorySample.endDate,
                        sourceName: categorySample.sourceRevision.source.name,
                        sourceBundleIdentifier: categorySample.sourceRevision.source.bundleIdentifier,
                        metadata: metadata(from: categorySample)
                    )
                }
                return HealthKitFetchResult(quantitySamples: [], categorySamples: categories, sleepSamples: [], workoutSamples: [])
            }

            guard let unit = HealthKitTypeRegistry.preferredQuantityUnit(for: type) else {
                throw HealthKitManagerError.unsupportedType(type)
            }
            let quantities = samples.compactMap { sample -> HealthQuantitySampleDTO? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HealthQuantitySampleDTO(
                    uuid: quantitySample.uuid,
                    type: type,
                    value: quantitySample.quantity.doubleValue(for: unit.hkUnit),
                    unit: unit.sampleUnit,
                    startAt: quantitySample.startDate,
                    endAt: quantitySample.endDate,
                    sourceName: quantitySample.sourceRevision.source.name,
                    sourceBundleIdentifier: quantitySample.sourceRevision.source.bundleIdentifier,
                    metadata: metadata(from: quantitySample)
                )
            }
            return HealthKitFetchResult(quantitySamples: quantities, categorySamples: [], sleepSamples: [], workoutSamples: [])
        }
    }

    private func encodeAnchor(_ anchor: HKQueryAnchor) throws -> String {
        let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        return data.base64EncodedString()
    }

    private func decodeAnchor(_ value: String) throws -> HKQueryAnchor? {
        guard let data = Data(base64Encoded: value) else { return nil }
        return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func metadata(from sample: HKSample) -> [String: String] {
        sample.metadata?.reduce(into: [:]) { result, item in
            result[item.key] = String(describing: item.value)
        } ?? [:]
    }

    private func backfillAggregationStrategy(for type: HealthDataType) -> BackfillQuantityAggregationStrategy? {
        guard type.kind == .quantity else { return nil }
        switch type {
        case .activeEnergy, .appleExerciseTime, .appleMoveTime, .appleStandTime, .basalEnergy,
             .distanceCrossCountrySkiing, .distanceCycling, .distanceDownhillSnowSports, .distancePaddleSports,
             .distanceRowing, .distanceSkatingSports, .distanceSwimming, .distanceWalkingRunning,
             .distanceWheelchair, .flightsClimbed, .nikeFuel, .pushCount, .stepCount, .swimmingStrokeCount,
             .dietaryBiotin, .dietaryCaffeine, .dietaryCalcium, .dietaryCarbohydrates, .dietaryChloride,
             .dietaryCholesterol, .dietaryChromium, .dietaryCopper, .dietaryEnergy, .dietaryFatMonounsaturated,
             .dietaryFatPolyunsaturated, .dietaryFatSaturated, .dietaryFat, .dietaryFiber, .dietaryFolate,
             .dietaryIodine, .dietaryIron, .dietaryMagnesium, .dietaryManganese, .dietaryMolybdenum,
             .dietaryNiacin, .dietaryPantothenicAcid, .dietaryPhosphorus, .dietaryPotassium, .dietaryProtein,
             .dietaryRiboflavin, .dietarySelenium, .dietarySodium, .dietarySugar, .dietaryThiamin,
             .dietaryVitaminA, .dietaryVitaminB12, .dietaryVitaminB6, .dietaryVitaminC, .dietaryVitaminD,
             .dietaryVitaminE, .dietaryVitaminK, .water, .dietaryZinc, .insulinDelivery,
             .numberOfAlcoholicBeverages, .numberOfTimesFallen, .timeInDaylight, .inhalerUsage:
            return .dailySum
        default:
            return .dailyAverage
        }
    }

    private func categoryValueLabel(for type: HealthDataType, value: Int) -> String {
        switch type {
        case .sleepAnalysis:
            sleepStageName(value)
        case .mindfulSession, .handwashingEvent, .toothbrushingEvent, .highHeartRateEvent,
             .irregularHeartRhythmEvent, .lowHeartRateEvent, .intermenstrualBleeding, .lactation,
             .pregnancy, .sexualActivity, .sleepApneaEvent:
            value == 0 ? "not_applicable" : String(value)
        default:
            String(value)
        }
    }

    private static func localDayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func isoString(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func sleepStageName(_ value: Int) -> String {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed:
            "in_bed"
        case .asleepUnspecified:
            "asleep_unspecified"
        case .asleepCore:
            "asleep_core"
        case .asleepDeep:
            "asleep_deep"
        case .asleepREM:
            "asleep_rem"
        case .awake:
            "awake"
        default:
            "unknown"
        }
    }

    private func activityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            "running"
        case .walking:
            "walking"
        case .cycling:
            "cycling"
        case .traditionalStrengthTraining:
            "traditionalStrengthTraining"
        case .functionalStrengthTraining:
            "functionalStrengthTraining"
        default:
            "other"
        }
    }
}
