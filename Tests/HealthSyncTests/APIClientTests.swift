import XCTest
import HealthKit
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

final class HealthKitManagerErrorTests: XCTestCase {
    func testAuthorizationNotDeterminedMessageTellsUserToConnectAppleHealth() {
        XCTAssertEqual(
            HealthKitManagerError.authorizationNotDetermined.errorDescription,
            "Apple Health permissions are not set up yet. Tap Connect Apple Health and allow the requested read permissions."
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
        XCTAssertEqual(presentation.connectButtonTitle, "Connect Apple Health")
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
    }

    func testExistingHostedStorageOffersRefreshAction() {
        let presentation = HostedStorageSetupPresentation(
            isBusy: false,
            backendURL: "https://api.example.com",
            lastError: nil,
            hostedAgentEndpoint: "https://api.example.com/api/agent/health-data",
            hostedAgentToken: "agent-token"
        )

        XCTAssertEqual(presentation.createButtonTitle, "Refresh Hosted Storage")
        XCTAssertEqual(presentation.createButtonSystemImage, "arrow.clockwise")
    }
}
