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
