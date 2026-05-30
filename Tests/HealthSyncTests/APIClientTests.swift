import XCTest
@testable import HealthSync

final class APIClientTests: XCTestCase {
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
    }
}

final class SupportDevelopmentPromptTests: XCTestCase {
    func testPromptUsesZcashOnlySupportDetails() {
        let prompt = SupportDevelopmentPrompt.current

        XCTAssertEqual(prompt.paymentMethodLabel, "ZEC")
        XCTAssertEqual(prompt.message, "Support the application development by paying some ZEC.")
        XCTAssertFalse(prompt.message.contains("$"))
        XCTAssertFalse(prompt.message.contains("10"))
        XCTAssertEqual(
            prompt.zcashAddress,
            "u1cyxqx2za9c7g2h7tjz0nn7rdf5fgykmqgw4eke7fvfa9pd7lynjkqfeq4hzd3tkys4pvku5xnmmwclm77jv9ljkhdefrvzc6pgehc63rcnmylqlxt0fmz55t6wdp6dyk5w2hzx06hs93xun5smexvwn04ju4ppy54gx477ftequajh0t"
        )
    }
}
