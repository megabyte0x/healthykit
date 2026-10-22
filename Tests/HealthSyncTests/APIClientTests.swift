import XCTest
import HealthKit
@testable import HealthSync

final class PopulatedWorkoutExportTests: XCTestCase {
    func testEllipticalWithAllMetricsSurvivesQueueAndHTTPEncoding() async throws {
        try await assertPopulatedExport(
            activity: .elliptical, name: "elliptical", rawType: "16",
            distanceType: .distanceWalkingRunning, metadataMETs: 6.25, expectedMETs: 6.25
        )
    }

    func testRowingWithAllMetricsSurvivesQueueAndHTTPEncoding() async throws {
        guard #available(iOS 18.0, *) else { throw XCTSkip("Rowing distance requires iOS 18") }
        try await assertPopulatedExport(
            activity: .rowing, name: "rowing", rawType: "35",
            distanceType: .distanceRowing, metadataMETs: nil, expectedMETs: 4.5
        )
    }

    private func assertPopulatedExport(
        activity: HKWorkoutActivityType, name: String, rawType: String,
        distanceType: HKQuantityTypeIdentifier, metadataMETs: Double?, expectedMETs: Double
    ) async throws {
        guard #available(iOS 18.0, *) else { throw XCTSkip("Populated effort fixtures require iOS 18") }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(2100)
        var sourceMetadata: [String: Any] = ["user_tag": "fixture"]
        if let metadataMETs {
            sourceMetadata[HKMetadataKeyAverageMETs] = HKQuantity(unit: HKUnit(from: "kcal/kg*hr"), doubleValue: metadataMETs)
        }
        let workout = HKWorkout(
            activityType: activity, start: start, end: end, duration: 2100,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 12),
            totalDistance: nil, metadata: sourceMetadata
        )
        let userEffort = HKQuantityType(.workoutEffortScore)
        let estimatedEffort = HKQuantityType(.estimatedWorkoutEffortScore)
        let effortSamples = [
            HKQuantitySample(type: userEffort, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: 4), start: start, end: start),
            HKQuantitySample(type: userEffort, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: 7), start: start, end: end),
            HKQuantitySample(type: estimatedEffort, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: 6), start: start, end: end)
        ]
        let manager = HealthKitManager(
            sampleReader: { type, predicate in
                XCTAssertEqual(predicate, HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil))
                return effortSamples.filter { $0.sampleType == type }.reversed()
            },
            workoutStatisticsReader: { readWorkout, type, option in
                XCTAssertEqual(readWorkout.uuid, workout.uuid)
                switch (type.identifier, option) {
                case (HKQuantityTypeIdentifier.activeEnergyBurned.rawValue, .cumulativeSum):
                    return HKQuantity(unit: HKUnit(from: "kJ"), doubleValue: 1004.16)
                case (HKQuantityTypeIdentifier.basalEnergyBurned.rawValue, .cumulativeSum):
                    return HKQuantity(unit: .kilocalorie(), doubleValue: 35)
                case (HKQuantityTypeIdentifier.heartRate.rawValue, .discreteAverage):
                    return HKQuantity(unit: .hertz(), doubleValue: 2)
                case (HKQuantityTypeIdentifier.heartRate.rawValue, .discreteMax):
                    return HKQuantity(unit: .hertz(), doubleValue: 3)
                case (distanceType.rawValue, .cumulativeSum):
                    return HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: 3.45)
                case (HKQuantityTypeIdentifier.physicalEffort.rawValue, .discreteAverage):
                    return HKQuantity(unit: HKUnit(from: "kcal/kg*hr"), doubleValue: 4.5)
                default: return nil
                }
            }
        )
        let converted = try await manager.convert(samples: [workout], as: .workouts)
        let payload = try HealthNormalizer().payload(
            deviceID: "fixture-device", dateRange: SyncDateRange(start: start, end: end), timezone: "UTC",
            quantitySamples: [], sleepSamples: [], workoutSamples: converted.workoutSamples, generatedAt: end
        )
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WorkoutFixture-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = directory.appendingPathComponent("queue.sqlite")
        let queue = try SQLiteLocalStore(url: database)
        try await queue.enqueueBatch(SyncBatch(payload: payload, createdAt: end))
        let reopened = try SQLiteLocalStore(url: database)
        let pending = try await reopened.pendingBatches()
        XCTAssertEqual(pending.count, 1)
        let persisted = try XCTUnwrap(pending.first)
        let request = try APIClient.makeSyncRequest(
            baseURL: "https://example.com", token: "fixture-token", deviceID: "fixture-device",
            appVersion: "1.0.1", payload: persisted.payload
        )
        XCTAssertEqual(request.url?.path, "/api/apple-health/sync")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let exported = try XCTUnwrap((json["workouts"] as? [[String: Any]])?.first)
        let metadata = try XCTUnwrap(exported["metadata"] as? [String: String])
        XCTAssertEqual(exported["id"] as? String, "healthkit:\(workout.uuid.uuidString)")
        XCTAssertEqual(exported["activity_type"] as? String, name)
        XCTAssertEqual(exported["source_name"] as? String, workout.sourceRevision.source.name)
        XCTAssertEqual(try XCTUnwrap(exported["active_energy_kcal"] as? Double), 240, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(exported["total_energy_kcal"] as? Double), 275, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(exported["distance_meters"] as? Double), 3450, accuracy: 0.000001)
        XCTAssertEqual(metadata["hk_workout_activity_type"], rawType)
        XCTAssertEqual(metadata["user_tag"], "fixture")
        for (key, expected) in [
            ("average_heart_rate_bpm", 120.0), ("max_heart_rate_bpm", 180.0),
            ("average_mets", expectedMETs), ("workout_effort_score", 7.0), ("estimated_workout_effort_score", 6.0)
        ] {
            XCTAssertEqual(try XCTUnwrap(metadata[key].flatMap(Double.init), key), expected, accuracy: 0.000001)
        }
    }
}

