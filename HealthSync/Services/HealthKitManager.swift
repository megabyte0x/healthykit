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
    let deletions: [HealthRecordDeletion]
}

enum BackfillQuantityAggregationStrategy: String {
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

enum HealthKitReadErrorPolicy {
    static func shouldSkipType(_ error: Error) -> Bool {
        if let managerError = error as? HealthKitManagerError,
           case .authorizationNotDetermined = managerError {
            return true
        }
        if let healthKitError = error as? HKError,
           healthKitError.code == .errorAuthorizationNotDetermined {
            return true
        }
        return false
    }
}

protocol HealthKitSyncReading {
    func fetchSamples(types: Set<HealthDataType>, start: Date, end: Date) async throws -> HealthKitFetchResult
    func fetchIncremental(types: Set<HealthDataType>, anchors: [HealthDataType: String]) async throws -> HealthKitIncrementalResult
}

final class HealthKitManager: HealthKitSyncReading {
    struct BackfillPage {
        let samples: [HKSample]
        let deletedCount: Int
        let anchor: HKQueryAnchor?
    }
    typealias BackfillPageReader = (HKSampleType, NSPredicate, HKQueryAnchor?, Int) async throws -> BackfillPage
    typealias SampleReader = (HKSampleType, NSPredicate?) async throws -> [HKSample]
    typealias WorkoutStatisticsReader = (HKWorkout, HKQuantityType, HKStatisticsOptions) -> HKQuantity?

    private let healthStore: HKHealthStore
    private let sampleReader: SampleReader?
    private let backfillPageReader: BackfillPageReader?
    private let workoutStatisticsReader: WorkoutStatisticsReader?
    private var observerQueries: [HKObserverQuery] = []
    private var observerSampleTypes: [HKSampleType] = []

    init(
        healthStore: HKHealthStore = HKHealthStore(), sampleReader: SampleReader? = nil,
        workoutStatisticsReader: WorkoutStatisticsReader? = nil,
        backfillPageReader: BackfillPageReader? = nil
    ) {
        self.healthStore = healthStore
        self.sampleReader = sampleReader
        self.backfillPageReader = backfillPageReader
        self.workoutStatisticsReader = workoutStatisticsReader
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
            do {
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
            } catch {
                guard HealthKitReadErrorPolicy.shouldSkipType(error) else { throw error }
            }
        }
        return result
    }

    // The consumer must finish persisting/uploading a page before the next read.
    // Anchors are local to this range, not the ordinary incremental-sync cursor.
    func forEachBackfillBatch(
        types: Set<HealthDataType>, start: Date, end: Date, mode: BackfillDataMode,
        consume: (HealthKitFetchResult) async throws -> Void
    ) async throws {
        guard isHealthDataAvailable else { throw HealthKitManagerError.healthDataUnavailable }
        for type in types.sorted(by: { $0.rawValue < $1.rawValue }) {
            try Task.checkCancellation()
            guard let sampleType = HealthKitTypeRegistry.sampleType(for: type) else { continue }
            if mode == .rawSamples && (type == .oxygenSaturation || type == .hrvSDNN) {
                let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
                var anchor: HKQueryAnchor?
                let limit = 100
                while true {
                    try Task.checkCancellation()
                    let page: BackfillPage
                    do {
                        page = try await backfillPage(type: sampleType, predicate: predicate, anchor: anchor, limit: limit)
                    } catch {
                        guard HealthKitReadErrorPolicy.shouldSkipType(error) else { throw error }
                        break
                    }
                    if !page.samples.isEmpty {
                        // Consumer errors must propagate; never treat an upload failure
                        // as a skippable HealthKit permission error.
                        try await consume(convert(samples: page.samples, as: type))
                    }
                    if page.samples.count + page.deletedCount < limit { break }
                    guard let nextAnchor = page.anchor, !nextAnchor.isEqual(anchor) else {
                        throw HealthKitManagerError.missingAnchor
                    }
                    anchor = nextAnchor
                }
                continue
            }

            let result: HealthKitFetchResult
            do {
                var batch = HealthKitFetchResult.empty
                // Keep summary-mode predicates unchanged; raw-mode boundaries select
                // records by start time, including workouts/categories that end later.
                let options: HKQueryOptions = mode == .rawSamples ? [.strictStartDate] : [.strictStartDate, .strictEndDate]
                switch type {
                case .sleepAnalysis:
                    batch.sleepSamples = try await sleepSamples(start: start, end: end)
                case .workouts:
                    batch.workoutSamples = try await workoutSamples(start: start, end: end, options: options)
                default:
                    if type.kind == .category {
                        batch.categorySamples = try await categorySamples(for: type, start: start, end: end, options: options)
                    } else if let strategy = backfillAggregationStrategy(for: type, mode: mode) {
                        batch.quantitySamples = try await aggregatedQuantitySamples(for: type, start: start, end: end, strategy: strategy)
                    }
                }
                result = batch
            } catch {
                guard HealthKitReadErrorPolicy.shouldSkipType(error) else { throw error }
                continue
            }
            if !result.isEmpty { try await consume(result) }
        }
    }

