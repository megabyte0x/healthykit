import XCTest
@testable import HealthSync

final class HealthNormalizerTests: XCTestCase {
    func testQuantitySampleUsesHealthKitUUIDAsStableID() throws {
        let uuid = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(300)
        let sample = HealthQuantitySampleDTO(
            uuid: uuid,
            type: .stepCount,
            value: 1234,
            unit: .count,
            startAt: start,
            endAt: end,
            sourceName: "iPhone",
            sourceBundleIdentifier: "com.apple.Health",
            metadata: [:]
        )

        let metric = try HealthNormalizer().metrics(from: [sample]).single()

        XCTAssertEqual(metric.id, "healthkit:\(uuid.uuidString)")
        XCTAssertEqual(metric.type, "step_count")
        XCTAssertEqual(metric.value, 1234)
        XCTAssertEqual(metric.unit, "count")
        XCTAssertEqual(metric.sourceName, "iPhone")
        XCTAssertEqual(metric.sourceBundleID, "com.apple.Health")
    }

    func testAggregatedQuantitySampleUsesDeterministicAggregateID() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(86_400)
        let sample = HealthQuantitySampleDTO(
            uuid: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            type: .stepCount,
            value: 12_345,
            unit: .count,
            startAt: start,
            endAt: end,
            sourceName: "Apple Health",
            sourceBundleIdentifier: nil,
            metadata: ["aggregation": "daily_sum"],
            stableIDOverride: "healthkit:aggregate:step_count:2023-11-14"
        )

        let metric = try HealthNormalizer().metrics(from: [sample]).single()

