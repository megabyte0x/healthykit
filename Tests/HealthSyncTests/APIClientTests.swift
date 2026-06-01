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
    func testDefaultSettingsSelectEverySupportedHealthDataType() {
        XCTAssertEqual(AppSettings.default.selectedTypes, Set(HealthDataType.allCases))
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

final class HealthPermissionSettingsPresentationTests: XCTestCase {
    func testNotRequestedStateOffersAppleHealthApproval() {
        let presentation = HealthPermissionSettingsPresentation(
            permissionSummary: "Not requested",
            isBusy: false
        )

        XCTAssertEqual(presentation.approvalButtonTitle, "Ask Apple Health for Approval")
        XCTAssertEqual(presentation.approvalButtonSystemImage, "heart.text.square.fill")
        XCTAssertFalse(presentation.isApprovalButtonDisabled)
        XCTAssertFalse(presentation.showsSettingsButton)
    }

    func testAlreadyRequestedStateOffersApprovalRetryAndSettingsRecovery() {
        let presentation = HealthPermissionSettingsPresentation(
            permissionSummary: "Requested",
            isBusy: false
        )

        XCTAssertEqual(presentation.approvalButtonTitle, "Ask Apple Health for Approval Again")
        XCTAssertTrue(presentation.showsSettingsButton)
        XCTAssertEqual(presentation.settingsButtonTitle, "Open App Settings")
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
