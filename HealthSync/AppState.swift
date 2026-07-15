import Foundation
import SwiftUI

enum HealthSyncUserMessages {
    static let noNewSamplesFound = "No new Apple Health samples found."
    static let noSamplesFoundForDateRange = "No Apple Health samples found for this date range."

    static func displayLogMessage(_ message: String) -> String {
        message
            .replacingOccurrences(of: "No new HealthKit samples found.", with: noNewSamplesFound)
            .replacingOccurrences(of: "No HealthKit samples found for this date range.", with: noSamplesFoundForDateRange)
    }
}

struct HealthActionFeedback: Equatable {
    enum Kind: Equatable {
        case success
        case info
        case error
    }

    let kind: Kind
    let message: String

    static let permissionRequested = HealthActionFeedback(
        kind: .success,
        message: "Health access request completed. You can change access at any time in iPhone Settings."
    )
    static let noSamples = HealthActionFeedback(
        kind: .info,
        message: "No health samples were found for the last 24 hours."
    )
    static let syncCompleted = HealthActionFeedback(
        kind: .success,
        message: "The last 24 hours were synced successfully."
    )

    static func failure(_ message: String) -> HealthActionFeedback {
        HealthActionFeedback(kind: .error, message: message)
    }
}

enum DevelopmentKeychainBypass {
    static var isEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func hasStoredToken(readProductionTokenState: () throws -> Bool) throws -> Bool {
        guard !isEnabled else { return true }
        return try readProductionTokenState()
    }

    static func hostedAgentToken(readProductionToken: () throws -> String?) throws -> String {
        guard !isEnabled else { return "" }
        return try readProductionToken() ?? ""
    }
}

enum BusyOperation {
    static func canStart(isBusy: Bool) -> Bool {
        !isBusy
    }
}

enum UploadDestinationPreparation: Equatable {
    case ready
    case provisionHostedStorage

    static func resolve(
        storageMode: StorageMode,
        hasAgentEndpoint: Bool,
        hasAgentToken: Bool,
        hasIngestToken: Bool
    ) -> UploadDestinationPreparation {
        guard storageMode == .hostedHealthSync else { return .ready }
        return hasAgentEndpoint && hasAgentToken && hasIngestToken
            ? .ready
            : .provisionHostedStorage
    }
}

enum BackfillSyncError: LocalizedError, Equatable {
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case let .uploadFailed(message):
            message
        }
    }
}

enum BackfillSync {
    private static let chunkLength: TimeInterval = 30 * 24 * 60 * 60
    private static let maxRecordsPerUpload = 100

    static func chunks(start: Date, end: Date) -> [SyncDateRange] {
        guard end > start else { return [] }

        var ranges: [SyncDateRange] = []
        var cursor = start
        while cursor < end {
            let next = min(cursor.addingTimeInterval(chunkLength), end)
            ranges.append(SyncDateRange(start: cursor, end: next))
            cursor = next
        }
        return ranges
    }

    static func validateUpload(_ result: SyncRunResult) throws {
        guard result.failedCount == 0 else {
            throw BackfillSyncError.uploadFailed(result.messages.last ?? "Backfill upload failed.")
        }
    }

    static func shouldUpload(_ payload: SyncPayload) -> Bool {
        !payload.isEmpty
    }