final class PhysicalWorkoutValidationTests: XCTestCase {
    func testExistingWorkoutsMatchHealthKitStatistics() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires a physical iPhone with existing HealthKit workouts")
        #else
        guard ProcessInfo.processInfo.environment["HEALTHSYNC_DEVICE_VALIDATION"] == "1" else {
            throw XCTSkip("Opt in with TEST_RUNNER_HEALTHSYNC_DEVICE_VALIDATION=1")
        }
        let store = HKHealthStore()
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(), predicate: nil, limit: 20,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples?.compactMap { $0 as? HKWorkout } ?? []) }
            }
            store.execute(query)
        }
        guard !workouts.isEmpty else { throw XCTSkip("No readable workouts; review Health permissions on the iPhone") }
        let result = try await HealthKitManager(healthStore: store).convert(samples: workouts, as: .workouts)
        XCTAssertEqual(result.workoutSamples.count, workouts.count)
        var availability: [String: Int] = [:]
        for (workout, sample) in zip(workouts, result.workoutSamples) {
            XCTAssertEqual(sample.uuid, workout.uuid)
            XCTAssertEqual(sample.metadata["hk_workout_activity_type"], String(workout.workoutActivityType.rawValue))
            if workout.workoutActivityType != .other { XCTAssertNotEqual(sample.activityType, "other") }
            let expectedNames: [HKWorkoutActivityType: String] = [
                .elliptical: "elliptical", .rowing: "rowing", .highIntensityIntervalTraining: "highIntensityIntervalTraining",
                .yoga: "yoga", .swimming: "swimming", .hiking: "hiking", .flexibility: "flexibility",
                .cooldown: "cooldown", .mindAndBody: "mindAndBody", .stairClimbing: "stairClimbing",
                .traditionalStrengthTraining: "traditionalStrengthTraining"
            ]
            if let expected = expectedNames[workout.workoutActivityType] { XCTAssertEqual(sample.activityType, expected) }
            let active = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
                ?? workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
            let basal = workout.statistics(for: HKQuantityType(.basalEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            XCTAssertEqual(sample.activeEnergyKcal, active)
            XCTAssertEqual(sample.totalEnergyKcal, active.flatMap { a in basal.map { a + $0 } })
            let heart = workout.statistics(for: HKQuantityType(.heartRate))
            let bpm = HKUnit.count().unitDivided(by: .minute())
            XCTAssertEqual(sample.metadata["average_heart_rate_bpm"].flatMap(Double.init), heart?.averageQuantity()?.doubleValue(for: bpm))
            XCTAssertEqual(sample.metadata["max_heart_rate_bpm"].flatMap(Double.init), heart?.maximumQuantity()?.doubleValue(for: bpm))
            let metsUnit = HKUnit(from: "kcal/kg*hr")
            let mets = (workout.metadata?[HKMetadataKeyAverageMETs] as? HKQuantity)?.doubleValue(for: metsUnit)
                ?? workout.statistics(for: HKQuantityType(.physicalEffort))?.averageQuantity()?.doubleValue(for: metsUnit)
            XCTAssertEqual(sample.metadata["average_mets"].flatMap(Double.init), mets)
            for key in ["average_heart_rate_bpm", "max_heart_rate_bpm", "average_mets", "workout_effort_score", "estimated_workout_effort_score"] {
                if sample.metadata[key] != nil { availability[key, default: 0] += 1 }
            }
            if sample.activeEnergyKcal != nil { availability["active_energy_kcal", default: 0] += 1 }
            if sample.totalEnergyKcal != nil { availability["total_energy_kcal", default: 0] += 1 }
            if sample.distanceMeters != nil { availability["distance_meters", default: 0] += 1 }
            let payload = HealthNormalizer().workouts(from: [sample])[0]
            let encoded = try PayloadJSON.encoder.encode(payload)
            let decoded = try PayloadJSON.decoder.decode(HealthWorkout.self, from: encoded)
            XCTAssertEqual(decoded.id, payload.id)
            XCTAssertEqual(decoded.activityType, payload.activityType)
            XCTAssertEqual(decoded.durationSeconds, payload.durationSeconds)
            XCTAssertEqual(decoded.activeEnergyKcal, payload.activeEnergyKcal)
            XCTAssertEqual(decoded.totalEnergyKcal, payload.totalEnergyKcal)
            XCTAssertEqual(decoded.distanceMeters, payload.distanceMeters)
            XCTAssertEqual(decoded.metadata, payload.metadata)
            XCTAssertEqual(decoded.startAt.timeIntervalSince1970, payload.startAt.timeIntervalSince1970, accuracy: 0.001)
            XCTAssertEqual(decoded.endAt.timeIntervalSince1970, payload.endAt.timeIntervalSince1970, accuracy: 0.001)
        }
        let report: [String: Any] = [
            "workouts_checked": workouts.count,
            "activity_types": Array(Set(result.workoutSamples.map(\.activityType))).sorted(),
            "available_field_counts": availability
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HealthSync", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("WorkoutValidation.json"), options: .atomic)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "Workout field availability"
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
    }
}

final class APIClientTests: XCTestCase {
    func testWorkoutNamesPreserveExistingValuesAndExpandRequestedTypes() {
        let manager = HealthKitManager()
        let names: [(HKWorkoutActivityType, String)] = [
            (.running, "running"), (.walking, "walking"), (.cycling, "cycling"),
            (.traditionalStrengthTraining, "traditionalStrengthTraining"),
            (.functionalStrengthTraining, "functionalStrengthTraining"),
            (.elliptical, "elliptical"), (.rowing, "rowing"),
            (.highIntensityIntervalTraining, "highIntensityIntervalTraining"),
            (.yoga, "yoga"), (.swimming, "swimming"), (.hiking, "hiking"),
            (.flexibility, "flexibility"), (.cooldown, "cooldown"),
            (.mindAndBody, "mindAndBody"), (.stairClimbing, "stairClimbing"),
            (.underwaterDiving, "underwaterDiving"), (.other, "other")
        ]
        for (type, expected) in names {
            XCTAssertEqual(manager.activityName(type), expected)
        }
        XCTAssertEqual(manager.activityName(HKWorkoutActivityType(rawValue: 9999)!), "hk_9999")
    }

    func testWorkoutConversionRetainsRawTypeAndSourceMetadata() async throws {
        let workout = HKWorkout(
            activityType: .elliptical,
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 60),
            duration: 60,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 12),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: 345),
            metadata: ["user_tag": "keep-me"]
        )
        let result = try await HealthKitManager(sampleReader: { _, _ in [] }).convert(samples: [workout], as: .workouts)
        let sample = try XCTUnwrap(result.workoutSamples.first)
        XCTAssertEqual(sample.uuid, workout.uuid)
        XCTAssertEqual(sample.activityType, "elliptical")
        XCTAssertEqual(sample.metadata["hk_workout_activity_type"], "16")
        XCTAssertEqual(sample.metadata["user_tag"], "keep-me")
        XCTAssertEqual(sample.distanceMeters, workout.totalDistance?.doubleValue(for: .meter()))
        XCTAssertEqual(sample.activeEnergyKcal, 12)
        XCTAssertNil(sample.totalEnergyKcal)
        let encoded = try PayloadJSON.encoder.encode(HealthNormalizer().workouts(from: [sample])[0])
        let decoded = try PayloadJSON.decoder.decode(HealthWorkout.self, from: encoded)
        XCTAssertEqual(decoded.metadata["hk_workout_activity_type"], "16")
        XCTAssertEqual(decoded.id, "healthkit:\(workout.uuid.uuidString)")
    }

    func testWorkoutConversionExportsNumericMETsWithoutInventingMissingMetrics() async throws {
        let workout = HKWorkout(
            activityType: .elliptical,
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 60),
            duration: 60,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyAverageMETs: HKQuantity(unit: HKUnit(from: "kcal/kg*hr"), doubleValue: 4.5),
                "user_tag": "keep-me"
            ]
        )
        let result = try await HealthKitManager(sampleReader: { _, _ in [] }).convert(samples: [workout], as: .workouts)
        let sample = try XCTUnwrap(result.workoutSamples.first)
        XCTAssertEqual(sample.metadata["average_mets"].flatMap(Double.init), 4.5)
        XCTAssertEqual(sample.metadata["user_tag"], "keep-me")
        XCTAssertNil(sample.metadata["average_heart_rate_bpm"])
        XCTAssertNil(sample.metadata["max_heart_rate_bpm"])
        XCTAssertNil(sample.metadata["workout_effort_score"])
        XCTAssertNil(sample.metadata["estimated_workout_effort_score"])
        XCTAssertNil(sample.activeEnergyKcal)
        XCTAssertNil(sample.totalEnergyKcal)
        XCTAssertNil(sample.distanceMeters)
    }

    func testWorkoutStatisticsExportSeparateCaloriesHeartRateAndRowingDistance() throws {
        let workout = HKWorkout(
            activityType: .rowing,
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 2100),
            duration: 2100,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 200),
            totalDistance: nil,
            metadata: ["user_tag": "keep-me"]
        )
        let sample = HealthKitManager().workoutSample(from: workout) { type, option in
            switch (type, option) {
            case (.activeEnergy, .cumulativeSum): 240
            case (.basalEnergy, .cumulativeSum): 35
            case (.heartRate, .discreteAverage): 122
            case (.heartRate, .discreteMax): 158
            case (.distanceRowing, .cumulativeSum): 3450
            case (.physicalEffort, .discreteAverage): 4.5
            default: nil
            }
        }
        let encoded = try PayloadJSON.encoder.encode(HealthNormalizer().workouts(from: [sample])[0])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let metadata = try XCTUnwrap(object["metadata"] as? [String: String])
        XCTAssertEqual(object["active_energy_kcal"] as? Double, 240)
        XCTAssertEqual(object["total_energy_kcal"] as? Double, 275)
        XCTAssertEqual(object["distance_meters"] as? Double, 3450)
        XCTAssertEqual(metadata["average_heart_rate_bpm"].flatMap(Double.init), 122)
        XCTAssertEqual(metadata["max_heart_rate_bpm"].flatMap(Double.init), 158)
        XCTAssertEqual(metadata["average_mets"].flatMap(Double.init), 4.5)
        XCTAssertEqual(metadata["user_tag"], "keep-me")
        XCTAssertEqual(metadata["hk_workout_activity_type"], "35")
    }

    func testWorkoutPermissionsIncludeSummaryTypesOnlyWhenWorkoutsAreSelected() {
        let readTypes = HealthKitTypeRegistry.readTypes(for: [.workouts])
        for type: HealthDataType in [.heartRate, .activeEnergy, .basalEnergy, .physicalEffort, .distanceRowing] {
            XCTAssertTrue(readTypes.contains(HealthKitTypeRegistry.objectType(for: type)!))
        }
        XCTAssertEqual(HealthKitTypeRegistry.readTypes(for: [.stepCount]), [HKQuantityType(.stepCount)])
    }

    func testWorkoutConversionQueriesRelatedEffortAndExportsLatestRating() async throws {
        guard #available(iOS 18.0, *) else { throw XCTSkip("Workout effort requires iOS 18") }
        let start = Date(timeIntervalSince1970: 0)
        let workout = HKWorkout(activityType: .rowing, start: start, end: start.addingTimeInterval(60))
        let effortType = HKQuantityType(.workoutEffortScore)
        let estimatedType = HKQuantityType(.estimatedWorkoutEffortScore)
        let samples = [
            HKQuantitySample(type: effortType, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: 4), start: start, end: start),
            HKQuantitySample(type: effortType, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: 7), start: start, end: start.addingTimeInterval(60)),
            HKQuantitySample(type: estimatedType, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: 6), start: start, end: start)
        ]
        let manager = HealthKitManager(sampleReader: { type, predicate in
            XCTAssertEqual(
                predicate,
                HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
            )
            return samples.filter { $0.sampleType == type }.reversed()
        })
        let result = try await manager.convert(samples: [workout], as: .workouts)
        let metadata = try XCTUnwrap(result.workoutSamples.first?.metadata)
        XCTAssertEqual(metadata["workout_effort_score"].flatMap(Double.init), 7)
        XCTAssertEqual(metadata["estimated_workout_effort_score"].flatMap(Double.init), 6)
    }

    func testDeniedOptionalEffortDoesNotPreventWorkoutExport() async throws {
        let start = Date(timeIntervalSince1970: 0)
        let workout = HKWorkout(activityType: .yoga, start: start, end: start.addingTimeInterval(60))
        let manager = HealthKitManager(sampleReader: { _, _ in
            throw HKError(.errorAuthorizationDenied)
        })
        let result = try await manager.convert(samples: [workout], as: .workouts)
        XCTAssertEqual(result.workoutSamples.first?.activityType, "yoga")
        XCTAssertNil(result.workoutSamples.first?.metadata["workout_effort_score"])
    }

    func testWorkoutEffortReadFailuresAndCancellationPropagateForRetry() async throws {
        guard #available(iOS 18.0, *) else { throw XCTSkip("Workout effort requires iOS 18") }
        let start = Date(timeIntervalSince1970: 0)
        let workout = HKWorkout(activityType: .yoga, start: start, end: start.addingTimeInterval(60))
        for expected: Error in [HKError(.errorDatabaseInaccessible), CancellationError()] {
            let manager = HealthKitManager(sampleReader: { _, _ in throw expected })
            do {
                _ = try await manager.convert(samples: [workout], as: .workouts)
                XCTFail("A failed effort read must not acknowledge an incomplete workout")
            } catch {
                XCTAssertEqual((error as NSError).domain, (expected as NSError).domain)
                XCTAssertEqual((error as NSError).code, (expected as NSError).code)
            }
        }
    }

    func testWorkoutRereadAndBackfillIncludeRelatedEffort() async throws {
        guard #available(iOS 18.0, *) else { throw XCTSkip("Workout effort requires iOS 18") }
        let start = Date(timeIntervalSince1970: 0)
        let end = start.addingTimeInterval(60)
        let workout = HKWorkout(activityType: .elliptical, start: start, end: end)
        let effort = HKQuantitySample(
            type: HKQuantityType(.workoutEffortScore),
            quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: 7),
            start: start,
            end: end
        )
        let manager = HealthKitManager(sampleReader: { type, predicate in
            if type == HKObjectType.workoutType() {
                XCTAssertEqual(predicate, HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate]))
                return [workout]
            }
            XCTAssertEqual(predicate, HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil))
            return type == effort.sampleType ? [effort] : []
        })
        let recent = try await manager.fetchSamples(types: [.workouts], start: start, end: end)
        var backfill = HealthKitFetchResult.empty
        try await manager.forEachBackfillBatch(types: [.workouts], start: start, end: end, mode: .dailySummary) {
            backfill.workoutSamples += $0.workoutSamples
        }
        for result in [recent, backfill] {
            XCTAssertEqual(result.workoutSamples.count, 1)
            XCTAssertEqual(result.workoutSamples.first?.metadata["workout_effort_score"].flatMap(Double.init), 7)
            XCTAssertEqual(result.workoutSamples.first?.uuid, workout.uuid)
            XCTAssertTrue(result.quantitySamples.isEmpty)
        }
    }

    func testWorkoutDistanceAndMETsRemainAvailableWithoutActiveEnergy() {
        let start = Date(timeIntervalSince1970: 0)
        let workout = HKWorkout(
            activityType: .rowing, start: start, end: start.addingTimeInterval(60), duration: 60,
            totalEnergyBurned: nil, totalDistance: nil,
            metadata: nil
        )
        let sample = HealthKitManager().workoutSample(from: workout) { type, option in
            switch (type, option) {
            case (.basalEnergy, .cumulativeSum): 10
            case (.distanceRowing, .cumulativeSum): 999
            case (.physicalEffort, .discreteAverage): 4.5
            default: nil
            }
        }
        XCTAssertEqual(sample.distanceMeters, 999)
        XCTAssertEqual(sample.metadata["average_mets"].flatMap(Double.init), 4.5)
        XCTAssertNil(sample.activeEnergyKcal)
        XCTAssertNil(sample.totalEnergyKcal)
    }

    func testBackendURLValidationRejectsMissingURLBeforeSyncWorkBegins() {
        XCTAssertThrowsError(try APIClient.validatedRootURL(from: "  ")) { error in
            XCTAssertEqual(error as? APIClientError, .missingBackendURL)
        }
    }

    func testRetryClassificationMatchesBackendContract() {
        XCTAssertEqual(APIClient.classify(statusCode: 200), .accepted)
        XCTAssertEqual(APIClient.classify(statusCode: 201), .accepted)
        XCTAssertEqual(APIClient.classify(statusCode: 202), .accepted)
        XCTAssertEqual(APIClient.classify(statusCode: 401), .authError)
        XCTAssertEqual(APIClient.classify(statusCode: 403), .authError)
        XCTAssertEqual(APIClient.classify(statusCode: 429), .transient)
        XCTAssertEqual(APIClient.classify(statusCode: 500), .transient)
        XCTAssertEqual(APIClient.classify(statusCode: 400), .permanent)
    }

    func testClientBuildsContractRequestWithoutLeakingToken() throws {
        let payload = SyncPayload.empty(
            deviceID: "device-123",
            dateRange: SyncDateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60)),
            timezone: "Asia/Kolkata"
        )
        let request = try APIClient.makeSyncRequest(
            baseURL: "https://example.com/root/",
            token: "secret-token",
            deviceID: "device-123",
            appVersion: "1.0",
            payload: payload
        )

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/root/api/apple-health/sync")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Id"), "device-123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-Version"), "1.0")
        XCTAssertFalse(String(describing: APIClientError.authRejected).contains("secret-token"))
        XCTAssertFalse(APIClientError.authRejected.userMessage.contains("secret-token"))
        XCTAssertEqual(
            APIClientError.authRejected.userMessage,
            "The saved backend token was rejected. For hosted storage, create hosted storage again; for your own backend, update the auth token."
        )
    }

    func testClientBuildsHostedProvisioningRequest() throws {
        let request = try APIClient.makeHostedWorkspaceRequest(
            baseURL: "https://api.example.com",
            label: "Personal Health"
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/api/hosted/workspaces")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), #"{"label":"Personal Health"}"#)
    }

    func testClientBuildsHostedAgentTokenRefreshRequest() throws {
        let request = try APIClient.makeHostedAgentTokenRefreshRequest(
            baseURL: "https://api.example.com",
            token: "ingest-token"
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/api/hosted/agent-token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ingest-token")
    }

    func testClientBuildsHostedWorkspaceResetRequest() throws {
        let request = try APIClient.makeHostedWorkspaceResetRequest(
            baseURL: "https://api.example.com",
            token: "ingest-token",
            label: "Personal Health"
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/api/hosted/workspaces/reset")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ingest-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), #"{"label":"Personal Health"}"#)
    }

    func testHostedAgentTokenRefreshResponseDecodesWorkspaceIdentity() throws {
        let data = Data(#"{"workspace_id":"wk_test","agent_endpoint":"https://api.example.com/api/agent/health-data","agent_token":"hs_agent_test"}"#.utf8)

        let response = try JSONDecoder().decode(HostedAgentTokenRefreshResponse.self, from: data)

        XCTAssertEqual(response.workspaceID, "wk_test")
        XCTAssertEqual(response.agentEndpoint, "https://api.example.com/api/agent/health-data")
        XCTAssertEqual(response.agentToken, "hs_agent_test")
    }

    func testUploadResultDecodesWorkspaceIdentity() throws {
        let data = Data(#"{"ok":true,"received":3,"duplicates":1,"workspace_id":"wk_test","export_id":"export-123"}"#.utf8)

        let result = try JSONDecoder().decode(UploadResult.self, from: data)

        XCTAssertEqual(result.workspaceID, "wk_test")
        XCTAssertEqual(result.exportID, "export-123")
        XCTAssertEqual(result.deleted, 0)
    }

    func testNetworkFailureMessagesExposeActionableCause() {
        XCTAssertEqual(
            APIClient.networkFailureMessage(for: URLError(.cannotFindHost)),
            "Cannot find the backend host. Check the backend URL."
        )
        XCTAssertEqual(
            APIClient.networkFailureMessage(for: URLError(.notConnectedToInternet)),
            "This iPhone lost network access. Check Wi-Fi or cellular and try again."
        )
    }
}

final class AppSettingsHostedEndpointTests: XCTestCase {
    func testCleanInstallDefaultsToHostedStorageSoManualSyncHasASetupPath() {
        XCTAssertEqual(AppSettings.default.storageMode, .hostedHealthSync)
        XCTAssertEqual(AppSettings.default.effectiveBackendURL, AppSettings.hostedBackendURL)
        XCTAssertEqual(AppSettings.default.syncFrequency, .hourlyBestEffort)
    }

    func testDefaultSettingsSelectEverySupportedHealthDataType() {
        XCTAssertEqual(AppSettings.default.selectedTypes, Set(HealthDataType.allCases))
    }

    func testHealthMetricCategoriesCoverEverySupportedTypeExactlyOnce() {
        let groupedTypes = HealthMetricCategory.allCases.flatMap(\.types)

        XCTAssertEqual(Set(groupedTypes), Set(HealthDataType.allCases))
        XCTAssertEqual(groupedTypes.count, HealthDataType.allCases.count)
    }

    func testHealthMetricCategoriesGroupCommonTypesByUserMeaning() {
        XCTAssertEqual(HealthMetricCategory.category(for: .stepCount), .activity)
        XCTAssertEqual(HealthMetricCategory.category(for: .heartRate), .heart)
        XCTAssertEqual(HealthMetricCategory.category(for: .dietaryProtein), .nutrition)
        XCTAssertEqual(HealthMetricCategory.category(for: .bloodGlucose), .clinical)
        XCTAssertEqual(HealthMetricCategory.category(for: .sleepAnalysis), .sleepMindfulness)
        XCTAssertEqual(HealthMetricCategory.category(for: .menstrualFlow), .reproductiveHealth)
    }

    func testDecodingLegacyDefaultSelectedTypesEnablesAllDietaryTypes() throws {
        let legacyDefaultSelectedTypes: Set<HealthDataType> = [
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
        let settings = AppSettings(
            backendURL: "",
            selectedTypes: legacyDefaultSelectedTypes,
            syncFrequency: .manualOnly,
            hasRequestedHealthPermissions: false,
            storageMode: .customBackend,
            hostedWorkspaceID: nil,
            hostedAgentEndpoint: nil
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertFalse(legacyDefaultSelectedTypes.isSuperset(of: HealthDataType.dietaryTypes))
        XCTAssertTrue(decoded.selectedTypes.isSuperset(of: HealthDataType.dietaryTypes))
    }

    func testDecodingCustomSelectedTypesPreservesUserChoice() throws {
        let customSelectedTypes: Set<HealthDataType> = [.stepCount, .sleepAnalysis]
        let settings = AppSettings(
            backendURL: "",
            selectedTypes: customSelectedTypes,
            syncFrequency: .manualOnly,
            hasRequestedHealthPermissions: false,
            storageMode: .customBackend,
            hostedWorkspaceID: nil,
            hostedAgentEndpoint: nil
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.selectedTypes, customSelectedTypes)
    }

    func testHostedStorageUsesManagedEndpointWhenEditableBackendURLIsEmpty() {
        var settings = AppSettings.default
        settings.storageMode = .hostedHealthSync
        settings.backendURL = ""

        XCTAssertEqual(settings.effectiveBackendURL, AppSettings.hostedBackendURL)
    }

    func testCustomStorageUsesUserBackendURL() {
        var settings = AppSettings.default
        settings.storageMode = .customBackend
        settings.backendURL = "https://api.example.com"

        XCTAssertEqual(settings.effectiveBackendURL, "https://api.example.com")
    }

    func testOnlyCustomStorageShowsManualBackendSettings() {
        XCTAssertTrue(StorageMode.customBackend.showsManualBackendSettings)
        XCTAssertFalse(StorageMode.hostedHealthSync.showsManualBackendSettings)
    }
}

final class UploadDestinationPreparationTests: XCTestCase {
    func testHostedStorageWithoutCredentialsRequiresAutomaticProvisioning() {
        XCTAssertEqual(
            UploadDestinationPreparation.resolve(
                storageMode: .hostedHealthSync,
                hasAgentEndpoint: false,
                hasAgentToken: false,
                hasIngestToken: false
            ),
            .provisionHostedStorage
        )
    }

    func testCompleteHostedStorageAndCustomBackendDoNotAutoProvision() {
        XCTAssertEqual(
            UploadDestinationPreparation.resolve(
                storageMode: .hostedHealthSync,
                hasAgentEndpoint: true,
                hasAgentToken: true,
                hasIngestToken: true
            ),
            .ready
        )
        XCTAssertEqual(
            UploadDestinationPreparation.resolve(
                storageMode: .customBackend,
                hasAgentEndpoint: false,
                hasAgentToken: false,
                hasIngestToken: false
            ),
            .ready
        )
    }
}

final class OnboardingStorageDisclosureTests: XCTestCase {
    func testDisclosureExplainsAutomaticHostedStorageBeforeHealthAccess() {
        XCTAssertEqual(
            OnboardingStorageDisclosure.message,
            "Continue creates private hosted storage, then requests Health access. You can switch to your own backend later."
        )
    }
}

final class HealthKitTypeRegistryTests: XCTestCase {
    func testRegistryIncludesRepresentativeHealthKitQuantityCategoryAndWorkoutTypes() {
        XCTAssertNotNil(HealthKitTypeRegistry.objectType(for: .bloodGlucose))
        XCTAssertNotNil(HealthKitTypeRegistry.objectType(for: .vo2Max))
        XCTAssertNotNil(HealthKitTypeRegistry.objectType(for: .mindfulSession))
        XCTAssertNotNil(HealthKitTypeRegistry.objectType(for: .abdominalCramps))
        XCTAssertNotNil(HealthKitTypeRegistry.objectType(for: .workouts))
    }

    func testPreferredUnitsCoverRepresentativeAdditionalQuantityTypes() throws {
        XCTAssertEqual(try XCTUnwrap(HealthKitTypeRegistry.preferredQuantityUnit(for: .bloodGlucose)).sampleUnit, .milligramPerDeciliter)
        XCTAssertEqual(try XCTUnwrap(HealthKitTypeRegistry.preferredQuantityUnit(for: .vo2Max)).sampleUnit, .milliliterPerKilogramMinute)
        XCTAssertEqual(try XCTUnwrap(HealthKitTypeRegistry.preferredQuantityUnit(for: .respiratoryRate)).sampleUnit, .countPerMinute)
        XCTAssertNil(HealthKitTypeRegistry.preferredQuantityUnit(for: .mindfulSession))
    }
}

final class HealthKitReadErrorPolicyTests: XCTestCase {
    func testSkipsOnlyUndeterminedReadAuthorization() {
        XCTAssertTrue(
            HealthKitReadErrorPolicy.shouldSkipType(
                HealthKitManagerError.authorizationNotDetermined
            )
        )
        XCTAssertFalse(
            HealthKitReadErrorPolicy.shouldSkipType(
                HealthKitManagerError.healthDataUnavailable
            )
        )
        XCTAssertFalse(
            HealthKitReadErrorPolicy.shouldSkipType(APIClientError.invalidResponse)
        )
    }
}

final class HealthKitManagerErrorTests: XCTestCase {
    func testAuthorizationNotDeterminedMessageUsesNeutralPermissionAction() {
        XCTAssertEqual(
            HealthKitManagerError.authorizationNotDetermined.errorDescription,
            "Health permissions are not set up yet. Tap Continue and review the requested read permissions."
        )
    }
}

final class HealthPermissionPromptPresentationTests: XCTestCase {
    func testShowsConnectActionWhenHealthPermissionsAreMissing() {
        let presentation = HealthPermissionPromptPresentation(
            permissionSummary: "Not requested",
            lastError: nil,
            isBusy: false
        )

        XCTAssertTrue(presentation.shouldShowConnectAction)
        XCTAssertEqual(presentation.connectButtonTitle, "Continue")
        XCTAssertFalse(presentation.isConnectButtonDisabled)
    }

    func testShowsConnectActionWhenSyncHitAuthorizationNotDetermined() {
        let presentation = HealthPermissionPromptPresentation(
            permissionSummary: "Requested",
            lastError: HealthKitManagerError.authorizationNotDetermined.errorDescription,
            isBusy: false
        )

        XCTAssertTrue(presentation.shouldShowConnectAction)
    }

    func testHidesConnectActionWhenPermissionsAreAlreadyRequested() {
        let presentation = HealthPermissionPromptPresentation(
            permissionSummary: "Requested",
            lastError: nil,
            isBusy: false
        )

        XCTAssertFalse(presentation.shouldShowConnectAction)
    }
}

final class HealthActionFeedbackTests: XCTestCase {
    func testPermissionSuccessMessageAcknowledgesCompletion() {
        XCTAssertEqual(
            HealthActionFeedback.permissionRequested.message,
            "Health access request completed. You can change access at any time in iPhone Settings."
        )
    }

    func testEmptyAndSuccessfulSyncMessagesAreVisibleOutcomes() {
        XCTAssertEqual(HealthActionFeedback.noSamples.message, "No health samples were found for the last 24 hours.")
        XCTAssertEqual(HealthActionFeedback.syncCompleted.message, "The last 24 hours were synced successfully.")
    }
}

final class DashboardMetricDateFormatterTests: XCTestCase {
    func testDisplayValueUsesShortReadableDateForCompactMetricCards() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 4, minute: 27)))

        XCTAssertEqual(DashboardMetricDateFormatter.displayValue(for: date, timeZone: timeZone), "2 Jun, 4:27 AM")
        XCTAssertEqual(DashboardMetricDateFormatter.displayValue(for: nil), "Never")
    }
}

final class HealthSyncUserMessagesTests: XCTestCase {
    func testNoSamplesMessagesUseAppleHealthWording() {
        XCTAssertEqual(HealthSyncUserMessages.noNewSamplesFound, "No new Apple Health samples found.")
        XCTAssertEqual(HealthSyncUserMessages.noSamplesFoundForDateRange, "No Apple Health samples found for this date range.")
    }

    func testDisplayLogMessageUpdatesLegacyHealthKitSampleCopy() {
        XCTAssertEqual(
            HealthSyncUserMessages.displayLogMessage("No new HealthKit samples found."),
            "No new Apple Health samples found."
        )
        XCTAssertEqual(
            HealthSyncUserMessages.displayLogMessage("No HealthKit samples found for this date range."),
            "No Apple Health samples found for this date range."
        )
        XCTAssertEqual(
            HealthSyncUserMessages.displayLogMessage("Missing com.apple.developer.healthkit entitlement."),
            "Missing com.apple.developer.healthkit entitlement."
        )
    }
}

final class DevelopmentKeychainBypassTests: XCTestCase {
    func testDebugBuildDoesNotReadKeychainForStoredTokenAvailability() throws {
        var didReadKeychain = false

        let hasStoredToken = try DevelopmentKeychainBypass.hasStoredToken {
            didReadKeychain = true
            throw KeychainError.unexpectedStatus(-34018)
        }

        XCTAssertTrue(DevelopmentKeychainBypass.isEnabled)
        XCTAssertTrue(hasStoredToken)
        XCTAssertFalse(didReadKeychain)
    }

    func testDebugBuildDoesNotReadHostedAgentToken() throws {
        var didReadKeychain = false

        let token = try DevelopmentKeychainBypass.hostedAgentToken {
            didReadKeychain = true
            throw KeychainError.unexpectedStatus(-34018)
        }

        XCTAssertTrue(DevelopmentKeychainBypass.isEnabled)
        XCTAssertEqual(token, "")
        XCTAssertFalse(didReadKeychain)
    }
}

final class HealthPermissionSettingsPresentationTests: XCTestCase {
    func testNotRequestedStateOffersAppleHealthApproval() {
        let presentation = HealthPermissionSettingsPresentation(
            permissionSummary: "Not requested",
            isBusy: false
        )

        XCTAssertEqual(presentation.approvalButtonTitle, "Continue")
        XCTAssertEqual(presentation.approvalButtonSystemImage, "heart.text.square.fill")
        XCTAssertFalse(presentation.isApprovalButtonDisabled)
        XCTAssertFalse(presentation.showsSettingsButton)
    }

    func testAlreadyRequestedStateOffersApprovalRetryAndSettingsRecovery() {
        let presentation = HealthPermissionSettingsPresentation(
            permissionSummary: "Requested",
            isBusy: false
        )

        XCTAssertEqual(presentation.approvalButtonTitle, "Continue")
        XCTAssertTrue(presentation.showsSettingsButton)
        XCTAssertEqual(presentation.settingsButtonTitle, "Open iPhone Settings")
    }
}

final class SettingsOverviewPresentationTests: XCTestCase {
    func testCustomBackendSummaryShowsTokenAndSelectionState() {
        let presentation = SettingsOverviewPresentation(
            storageMode: .customBackend,
            permissionSummary: "Requested",
            selectedHealthDataCount: 8,
            totalHealthDataCount: 12,
            hasStoredUploadToken: false
        )

        XCTAssertEqual(presentation.storageLabel, "Custom backend")
        XCTAssertEqual(presentation.permissionLabel, "Apple Health ready")
        XCTAssertEqual(presentation.healthDataSummary, "8 of 12 selected")
        XCTAssertEqual(presentation.tokenLabel, "Token needed")
    }

    func testHostedStorageSummaryShowsManagedDestinationAndSavedToken() {
        let presentation = SettingsOverviewPresentation(
            storageMode: .hostedHealthSync,
            permissionSummary: "Unavailable",
            selectedHealthDataCount: 12,
            totalHealthDataCount: 12,
            hasStoredUploadToken: true
        )

        XCTAssertEqual(presentation.storageLabel, "Hosted storage")
        XCTAssertEqual(presentation.permissionLabel, "Apple Health unavailable")
        XCTAssertEqual(presentation.healthDataSummary, "12 of 12 selected")
        XCTAssertEqual(presentation.tokenLabel, "Token saved")
    }
}

final class InitialAppTabTests: XCTestCase {
    func testDebugLaunchArgumentCanOpenSettingsForUiVerification() {
        XCTAssertEqual(
            InitialAppTab.resolve(arguments: ["HealthSync", "-HealthSyncOpenSettings"]),
            .settings
        )
        XCTAssertEqual(InitialAppTab.resolve(arguments: ["HealthSync"]), .dashboard)
    }
}

final class SupportDevelopmentPromptTests: XCTestCase {
    func testPromptUsesZcashOnlySupportDetails() {
        let prompt = SupportDevelopmentPrompt.current

        XCTAssertEqual(prompt.paymentMethodLabel, "ZEC")
        XCTAssertEqual(prompt.message, "Support continued HealthSync development with ZEC.")
        XCTAssertFalse(prompt.message.contains("$"))
        XCTAssertFalse(prompt.message.contains("10"))
        XCTAssertEqual(
            prompt.zcashAddress,
            "u1cyxqx2za9c7g2h7tjz0nn7rdf5fgykmqgw4eke7fvfa9pd7lynjkqfeq4hzd3tkys4pvku5xnmmwclm77jv9ljkhdefrvzc6pgehc63rcnmylqlxt0fmz55t6wdp6dyk5w2hzx06hs93xun5smexvwn04ju4ppy54gx477ftequajh0t"
        )
    }
}

final class HostedStorageSetupPresentationTests: XCTestCase {
    func testCreatingStateShowsProgressAndDisablesCreateButton() {
        let presentation = HostedStorageSetupPresentation(
            isBusy: true,
            backendURL: "https://api.example.com",
            lastError: nil,
            hostedAgentEndpoint: nil,
            hostedAgentToken: "",
            hasStoredUploadToken: false
        )

        XCTAssertEqual(presentation.createButtonTitle, "Creating Hosted Storage...")
        XCTAssertEqual(presentation.progressMessage, "Creating hosted storage...")
        XCTAssertTrue(presentation.isCreateButtonDisabled)
        XCTAssertNil(presentation.feedbackMessage)
    }

    func testHostedSetupDoesNotRequireManualBackendURL() {
        let presentation = HostedStorageSetupPresentation(
            isBusy: false,
            backendURL: "",
            lastError: nil,
            hostedAgentEndpoint: nil,
            hostedAgentToken: "",
            hasStoredUploadToken: false
        )

        XCTAssertFalse(presentation.isCreateButtonDisabled)
        XCTAssertNil(presentation.feedbackMessage)
        XCTAssertEqual(presentation.feedbackKind, .none)
    }

    func testProvisioningErrorIsVisibleToTheUser() {
        let presentation = HostedStorageSetupPresentation(
            isBusy: false,
            backendURL: "https://api.example.com",
            lastError: "Network unavailable or server temporarily unavailable.",
            hostedAgentEndpoint: nil,
            hostedAgentToken: "",
            hasStoredUploadToken: false
        )

        XCTAssertEqual(presentation.feedbackMessage, "Network unavailable or server temporarily unavailable.")
        XCTAssertEqual(presentation.feedbackKind, .error)
        XCTAssertFalse(presentation.isCreateButtonDisabled)
    }

    func testReadyStateShowsHostedStorageSuccess() {
        let presentation = HostedStorageSetupPresentation(
            isBusy: false,
            backendURL: "https://api.example.com",
            lastError: nil,
            hostedAgentEndpoint: "https://api.example.com/api/agent/health-data",
            hostedAgentToken: "",
            hasStoredUploadToken: true
        )

        XCTAssertEqual(presentation.feedbackMessage, "Hosted storage is ready.")
        XCTAssertEqual(presentation.feedbackKind, .success)
        XCTAssertEqual(presentation.createButtonTitle, "Hosted Storage Created")
        XCTAssertEqual(presentation.createButtonSystemImage, "checkmark.circle")
        XCTAssertTrue(presentation.isCreateButtonDisabled)
    }

    func testExistingHostedStorageWithoutUploadTokenOffersRepairAction() {
        let presentation = HostedStorageSetupPresentation(
            isBusy: false,
            backendURL: "https://api.example.com",
            lastError: nil,
            hostedAgentEndpoint: "https://api.example.com/api/agent/health-data",
            hostedAgentToken: "agent-token",
            hasStoredUploadToken: false
        )

        XCTAssertEqual(presentation.feedbackMessage, "Hosted storage needs refresh before uploads can reach the agent endpoint.")
        XCTAssertEqual(presentation.feedbackKind, .info)
        XCTAssertEqual(presentation.createButtonTitle, "Refresh Hosted Storage")
        XCTAssertEqual(presentation.createButtonSystemImage, "arrow.clockwise")
        XCTAssertFalse(presentation.isCreateButtonDisabled)
    }

    func testReadyHostedStorageOffersResetAction() {
        let presentation = HostedStorageSetupPresentation(
            isBusy: false,
            backendURL: "https://api.example.com",
            lastError: nil,
            hostedAgentEndpoint: "https://api.example.com/api/agent/health-data",
            hostedAgentToken: "agent-token",
            hasStoredUploadToken: true
        )

        XCTAssertTrue(presentation.showsResetButton)
        XCTAssertEqual(presentation.resetButtonTitle, "Reset Hosted Storage")
        XCTAssertFalse(presentation.isResetButtonDisabled)
    }
}

private final class UploadTestURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let data = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

final class UploadTransportRecoveryTests: XCTestCase {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UploadTestURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    func testCancelledNetworkRequestDoesNotRetry() async throws {
        let session = session()
        defer { session.invalidateAndCancel(); UploadTestURLProtocol.handler = nil }
        let lock = NSLock()
        var count = 0
        UploadTestURLProtocol.handler = { _ in
            lock.lock()
            count += 1
            lock.unlock()
            throw URLError(.cancelled)
        }
        let payload = SyncPayload.empty(deviceID: "device", dateRange: SyncDateRange(start: .distantPast, end: .distantPast), timezone: "UTC")
        do {
            _ = try await APIClient(session: session).upload(batch: SyncBatch(payload: payload), configuration: UploadConfiguration(baseURL: "https://example.com", token: "test", deviceID: "device", appVersion: "1.0.1"))
            XCTFail("Cancellation must propagate")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(count, 1)
    }

    func testLostUploadReplyRetriesOriginalExportAfterReopeningLocalDatabase() async throws {
        let session = session()
        defer { session.invalidateAndCancel(); UploadTestURLProtocol.handler = nil }
        let lock = NSLock()
        var count = 0
        var bodies: [Data] = []
        UploadTestURLProtocol.handler = { request in
            lock.lock()
            defer { lock.unlock() }
            count += 1
            var body = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let length = stream.read(&buffer, maxLength: buffer.count)
                    if length <= 0 { break }
                    body.append(contentsOf: buffer.prefix(length))
                }
            }
            bodies.append(body)
            if count == 1 { throw URLError(.timedOut) }
            return Data(#"{"ok":true,"received":1,"duplicates":1}"#.utf8)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LostReply-\(UUID()).sqlite")
        let store = try SQLiteLocalStore(url: url)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let metric = HealthMetric(id: "healthkit:retained-id", type: "step_count", value: 12, unit: "count", startAt: date, endAt: date, sourceName: "Watch", sourceBundleID: nil, metadata: [:])
        let payload = SyncPayload(deviceID: "device", exportID: UUID(), generatedAt: date, timezone: "UTC", source: "ios-healthkit", schemaVersion: 1, dateRange: SyncDateRange(start: date, end: date), metrics: [metric], workouts: [])
        let configuration = UploadConfiguration(baseURL: "https://example.com", token: "test", deviceID: "device", appVersion: "1.0.1")
        let engine = SyncEngine(store: store, uploader: APIClient(session: session, maxAttempts: 1))
        _ = try await engine.queue(payload: payload)
        let first = await engine.uploadPending(configuration: configuration)
        XCTAssertEqual(first.failedCount, 1)
        let reopened = try SQLiteLocalStore(url: url)
        let resumed = SyncEngine(store: reopened, uploader: APIClient(session: session, maxAttempts: 1))
        let second = await resumed.uploadPending(configuration: configuration)
        let pending = try await reopened.pendingBatches()
        XCTAssertEqual(second.uploadedCount, 1)
        XCTAssertTrue(pending.isEmpty)
        XCTAssertEqual(count, 2)
        XCTAssertFalse(bodies[0].isEmpty)
        XCTAssertEqual(bodies[0], bodies[1])
        let sent = try PayloadJSON.decoder.decode(SyncPayload.self, from: bodies[1])
        XCTAssertEqual(sent.exportID, payload.exportID)
        XCTAssertEqual(sent.metrics.map(\.id), [metric.id])
    }

    func testSleepPredicateIncludesCrossMidnightSamples() {
        let midnight = Date(timeIntervalSince1970: 1_700_006_400)
        let sample = HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            start: midnight.addingTimeInterval(-3600), end: midnight.addingTimeInterval(6 * 3600))
        let predicate = HealthKitManager.sleepPredicate(start: midnight, end: midnight.addingTimeInterval(24 * 3600))
        XCTAssertTrue(predicate.evaluate(with: sample))
    }
}


final class RawHistoryBackfillTests: XCTestCase {
    func testOnlyBloodOxygenAndHRVBypassDailyStatistics() {
        let manager = HealthKitManager()
        for type in HealthDataType.allCases {
            let summary = manager.backfillAggregationStrategy(for: type, mode: .dailySummary)
            let raw = manager.backfillAggregationStrategy(for: type, mode: .rawSamples)
            if type == .oxygenSaturation || type == .hrvSDNN {
                XCTAssertEqual(summary, .dailyAverage)
                XCTAssertNil(raw)
            } else {
                XCTAssertEqual(raw, summary, "Do not change device-overlap handling for \(type)")
            }
        }
        for type in [HealthDataType.stepCount, .activeEnergy, .distanceWalkingRunning] {
            XCTAssertEqual(manager.backfillAggregationStrategy(for: type, mode: .rawSamples), .dailySum)
        }
        XCTAssertEqual(manager.backfillAggregationStrategy(for: .heartRate, mode: .rawSamples), .dailyAverage)
    }

    func testRawBloodOxygenAndHRVKeepIndividualSamplesAcrossChunkEnd() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw XCTSkip("HealthKit unavailable") }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(60)
        for (type, identifier, unit, values) in [
            (HealthDataType.oxygenSaturation, HKQuantityTypeIdentifier.oxygenSaturation, HKUnit.percent(), [0.96, 0.98]),
            (.hrvSDNN, .heartRateVariabilitySDNN, HKUnit.secondUnit(with: .milli), [25.0, 45.0])
        ] {
            let samples = values.enumerated().map { index, value in
                HKQuantitySample(type: HKQuantityType(identifier), quantity: HKQuantity(unit: unit, doubleValue: value),
                                 start: start.addingTimeInterval(Double(index) * 50),
                                 end: start.addingTimeInterval(Double(index) * 50 + 20),
                                 metadata: ["fixture": "raw-history"])
            }
            var readCount = 0
            let manager = HealthKitManager(backfillPageReader: { requestedType, predicate, anchor, limit in
                readCount += 1
                XCTAssertEqual(requestedType, HKQuantityType(identifier))
                XCTAssertEqual(predicate, HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate]))
                XCTAssertNil(anchor)
                XCTAssertEqual(limit, 100)
                return .init(samples: samples, deletedCount: 0, anchor: HKQueryAnchor(fromValue: 1))
            })
            var records: [HealthQuantitySampleDTO] = []
            try await manager.forEachBackfillBatch(types: [type], start: start, end: end, mode: .rawSamples) {
                records += $0.quantitySamples
            }
            XCTAssertEqual(readCount, 1)
            XCTAssertEqual(records.count, 2)
            for (actual, expected) in zip(records, samples) {
                XCTAssertEqual(actual.uuid, expected.uuid)
                XCTAssertEqual(actual.startAt, expected.startDate)
                XCTAssertEqual(actual.endAt, expected.endDate)
                XCTAssertEqual(actual.sourceName, expected.sourceRevision.source.name)
                XCTAssertEqual(actual.sourceBundleIdentifier, expected.sourceRevision.source.bundleIdentifier)
                XCTAssertEqual(actual.metadata["fixture"], "raw-history")
                XCTAssertNil(actual.metadata["aggregation"])
                XCTAssertEqual(actual.value, expected.quantity.doubleValue(for: unit))
            }
        }
    }

    func testRawPagesAreConsumedBeforeNextReadIncludingDeletionOnlyPages() async throws {
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        var reads = 0
        var consumed = 0
        var retainedIDs = Set<UUID>()
        let manager = HealthKitManager(backfillPageReader: { _, _, anchor, limit in
            XCTAssertEqual(limit, 100)
            reads += 1
            if reads == 1 {
                XCTAssertNil(anchor)
                return .init(samples: [], deletedCount: 100, anchor: HKQueryAnchor(fromValue: 1))
            }
            XCTAssertEqual(consumed, reads - 2, "Read must await previous page's consumer")
            XCTAssertEqual(anchor, HKQueryAnchor(fromValue: reads - 1))
            let count = reads == 2 ? 100 : 3
            let samples = (0..<count).map { _ in
                HKQuantitySample(type: HKQuantityType(.oxygenSaturation), quantity: HKQuantity(unit: .percent(), doubleValue: 0.97), start: at, end: at)
            }
            return .init(samples: samples, deletedCount: 0, anchor: HKQueryAnchor(fromValue: reads))
        })
        try await manager.forEachBackfillBatch(types: [.oxygenSaturation], start: at, end: at.addingTimeInterval(1), mode: .rawSamples) { batch in
            XCTAssertLessThanOrEqual(batch.quantitySamples.count, 100)
            // An actual suspension proves the next query waits for persistence/upload.
            await Task.yield()
            consumed += 1
            for sample in batch.quantitySamples { XCTAssertTrue(retainedIDs.insert(sample.uuid).inserted) }
        }
        XCTAssertEqual(reads, 3)
        XCTAssertEqual(consumed, 2)
        XCTAssertEqual(retainedIDs.count, 103)
    }

    func testConsumerFailureStopsReadingAndIsNotSwallowed() async throws {
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = HKQuantitySample(type: HKQuantityType(.oxygenSaturation), quantity: HKQuantity(unit: .percent(), doubleValue: 0.97), start: at, end: at)
        var reads = 0
        let manager = HealthKitManager(backfillPageReader: { _, _, _, _ in
            reads += 1
            return .init(samples: Array(repeating: sample, count: 100), deletedCount: 0, anchor: HKQueryAnchor(fromValue: reads))
        })
        do {
            try await manager.forEachBackfillBatch(types: [.oxygenSaturation], start: at, end: at.addingTimeInterval(1), mode: .rawSamples) { _ in
                throw HealthKitManagerError.authorizationNotDetermined
            }
            XCTFail("Consumer errors must propagate, even if a HealthKit read would skip that error")
        } catch { XCTAssertTrue(error is HealthKitManagerError) }
        XCTAssertEqual(reads, 1)
    }

    func testMissingPagingAnchorFailsInsteadOfLoopingOrAcknowledging() async throws {
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let manager = HealthKitManager(backfillPageReader: { _, _, _, _ in
            .init(samples: [], deletedCount: 100, anchor: nil)
        })
        do {
            try await manager.forEachBackfillBatch(types: [.oxygenSaturation], start: at, end: at.addingTimeInterval(1), mode: .rawSamples) { _ in XCTFail("No live samples") }
            XCTFail("Missing continuation anchor must fail")
        } catch { XCTAssertTrue(error is HealthKitManagerError) }
    }

    func testCancellationStopsBeforeAnotherPageRead() async throws {
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = HKQuantitySample(type: HKQuantityType(.oxygenSaturation), quantity: HKQuantity(unit: .percent(), doubleValue: 0.97), start: at, end: at)
        var reads = 0
        let manager = HealthKitManager(backfillPageReader: { _, _, _, _ in
            reads += 1
            return .init(samples: Array(repeating: sample, count: 100), deletedCount: 0, anchor: HKQueryAnchor(fromValue: reads))
        })
        let task = Task {
            try await manager.forEachBackfillBatch(types: [.oxygenSaturation], start: at, end: at.addingTimeInterval(1), mode: .rawSamples) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { try await task.value; XCTFail("Cancellation must stop backfill") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(reads, 1)
    }

    func testEmptyWindowsDoNotEmitConsumerBatches() async throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var consumes = 0
        let manager = HealthKitManager(backfillPageReader: { _, _, _, _ in
            .init(samples: [], deletedCount: 0, anchor: HKQueryAnchor(fromValue: 1))
        })
        for window in BackfillSync.chunks(start: start, end: start.addingTimeInterval(365 * 86400)) {
            try await manager.forEachBackfillBatch(types: [.oxygenSaturation, .hrvSDNN], start: window.start, end: window.end, mode: .rawSamples) { _ in
                consumes += 1
            }
        }
        XCTAssertEqual(consumes, 0)
    }

    func testCrossWindowWorkoutAndCategoryKeepTheirFullTimes() async throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let boundary = start.addingTimeInterval(60)
        let end = boundary.addingTimeInterval(60)
        let workout = HKWorkout(activityType: .walking, start: start.addingTimeInterval(30), end: boundary.addingTimeInterval(30))
        let category = HKCategorySample(type: HKCategoryType(.mindfulSession), value: HKCategoryValue.notApplicable.rawValue,
                                        start: start.addingTimeInterval(30), end: boundary.addingTimeInterval(30))
        var reads = 0
        let manager = HealthKitManager(sampleReader: { type, predicate in
            if #available(iOS 18.0, *),
               type == HKQuantityType(.workoutEffortScore) || type == HKQuantityType(.estimatedWorkoutEffortScore) {
                XCTAssertEqual(predicate, HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil))
                return []
            }
            reads += 1
            XCTAssertEqual(predicate, HKQuery.predicateForSamples(withStart: start, end: boundary, options: [.strictStartDate]))
            if type == HKObjectType.workoutType() { return [workout] }
            XCTAssertEqual(type, category.sampleType)
            return [category]
        })
        var workouts: [HealthWorkoutSampleDTO] = []
        var categories: [HealthCategorySampleDTO] = []
        try await manager.forEachBackfillBatch(types: [.workouts, .mindfulSession], start: start, end: boundary, mode: .rawSamples) {
            workouts += $0.workoutSamples; categories += $0.categorySamples
        }
        XCTAssertEqual(reads, 2)
        XCTAssertEqual(workouts.first?.uuid, workout.uuid)
        XCTAssertEqual(workouts.first?.endAt, workout.endDate)
        XCTAssertEqual(categories.first?.uuid, category.uuid)
        XCTAssertEqual(categories.first?.endAt, category.endDate)
        // The real HealthKit predicate, not only the injected reader, assigns each
        // crossing record to exactly one contiguous window.
        let first = HKQuery.predicateForSamples(withStart: start, end: boundary, options: [.strictStartDate])
        let second = HKQuery.predicateForSamples(withStart: boundary, end: end, options: [.strictStartDate])
        for sample in [workout as HKSample, category as HKSample] {
            XCTAssertTrue(first.evaluate(with: sample))
            XCTAssertFalse(second.evaluate(with: sample))
        }
    }
}
