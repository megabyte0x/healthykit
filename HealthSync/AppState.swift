import Foundation
import SwiftUI

enum BusyOperation {
    static func canStart(isBusy: Bool) -> Bool {
        !isBusy
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
    @Published var lastError: String?

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
            hasStoredToken = try hasTokenForCurrentStorageMode()
            hostedAgentToken = try keychain.readHostedAgentToken() ?? ""
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
            try await healthKit.requestReadPermissions(for: settings.selectedTypes)
            settings.hasRequestedHealthPermissions = true
            shouldShowOnboarding = false
            permissionSummary = "Requested"
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
            let existingAgentEndpoint = settings.hostedAgentEndpoint?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let existingAgentToken = hostedAgentToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard existingAgentEndpoint.isEmpty && existingAgentToken.isEmpty else {
                settings.storageMode = .hostedHealthSync
                try await saveSettingsOnly()
                restartPeriodicSync()
                return
            }

            let response = try await APIClient(maxAttempts: 1).provisionHostedWorkspace(
                baseURL: AppSettings.hostedBackendURL,
                label: "Personal Health"
            )
            settings.storageMode = .hostedHealthSync
            settings.backendURL = response.backendURL
            settings.hostedWorkspaceID = response.workspaceID
            settings.hostedAgentEndpoint = response.agentEndpoint
            try keychain.saveHostedIngestToken(response.ingestToken)
            try keychain.saveHostedAgentToken(response.agentToken)
            hostedAgentToken = response.agentToken
            hasStoredToken = true
            try await saveSettingsOnly()
            restartPeriodicSync()
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
        await syncDateRange(start: start, end: end)
    }

    func backfill(start: Date, end: Date) async {
        guard end > start else { return }
        backfillProgress = 0
        await runBusy {
            var cursor = start
            let total = end.timeIntervalSince(start)
            while cursor < end {
                let next = min(cursor.addingTimeInterval(24 * 60 * 60), end)
                try await syncDateRangeThrowing(start: cursor, end: next)
                cursor = next
                backfillProgress = min(1, cursor.timeIntervalSince(start) / total)
            }
            backfillProgress = 1
        }
    }

    func syncIncremental() async {
        await runBusy {
            guard let store, let syncEngine else { throw APIClientError.invalidResponse }
            try await ensureHealthPermissionsRequested()
            var anchors: [HealthDataType: String] = [:]
            for type in settings.selectedTypes {
                if let anchor = try await store.loadAnchor(for: type) {
                    anchors[type] = anchor
                }
            }
            let result = try await healthKit.fetchIncremental(types: settings.selectedTypes, anchors: anchors)
            guard !result.fetchResult.isEmpty else {
                try await store.appendLog(SyncLogEntry(level: .info, message: "No new HealthKit samples found."))
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
                workoutSamples: result.fetchResult.workoutSamples
            )
            try await syncEngine.queue(payload: payload)
            for (type, anchor) in result.anchors {
                try await store.saveAnchor(anchor, for: type)
            }
            _ = await syncEngine.uploadPending(configuration: try await uploadConfiguration())
            await refresh()
        }
    }

    private func syncDateRange(start: Date, end: Date) async {
        await runBusy {
            try await syncDateRangeThrowing(start: start, end: end)
        }
    }

    private func syncDateRangeThrowing(start: Date, end: Date) async throws {
        guard let store, let syncEngine else { throw APIClientError.invalidResponse }
        try await ensureHealthPermissionsRequested()
        let fetchResult = try await healthKit.fetchSamples(types: settings.selectedTypes, start: start, end: end)
        let payload = try normalizer.payload(
            deviceID: try await store.deviceID(),
            dateRange: SyncDateRange(start: start, end: end),
            timezone: TimeZone.current.identifier,
            quantitySamples: fetchResult.quantitySamples,
            sleepSamples: fetchResult.sleepSamples,
            workoutSamples: fetchResult.workoutSamples
        )
        try await syncEngine.queue(payload: payload)
        let result = await syncEngine.uploadPending(configuration: try await uploadConfiguration())
        if result.failedCount > 0 {
            lastError = result.messages.last
        }
        await refresh()
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
        guard let token = try readUploadToken(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIClientError.missingToken
        }
        return UploadConfiguration(
            baseURL: settings.effectiveBackendURL,
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
        guard let interval = settings.syncFrequency.intervalSeconds else { return }
        periodicSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
                await self?.syncIncremental()
            }
        }
    }

    private func runBusy(_ operation: () async throws -> Void) async {
        guard BusyOperation.canStart(isBusy: isBusy) else { return }
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            try await operation()
            await refresh()
        } catch {
            let message = userMessage(from: error)
            lastError = message
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
