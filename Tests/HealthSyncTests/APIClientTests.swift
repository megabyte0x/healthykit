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
}

final class AppSettingsHostedEndpointTests: XCTestCase {
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

final class HostedStorageSetupPresentationTests: XCTestCase {
    func testCreatingStateShowsProgressAndDisablesCreateButton() {
        let presentation = HostedStorageSetupPresentation(
            isBusy: true,
            backendURL: "https://api.example.com",
            lastError: nil,
            hostedAgentEndpoint: nil,
            hostedAgentToken: ""
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
            hostedAgentToken: ""
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
            hostedAgentToken: ""
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
            hostedAgentToken: ""
        )

        XCTAssertEqual(presentation.feedbackMessage, "Hosted storage is ready.")
        XCTAssertEqual(presentation.feedbackKind, .success)
        XCTAssertEqual(presentation.createButtonTitle, "Hosted Storage Created")
        XCTAssertEqual(presentation.createButtonSystemImage, "checkmark.circle")
        XCTAssertTrue(presentation.isCreateButtonDisabled)
    }
}