    static func uploadPayloads(for payload: SyncPayload) -> [SyncPayload] {
        payload.chunked(maxRecords: maxRecordsPerUpload)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var shouldShowOnboarding = true
    @Published var settings = AppSettings.default
    @Published var status = SyncStatus.empty
    @Published var logs: [SyncLogEntry] = []
    @Published var permissionSummary = "Not requested"
    @Published var authTokenDraft = ""
    @Published var hostedAgentToken = ""
    @Published var hasStoredToken = false
    @Published var isBusy = false
    @Published var backfillProgress = 0.0
    @Published var backfillError: String?
    @Published var lastError: String?
    @Published var actionFeedback: HealthActionFeedback?

    private var store: SQLiteLocalStore?
    private var syncEngine: SyncEngine?
    private let healthKit = HealthKitManager()
    private let normalizer = HealthNormalizer()
    private let keychain = KeychainStore()
    private var periodicSyncTask: Task<Void, Never>?

    func bootstrap() async {
        do {
            let localStore = try SQLiteLocalStore()
            store = localStore
            syncEngine = SyncEngine(store: localStore)
            settings = try await localStore.loadSettings()
            hasStoredToken = try DevelopmentKeychainBypass.hasStoredToken {
                try hasTokenForCurrentStorageMode()
            }
            hostedAgentToken = try DevelopmentKeychainBypass.hostedAgentToken {
                try keychain.readHostedAgentToken()
            }
            shouldShowOnboarding = !settings.hasRequestedHealthPermissions
            permissionSummary = healthKit.isHealthDataAvailable
                ? (settings.hasRequestedHealthPermissions ? "Requested" : "Not requested")
                : "Unavailable"
            try await localStore.pruneUploaded(olderThan: Date().addingTimeInterval(-7 * 24 * 60 * 60))
            await refresh()
            startObserversIfPossible()
            restartPeriodicSync()
        } catch {
            lastError = userMessage(from: error)
        }
    }

    func refresh() async {
        guard let store else { return }
        do {
            status = try await store.syncStatus()
            logs = try await store.recentLogs()
        } catch {
            lastError = userMessage(from: error)
        }
    }

    func connectAppleHealth() async {
        await runBusy {
            try await prepareHostedStorageIfNeeded()
            try await healthKit.requestReadPermissions(for: settings.selectedTypes)
            settings.hasRequestedHealthPermissions = true
            shouldShowOnboarding = false
            permissionSummary = "Requested"
            actionFeedback = .permissionRequested
            try await saveSettingsOnly()
            startObserversIfPossible()
        }
    }

    func set(type: HealthDataType, enabled: Bool) {
        if enabled {
            settings.selectedTypes.insert(type)
        } else {
            settings.selectedTypes.remove(type)
        }
    }

    func saveSettingsAndToken() async {
        await runBusy {
            try await saveSettingsOnly()
            if !authTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try keychain.saveToken(authTokenDraft)
                authTokenDraft = ""
                hasStoredToken = true
            }
            startObserversIfPossible()
            restartPeriodicSync()
        }
    }

    func createHostedStorage() async {
        await runBusy {
            try await prepareHostedStorageIfNeeded()
            restartPeriodicSync()
        }
    }