    private func backfillPage(type: HKSampleType, predicate: NSPredicate, anchor: HKQueryAnchor?, limit: Int) async throws -> BackfillPage {
        if let backfillPageReader { return try await backfillPageReader(type, predicate, anchor, limit) }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: anchor, limit: limit) { _, samples, deleted, nextAnchor, error in
                if let error { continuation.resume(throwing: HealthKitManagerError.map(error)) }
                else { continuation.resume(returning: BackfillPage(samples: samples ?? [], deletedCount: deleted?.count ?? 0, anchor: nextAnchor)) }
            }
            healthStore.execute(query)
        }
    }

    func fetchIncremental(types: Set<HealthDataType>, anchors: [HealthDataType: String]) async throws -> HealthKitIncrementalResult {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }
        var fetchResult = HealthKitFetchResult.empty
        var updatedAnchors: [HealthDataType: String] = [:]
        var deletions: Set<HealthRecordDeletion> = []

        for type in types {
            guard let sampleType = HealthKitTypeRegistry.sampleType(for: type) else {
                continue
            }
            let anchor = try anchors[type].flatMap(decodeAnchor)
            let samples: [HKSample]
            let deletedObjects: [HKDeletedObject]
            let newAnchor: HKQueryAnchor?
            do {
                (samples, deletedObjects, newAnchor) = try await anchoredSamples(type: sampleType, anchor: anchor)
            } catch {
                guard HealthKitReadErrorPolicy.shouldSkipType(error) else { throw error }
                continue
            }
            guard let newAnchor else {
                throw HealthKitManagerError.missingAnchor
            }
            updatedAnchors[type] = try encodeAnchor(newAnchor)
            let converted = try await convert(samples: samples, as: type)
            fetchResult.quantitySamples += converted.quantitySamples
            fetchResult.categorySamples += converted.categorySamples
            fetchResult.sleepSamples += converted.sleepSamples
            fetchResult.workoutSamples += converted.workoutSamples
            deletions.formUnion(deletedObjects.map { HealthRecordDeletion.healthKit(uuid: $0.uuid, type: type) })
        }

        return HealthKitIncrementalResult(
            fetchResult: fetchResult,
            anchors: updatedAnchors,
            deletions: deletions.sorted { ($0.kind.rawValue, $0.id) < ($1.kind.rawValue, $1.id) }
        )
    }

    func startObserverQueries(
        types: Set<HealthDataType>,
        frequency: SyncFrequency,
        onUpdate: @escaping @Sendable (HealthDataType) async -> Void
    ) async throws {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }
        await stopObserverQueries(disabling: Set(HealthDataType.allCases))
        guard let updateFrequency = healthKitUpdateFrequency(for: frequency) else { return }

        for type in types {
            guard let sampleType = HealthKitTypeRegistry.sampleType(for: type) else { continue }
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }
                Task {
                    await onUpdate(type)
                    completionHandler()
                }
            }
            healthStore.execute(query)
            do {
                try await enableBackgroundDelivery(for: sampleType, frequency: updateFrequency)
                observerQueries.append(query)
                observerSampleTypes.append(sampleType)
            } catch {
                healthStore.stop(query)
                if HealthKitReadErrorPolicy.shouldSkipType(error) {
                    continue
                }
                await stopObserverQueries(disabling: types)
                throw error
            }
        }
    }

    func stopObserverQueries(disabling types: Set<HealthDataType> = []) async {
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
        var backgroundTypes = observerSampleTypes
        for type in types {
            guard let sampleType = HealthKitTypeRegistry.sampleType(for: type) else { continue }
            if !backgroundTypes.contains(sampleType) {
                backgroundTypes.append(sampleType)
            }
        }
        for sampleType in backgroundTypes {
            await disableBackgroundDelivery(for: sampleType)
        }
        observerSampleTypes.removeAll()
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

    static func sleepPredicate(start: Date, end: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    }

    private func sleepSamples(start: Date, end: Date) async throws -> [HealthSleepSampleDTO] {
        guard let categoryType = HealthKitTypeRegistry.sampleType(for: .sleepAnalysis) as? HKCategoryType else {
            throw HealthKitManagerError.unsupportedType(.sleepAnalysis)
        }
        let predicate = Self.sleepPredicate(start: start, end: end)
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

    private func categorySamples(for type: HealthDataType, start: Date, end: Date, options: HKQueryOptions = [.strictStartDate, .strictEndDate]) async throws -> [HealthCategorySampleDTO] {
        guard let categoryType = HealthKitTypeRegistry.sampleType(for: type) as? HKCategoryType else {
            throw HealthKitManagerError.unsupportedType(type)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: options)
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

    private func workoutSamples(start: Date, end: Date, options: HKQueryOptions = [.strictStartDate, .strictEndDate]) async throws -> [HealthWorkoutSampleDTO] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: options)
        let samples = try await samples(sampleType: workoutType, predicate: predicate)
        return try await convert(samples: samples, as: .workouts).workoutSamples
    }

    private func samples(sampleType: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample] {
        if let sampleReader { return try await sampleReader(sampleType, predicate) }
        return try await withCheckedThrowingContinuation { continuation in
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

    private func anchoredSamples(
        type: HKSampleType,
        anchor: HKQueryAnchor?
    ) async throws -> ([HKSample], [HKDeletedObject], HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deletedObjects, newAnchor, error in
                if let error {
                    continuation.resume(throwing: HealthKitManagerError.map(error))
                } else {
                    continuation.resume(returning: (samples ?? [], deletedObjects ?? [], newAnchor))
                }
            }
            healthStore.execute(query)
        }
    }

    private func healthKitUpdateFrequency(for frequency: SyncFrequency) -> HKUpdateFrequency? {
        switch frequency {
        case .manualOnly:
            nil
        case .hourlyBestEffort:
            .hourly
        case .dailyBestEffort:
            .daily
        }
    }

    private func enableBackgroundDelivery(
        for sampleType: HKSampleType,
        frequency: HKUpdateFrequency
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: frequency) { success, error in
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

    private func disableBackgroundDelivery(for sampleType: HKSampleType) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            healthStore.disableBackgroundDelivery(for: sampleType) { _, _ in
                continuation.resume()
            }
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

    func convert(samples: [HKSample], as type: HealthDataType) async throws -> HealthKitFetchResult {
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
            var workouts: [HealthWorkoutSampleDTO] = []
            for case let workout as HKWorkout in samples {
                try Task.checkCancellation()
                let effortMetadata = try await workoutEffortMetadata(for: workout)
                workouts.append(workoutSample(from: workout, effortMetadata: effortMetadata))
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

    func backfillAggregationStrategy(for type: HealthDataType, mode: BackfillDataMode) -> BackfillQuantityAggregationStrategy? {
        guard type.kind == .quantity else { return nil }
        // Only these discrete measurements bypass aggregation. In particular,
        // cumulative types must retain HealthKit's device-overlap handling.
        if mode == .rawSamples && (type == .oxygenSaturation || type == .hrvSDNN) { return nil }
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

    private func workoutEffortMetadata(for workout: HKWorkout) async throws -> [String: String] {
        guard #available(iOS 18.0, *) else { return [:] }
        var result: [String: String] = [:]
        let predicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
        for type: HealthDataType in [.workoutEffortScore, .estimatedWorkoutEffortScore] {
            guard let quantityType = HealthKitTypeRegistry.sampleType(for: type) as? HKQuantityType else { continue }
            do {
                try Task.checkCancellation()
                let effortSamples = try await samples(sampleType: quantityType, predicate: predicate)
                let latest = effortSamples.compactMap { $0 as? HKQuantitySample }.max {
                    ($0.endDate, $0.startDate, $0.uuid.uuidString) < ($1.endDate, $1.startDate, $1.uuid.uuidString)
                }
                result[type.rawValue] = latest.map { String($0.quantity.doubleValue(for: .appleEffortScore())) }
            } catch {
                if HealthKitReadErrorPolicy.shouldSkipType(error) { continue }
                if let error = error as? HKError, error.code == .errorAuthorizationDenied { continue }
                throw error
            }
        }
        return result
    }

    func workoutSample(from workout: HKWorkout, effortMetadata: [String: String] = [:]) -> HealthWorkoutSampleDTO {
        workoutSample(from: workout, effortMetadata: effortMetadata) { type, option in
            guard let quantityType = HealthKitTypeRegistry.sampleType(for: type) as? HKQuantityType,
                  let unit = HealthKitTypeRegistry.preferredQuantityUnit(for: type)?.hkUnit else { return nil }
            let quantity: HKQuantity?
            if let workoutStatisticsReader {
                quantity = workoutStatisticsReader(workout, quantityType, option)
            } else {
                guard let statistics = workout.statistics(for: quantityType) else { return nil }
                switch option {
                case .cumulativeSum: quantity = statistics.sumQuantity()
                case .discreteAverage: quantity = statistics.averageQuantity()
                case .discreteMax: quantity = statistics.maximumQuantity()
                default: quantity = nil
                }
            }
            return quantity?.doubleValue(for: unit)
        }
    }

    func workoutSample(
        from workout: HKWorkout,
        effortMetadata: [String: String] = [:],
        quantityValue: (HealthDataType, HKStatisticsOptions) -> Double?
    ) -> HealthWorkoutSampleDTO {
        var workoutMetadata = metadata(from: workout)
        workoutMetadata["hk_workout_activity_type"] = String(workout.workoutActivityType.rawValue)
        let activeEnergy = quantityValue(.activeEnergy, .cumulativeSum)
            ?? workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let basalEnergy = quantityValue(.basalEnergy, .cumulativeSum)
        let totalEnergy = activeEnergy.flatMap { active in basalEnergy.map { active + $0 } }
        workoutMetadata["average_heart_rate_bpm"] = quantityValue(.heartRate, .discreteAverage).map { String($0) }
        workoutMetadata["max_heart_rate_bpm"] = quantityValue(.heartRate, .discreteMax).map { String($0) }
        let metsUnit = HKUnit(from: "kcal/kg*hr")
        let averageMETs = (workout.metadata?[HKMetadataKeyAverageMETs] as? HKQuantity)
            .flatMap { $0.is(compatibleWith: metsUnit) ? $0.doubleValue(for: metsUnit) : nil }
            ?? quantityValue(.physicalEffort, .discreteAverage)
        workoutMetadata["average_mets"] = averageMETs.map { String($0) }
        for type: HealthDataType in [.workoutEffortScore, .estimatedWorkoutEffortScore] {
            workoutMetadata[type.rawValue] = effortMetadata[type.rawValue]
                ?? quantityValue(type, .discreteAverage).map { String($0) }
        }
        var distance = workout.totalDistance?.doubleValue(for: .meter())
        if distance == nil {
            let distances: [HealthDataType] = [
                .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceWheelchair,
                .distanceCrossCountrySkiing, .distanceDownhillSnowSports, .distancePaddleSports,
                .distanceRowing, .distanceSkatingSports
            ]
            let values = distances.compactMap { quantityValue($0, .cumulativeSum) }
            if !values.isEmpty { distance = values.reduce(0, +) }
        }
        return HealthWorkoutSampleDTO(
            uuid: workout.uuid,
            activityType: activityName(workout.workoutActivityType),
            startAt: workout.startDate,
            endAt: workout.endDate,
            durationSeconds: workout.duration,
            totalEnergyKcal: totalEnergy,
            activeEnergyKcal: activeEnergy,
            distanceMeters: distance,
            sourceName: workout.sourceRevision.source.name,
            sourceBundleIdentifier: workout.sourceRevision.source.bundleIdentifier,
            metadata: workoutMetadata
        )
    }

    func activityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .americanFootball: "americanFootball"
        case .archery: "archery"
        case .australianFootball: "australianFootball"
        case .badminton: "badminton"
        case .baseball: "baseball"
        case .basketball: "basketball"
        case .bowling: "bowling"
        case .boxing: "boxing"
        case .climbing: "climbing"
        case .cricket: "cricket"
        case .crossTraining: "crossTraining"
        case .curling: "curling"
        case .cycling: "cycling"
        case .dance: "dance"
        case .danceInspiredTraining: "danceInspiredTraining"
        case .elliptical: "elliptical"
        case .equestrianSports: "equestrianSports"
        case .fencing: "fencing"
        case .fishing: "fishing"
        case .functionalStrengthTraining: "functionalStrengthTraining"
        case .golf: "golf"
        case .gymnastics: "gymnastics"
        case .handball: "handball"
        case .hiking: "hiking"
        case .hockey: "hockey"
        case .hunting: "hunting"
        case .lacrosse: "lacrosse"
        case .martialArts: "martialArts"
        case .mindAndBody: "mindAndBody"
        case .mixedMetabolicCardioTraining: "mixedMetabolicCardioTraining"
        case .paddleSports: "paddleSports"
        case .play: "play"
        case .preparationAndRecovery: "preparationAndRecovery"
        case .racquetball: "racquetball"
        case .rowing: "rowing"
        case .rugby: "rugby"
        case .running: "running"
        case .sailing: "sailing"
        case .skatingSports: "skatingSports"
        case .snowSports: "snowSports"
        case .soccer: "soccer"
        case .softball: "softball"
        case .squash: "squash"
        case .stairClimbing: "stairClimbing"
        case .surfingSports: "surfingSports"
        case .swimming: "swimming"
        case .tableTennis: "tableTennis"
        case .tennis: "tennis"
        case .trackAndField: "trackAndField"
        case .traditionalStrengthTraining: "traditionalStrengthTraining"
        case .volleyball: "volleyball"
        case .walking: "walking"
        case .waterFitness: "waterFitness"
        case .waterPolo: "waterPolo"
        case .waterSports: "waterSports"
        case .wrestling: "wrestling"
        case .yoga: "yoga"
        case .barre: "barre"
        case .coreTraining: "coreTraining"
        case .crossCountrySkiing: "crossCountrySkiing"
        case .downhillSkiing: "downhillSkiing"
        case .flexibility: "flexibility"
        case .highIntensityIntervalTraining: "highIntensityIntervalTraining"
        case .jumpRope: "jumpRope"
        case .kickboxing: "kickboxing"
        case .pilates: "pilates"
        case .snowboarding: "snowboarding"
        case .stairs: "stairs"
        case .stepTraining: "stepTraining"
        case .wheelchairWalkPace: "wheelchairWalkPace"
        case .wheelchairRunPace: "wheelchairRunPace"
        case .taiChi: "taiChi"
        case .mixedCardio: "mixedCardio"
        case .handCycling: "handCycling"
        case .discSports: "discSports"
        case .fitnessGaming: "fitnessGaming"
        case .cardioDance: "cardioDance"
        case .socialDance: "socialDance"
        case .pickleball: "pickleball"
        case .cooldown: "cooldown"
        case .swimBikeRun: "swimBikeRun"
        case .transition: "transition"
        case .underwaterDiving: "underwaterDiving"
        case .other: "other"
        default: "hk_\(type.rawValue)"
        }
    }
}