        XCTAssertEqual(metric.id, "healthkit:aggregate:step_count:2023-11-14")
        XCTAssertEqual(metric.metadata["aggregation"], "daily_sum")
    }

    func testUnitConversionsUseBackendUnits() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(60)
        let heartRate = HealthQuantitySampleDTO(
            uuid: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            type: .heartRate,
            value: 1.5,
            unit: .countPerSecond,
            startAt: start,
            endAt: end,
            sourceName: "Apple Watch",
            sourceBundleIdentifier: nil,
            metadata: [:]
        )
        let activeEnergy = HealthQuantitySampleDTO(
            uuid: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
            type: .activeEnergy,
            value: 4_184,
            unit: .joule,
            startAt: start,
            endAt: end,
            sourceName: "Apple Watch",
            sourceBundleIdentifier: nil,
            metadata: [:]
        )
        let water = HealthQuantitySampleDTO(
            uuid: UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-000000000000")!,
            type: .water,
            value: 0.75,
            unit: .liter,
            startAt: start,
            endAt: end,
            sourceName: "Water App",
            sourceBundleIdentifier: nil,
            metadata: [:]
        )

        let metrics = try HealthNormalizer().metrics(from: [heartRate, activeEnergy, water])

        XCTAssertEqual(metrics[0].value, 90, accuracy: 0.001)
        XCTAssertEqual(metrics[0].unit, "count/min")
        XCTAssertEqual(metrics[1].value, 1, accuracy: 0.001)
        XCTAssertEqual(metrics[1].unit, "kcal")
        XCTAssertEqual(metrics[2].value, 750, accuracy: 0.001)
        XCTAssertEqual(metrics[2].unit, "mL")
    }

    func testAdditionalHealthKitQuantityUnitsPassThroughBackendUnits() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(60)
        let glucose = HealthQuantitySampleDTO(
            uuid: UUID(uuidString: "DDDDDDDD-EEEE-FFFF-0000-111111111111")!,
            type: .bloodGlucose,
            value: 92,
            unit: .milligramPerDeciliter,
            startAt: start,
            endAt: end,
            sourceName: "Glucose Meter",
            sourceBundleIdentifier: nil,
            metadata: [:]
        )
        let vo2Max = HealthQuantitySampleDTO(
            uuid: UUID(uuidString: "EEEEEEEE-FFFF-0000-1111-222222222222")!,
            type: .vo2Max,
            value: 42.5,
            unit: .milliliterPerKilogramMinute,
            startAt: start,
            endAt: end,
            sourceName: "Apple Watch",
            sourceBundleIdentifier: nil,
            metadata: [:]
        )

        let metrics = try HealthNormalizer().metrics(from: [glucose, vo2Max])

        XCTAssertEqual(metrics[0].type, "blood_glucose")
        XCTAssertEqual(metrics[0].value, 92, accuracy: 0.001)
        XCTAssertEqual(metrics[0].unit, "mg/dL")
        XCTAssertEqual(metrics[1].type, "vo2_max")
        XCTAssertEqual(metrics[1].value, 42.5, accuracy: 0.001)
        XCTAssertEqual(metrics[1].unit, "mL/kg/min")
    }

    func testCategorySamplesEncodeAsMetrics() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(120)
        let sample = HealthCategorySampleDTO(
            uuid: UUID(uuidString: "FFFFFFFF-0000-1111-2222-333333333333")!,
            type: .mindfulSession,
            value: 0,
            valueLabel: "not_applicable",
            startAt: start,
            endAt: end,
            sourceName: "Mindfulness",
            sourceBundleIdentifier: "com.example.mindful",
            metadata: ["source": "test"]
        )

        let metric = try HealthNormalizer().categoryMetrics(from: [sample]).single()

        XCTAssertEqual(metric.id, "healthkit:\(sample.uuid.uuidString)")
        XCTAssertEqual(metric.type, "mindful_session")
        XCTAssertEqual(metric.value, 0)
        XCTAssertEqual(metric.unit, "category_value")
        XCTAssertEqual(metric.metadata["category_value"], "0")
        XCTAssertEqual(metric.metadata["category_label"], "not_applicable")
    }

    func testSleepCategorySamplesKeepDurationMetricContract() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3_600)
        let sample = HealthCategorySampleDTO(
            uuid: UUID(uuidString: "00000000-1111-2222-3333-444444444444")!,
            type: .sleepAnalysis,
            value: 3,
            valueLabel: "asleep_deep",
            startAt: start,
            endAt: end,
            sourceName: "Apple Watch",
            sourceBundleIdentifier: nil,
            metadata: [:]
        )

        let metric = try HealthNormalizer().categoryMetrics(from: [sample]).single()

        XCTAssertEqual(metric.type, "sleep_analysis")
        XCTAssertEqual(metric.value, 3_600)
        XCTAssertEqual(metric.unit, "seconds")
        XCTAssertEqual(metric.metadata["sleep_stage"], "asleep_deep")
    }

    func testPayloadEncodingUsesSnakeCaseContract() throws {
        let payload = SyncPayload(
            deviceID: "device-123",
            exportID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            timezone: "Asia/Kolkata",
            source: "ios-healthkit",
            schemaVersion: 1,
            dateRange: SyncDateRange(
                start: Date(timeIntervalSince1970: 1_699_913_600),
                end: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            metrics: [
                HealthMetric(
                    id: "healthkit:sample",
                    type: "step_count",
                    value: 10,
                    unit: "count",
                    startAt: Date(timeIntervalSince1970: 1_699_913_600),
                    endAt: Date(timeIntervalSince1970: 1_700_000_000),
                    sourceName: "iPhone",
                    sourceBundleID: "com.apple.Health",
                    metadata: [:]
                )
            ],
            workouts: []
        )

        let json = try String(data: PayloadJSON.encoder.encode(payload), encoding: .utf8).unwrap()

        XCTAssertTrue(json.contains("\"device_id\":\"device-123\""))
        XCTAssertTrue(json.contains("\"export_id\":\"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE\""))
        XCTAssertTrue(json.contains("\"schema_version\":1"))
        XCTAssertTrue(json.contains("\"source_bundle_id\":\"com.apple.Health\""))
        XCTAssertFalse(json.contains("deviceID"))
        XCTAssertFalse(json.contains("sourceBundleID"))
    }
}

private extension Array {
    func single(file: StaticString = #filePath, line: UInt = #line) throws -> Element {
        XCTAssertEqual(count, 1, file: file, line: line)
        return self[0]
    }
}

private extension Optional {
    func unwrap(file: StaticString = #filePath, line: UInt = #line) throws -> Wrapped {
        guard let value = self else {
            XCTFail("Expected value", file: file, line: line)
            throw NSError(domain: "HealthSyncTests", code: 1)
        }
        return value
    }
}