    func resetHostedStorage() async {
        await runBusy {
            let client = APIClient(maxAttempts: 1)
            let label = "Personal Health"
            let ingestToken = (try keychain.readHostedIngestToken() ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let response: HostedWorkspaceProvisioningResponse

            if ingestToken.isEmpty {
                response = try await client.provisionHostedWorkspace(
                    baseURL: AppSettings.hostedBackendURL,
                    label: label
                )
            } else {
                do {
                    response = try await client.resetHostedWorkspace(
                        baseURL: AppSettings.hostedBackendURL,
                        token: ingestToken,
                        label: label
                    )
                } catch APIClientError.authRejected {
                    response = try await client.provisionHostedWorkspace(
                        baseURL: AppSettings.hostedBackendURL,
                        label: label
                    )
                }
            }

            try await applyHostedWorkspace(response)
            restartPeriodicSync()
        }
    }

    func refreshHostedAgentToken() async {
        await runBusy {
            let ingestToken = (try keychain.readHostedIngestToken() ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ingestToken.isEmpty else { throw APIClientError.missingToken }

            let response = try await APIClient(maxAttempts: 1).refreshHostedAgentToken(
                baseURL: AppSettings.hostedBackendURL,
                token: ingestToken
            )
            settings.storageMode = .hostedHealthSync
            settings.hostedWorkspaceID = response.workspaceID
            settings.hostedAgentEndpoint = response.agentEndpoint
            try keychain.saveHostedAgentToken(response.agentToken)
            hostedAgentToken = response.agentToken
            hasStoredToken = true
            try await saveSettingsOnly()
        }
    }

    private func applyHostedWorkspace(_ response: HostedWorkspaceProvisioningResponse) async throws {
        settings.storageMode = .hostedHealthSync
        settings.backendURL = response.backendURL
        settings.hostedWorkspaceID = response.workspaceID
        settings.hostedAgentEndpoint = response.agentEndpoint
        try keychain.saveHostedIngestToken(response.ingestToken)
        try keychain.saveHostedAgentToken(response.agentToken)
        hostedAgentToken = response.agentToken
        hasStoredToken = true
        try await saveSettingsOnly()
    }

    private func prepareHostedStorageIfNeeded() async throws {
        guard settings.storageMode == .hostedHealthSync else { return }

        let existingAgentEndpoint = settings.hostedAgentEndpoint?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let existingAgentToken = hostedAgentToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingIngestToken = (try keychain.readHostedIngestToken() ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch UploadDestinationPreparation.resolve(
            storageMode: settings.storageMode,
            hasAgentEndpoint: !existingAgentEndpoint.isEmpty,
            hasAgentToken: !existingAgentToken.isEmpty,
            hasIngestToken: !existingIngestToken.isEmpty
        ) {
        case .ready:
            if settings.storageMode == .hostedHealthSync {
                hasStoredToken = true
                try await saveSettingsOnly()
            }
        case .provisionHostedStorage:
            let response = try await APIClient(maxAttempts: 1).provisionHostedWorkspace(
                baseURL: AppSettings.hostedBackendURL,
                label: "Personal Health"
            )
            try await applyHostedWorkspace(response)
        }
    }

    func testConnection() async {
        await runBusy {
            guard let store else { throw APIClientError.invalidResponse }
            let configuration = try await uploadConfiguration()
            let now = Date()
            let payload = SyncPayload.empty(
                deviceID: try await store.deviceID(),
                dateRange: SyncDateRange(start: now, end: now),
                timezone: TimeZone.current.identifier
            )
            let result = try await APIClient(maxAttempts: 1).upload(batch: SyncBatch(payload: payload), configuration: configuration)
            try await store.appendLog(
                SyncLogEntry(level: .success, message: "Connection accepted (\(result.received) received, \(result.duplicates) duplicates).")
            )
            await refresh()
        }
    }

    func syncLast24Hours() async {
        let end = Date()
        let start = end.addingTimeInterval(-24 * 60 * 60)
        await runBusy {
            try await prepareHostedStorageIfNeeded()
            let uploaded = try await syncDateRangeThrowing(start: start, end: end)
            actionFeedback = uploaded ? .syncCompleted : .noSamples
        }
    }

    func backfill(start: Date, end: Date) async {
        guard end > start else { return }
        backfillProgress = 0
        backfillError = nil
        await runBusy {
            try await prepareHostedStorageIfNeeded()
            let chunks = BackfillSync.chunks(start: start, end: end)
            let total = Double(chunks.count)
            for (index, chunk) in chunks.enumerated() {
                do {
                    _ = try await syncDateRangeThrowing(
                        start: chunk.start,
                        end: chunk.end,
                        refreshAfterUpload: false,
                        optimizedBackfill: true
                    )
                } catch {
                    backfillError = userMessage(from: error)
                    throw error
                }
                backfillProgress = min(1, Double(index + 1) / total)
            }
            backfillProgress = 1
            await refresh()
        }
    }

    func syncIncremental() async {
        await runBusy {
            guard let store, let syncEngine else { throw APIClientError.invalidResponse }
            try await ensureHealthPermissionsRequested()
            let configuration = try await uploadConfiguration()
            var anchors: [HealthDataType: String] = [:]
            for type in settings.selectedTypes {
                if let anchor = try await store.loadAnchor(for: type) {
                    anchors[type] = anchor
                }
            }
            let result = try await healthKit.fetchIncremental(types: settings.selectedTypes, anchors: anchors)
            guard !result.fetchResult.isEmpty else {
                try await store.appendLog(SyncLogEntry(level: .info, message: HealthSyncUserMessages.noNewSamplesFound))
                await refresh()
                return
            }
            let deviceID = try await store.deviceID()
            let now = Date()
            let payload = try normalizer.payload(
                deviceID: deviceID,
                dateRange: SyncDateRange(start: now, end: now),
                timezone: TimeZone.current.identifier,
                quantitySamples: result.fetchResult.quantitySamples,
                sleepSamples: result.fetchResult.sleepSamples,
                categorySamples: result.fetchResult.categorySamples,
                workoutSamples: result.fetchResult.workoutSamples
            )
            let batch = try await syncEngine.queue(payload: payload)
            for (type, anchor) in result.anchors {
                try await store.saveAnchor(anchor, for: type)
            }
            _ = await syncEngine.uploadQueuedBatch(batch, configuration: configuration)
            await refresh()
        }
    }

    private func syncDateRangeThrowing(
        start: Date,
        end: Date,
        refreshAfterUpload: Bool = true,
        optimizedBackfill: Bool = false
    ) async throws -> Bool {
        guard let store, let syncEngine else { throw APIClientError.invalidResponse }
        try await ensureHealthPermissionsRequested()
        let configuration = try await uploadConfiguration()
        let fetchResult = try await (optimizedBackfill
            ? healthKit.fetchBackfillSamples(types: settings.selectedTypes, start: start, end: end)
            : healthKit.fetchSamples(types: settings.selectedTypes, start: start, end: end))
        let payload = try normalizer.payload(
            deviceID: try await store.deviceID(),
            dateRange: SyncDateRange(start: start, end: end),
            timezone: TimeZone.current.identifier,
            quantitySamples: fetchResult.quantitySamples,
            sleepSamples: fetchResult.sleepSamples,
            categorySamples: fetchResult.categorySamples,
            workoutSamples: fetchResult.workoutSamples
        )
        guard BackfillSync.shouldUpload(payload) else {
            try await store.appendLog(SyncLogEntry(level: .info, message: HealthSyncUserMessages.noSamplesFoundForDateRange))
            if refreshAfterUpload {
                await refresh()
            }
            return false
        }
        for uploadPayload in BackfillSync.uploadPayloads(for: payload) {
            let batch = try await syncEngine.queue(payload: uploadPayload)
            let result = await syncEngine.uploadQueuedBatch(batch, configuration: configuration)
            try BackfillSync.validateUpload(result)
        }
        if refreshAfterUpload {
            await refresh()
        }
        return true
    }

    private func saveSettingsOnly() async throws {
        guard let store else { throw APIClientError.invalidResponse }
        try await store.saveSettings(settings)
    }

    private func ensureHealthPermissionsRequested() async throws {
        guard !settings.hasRequestedHealthPermissions else { return }
        try await healthKit.requestReadPermissions(for: settings.selectedTypes)
        settings.hasRequestedHealthPermissions = true
        shouldShowOnboarding = false
        permissionSummary = "Requested"
        try await saveSettingsOnly()
        startObserversIfPossible()
    }

    private func uploadConfiguration() async throws -> UploadConfiguration {
        guard let store else { throw APIClientError.invalidResponse }
        let baseURL = settings.effectiveBackendURL
        _ = try APIClient.validatedRootURL(from: baseURL)
        guard let token = try readUploadToken(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIClientError.missingToken
        }
        return UploadConfiguration(
            baseURL: baseURL,
            token: token,
            deviceID: try await store.deviceID(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }

    private func readUploadToken() throws -> String? {
        switch settings.storageMode {
        case .customBackend:
            try keychain.readToken()
        case .hostedHealthSync:
            try keychain.readHostedIngestToken()
        }
    }

    private func hasTokenForCurrentStorageMode() throws -> Bool {
        let token = try readUploadToken()
        return !(token ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startObserversIfPossible() {
        guard settings.hasRequestedHealthPermissions else { return }
        guard hasUsableUploadConfiguration() else { return }
        do {
            try healthKit.startObserverQueries(types: settings.selectedTypes) { [weak self] _ in
                Task { @MainActor in
                    await self?.syncIncremental()
                }
            }
        } catch {
            lastError = userMessage(from: error)
        }
    }

    private func restartPeriodicSync() {
        periodicSyncTask?.cancel()
        guard hasUsableUploadConfiguration() else { return }
        guard let interval = settings.syncFrequency.intervalSeconds else { return }
        periodicSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
                await self?.syncIncremental()
            }
        }
    }

    private func hasUsableUploadConfiguration() -> Bool {
        guard (try? APIClient.validatedRootURL(from: settings.effectiveBackendURL)) != nil else {
            return false
        }
        return (try? hasTokenForCurrentStorageMode()) == true
    }

    private func runBusy(_ operation: () async throws -> Void) async {
        guard BusyOperation.canStart(isBusy: isBusy) else { return }
        isBusy = true
        lastError = nil
        actionFeedback = nil
        defer { isBusy = false }
        do {
            try await operation()
            await refresh()
        } catch {
            let message = userMessage(from: error)
            lastError = message
            actionFeedback = .failure(message)
            if let store {
                try? await store.appendLog(SyncLogEntry(level: .error, message: message))
                await refresh()
            }
        }
    }

    private func userMessage(from error: Error) -> String {
        if let apiError = error as? APIClientError {
            return apiError.userMessage
        }
        return error.localizedDescription
    }
}
