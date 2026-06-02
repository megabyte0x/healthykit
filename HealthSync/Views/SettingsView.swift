import SwiftUI
import UIKit

struct SupportDevelopmentPrompt: Equatable {
    let paymentMethodLabel: String
    let zcashAddress: String

    var message: String {
        "Support continued HealthSync development with \(paymentMethodLabel)."
    }

    static let current = SupportDevelopmentPrompt(
        paymentMethodLabel: "ZEC",
        zcashAddress: "u1cyxqx2za9c7g2h7tjz0nn7rdf5fgykmqgw4eke7fvfa9pd7lynjkqfeq4hzd3tkys4pvku5xnmmwclm77jv9ljkhdefrvzc6pgehc63rcnmylqlxt0fmz55t6wdp6dyk5w2hzx06hs93xun5smexvwn04ju4ppy54gx477ftequajh0t"
    )
}

enum HostedStorageFeedbackKind: Equatable {
    case none
    case info
    case success
    case error
}

struct HostedStorageSetupPresentation: Equatable {
    let isBusy: Bool
    let backendURL: String
    let lastError: String?
    let hostedAgentEndpoint: String?
    let hostedAgentToken: String
    let hasStoredUploadToken: Bool

    var createButtonTitle: String {
        if isBusy {
            return "Creating Hosted Storage..."
        }
        if hasUsableHostedStorage {
            return "Hosted Storage Created"
        }
        return hasAgentAccess ? "Refresh Hosted Storage" : "Create Hosted Storage"
    }

    var createButtonSystemImage: String {
        if isBusy {
            return "hourglass"
        }
        if hasUsableHostedStorage {
            return "checkmark.circle"
        }
        return hasAgentAccess ? "arrow.clockwise" : "externaldrive.badge.plus"
    }

    var isCreateButtonDisabled: Bool {
        isBusy || hasUsableHostedStorage
    }

    var showsResetButton: Bool {
        hasAgentAccess || hasStoredUploadToken
    }

    var resetButtonTitle: String {
        hasUsableHostedStorage ? "Reset Hosted Storage" : "Create Hosted Storage Again"
    }

    var isResetButtonDisabled: Bool {
        isBusy
    }

    var progressMessage: String? {
        isBusy ? "Creating hosted storage..." : nil
    }

    var feedbackMessage: String? {
        if let errorMessage = trimmed(lastError), !errorMessage.isEmpty {
            return errorMessage
        }

        if hasUsableHostedStorage {
            return "Hosted storage is ready."
        }
        if hasAgentAccess {
            return "Hosted storage needs refresh before uploads can reach the agent endpoint."
        }

        return nil
    }

    var feedbackKind: HostedStorageFeedbackKind {
        if let errorMessage = trimmed(lastError), !errorMessage.isEmpty {
            return .error
        }

        if hasUsableHostedStorage {
            return .success
        }
        if hasAgentAccess {
            return .info
        }

        return .none
    }

    private var hasAgentAccess: Bool {
        !(trimmed(hostedAgentEndpoint) ?? "").isEmpty || !(trimmed(hostedAgentToken) ?? "").isEmpty
    }

    private var hasUsableHostedStorage: Bool {
        hasAgentAccess && hasStoredUploadToken
    }

    private func trimmed(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct HealthPermissionSettingsPresentation: Equatable {
    let permissionSummary: String
    let isBusy: Bool

    var approvalButtonTitle: String {
        "Review Apple Health Access"
    }

    var approvalButtonSystemImage: String {
        isBusy ? "hourglass" : "heart.text.square.fill"
    }

    var isApprovalButtonDisabled: Bool {
        isBusy || permissionSummary == "Unavailable"
    }

    var showsSettingsButton: Bool {
        permissionSummary == "Requested"
    }

    var settingsButtonTitle: String {
        "Open iPhone Settings"
    }
}

struct SettingsOverviewPresentation: Equatable {
    let storageMode: StorageMode
    let permissionSummary: String
    let selectedHealthDataCount: Int
    let totalHealthDataCount: Int
    let hasStoredUploadToken: Bool

    var storageLabel: String {
        switch storageMode {
        case .customBackend:
            "Custom backend"
        case .hostedHealthSync:
            "Hosted storage"
        }
    }

    var storageDetail: String {
        switch storageMode {
        case .customBackend:
            "Uploads use your configured endpoint."
        case .hostedHealthSync:
            "Uploads use managed HealthSync storage."
        }
    }

    var permissionLabel: String {
        switch permissionSummary {
        case "Requested":
            "Apple Health ready"
        case "Unavailable":
            "Apple Health unavailable"
        default:
            "Apple Health not set"
        }
    }

    var healthDataSummary: String {
        "\(selectedHealthDataCount) of \(totalHealthDataCount) selected"
    }

    var tokenLabel: String {
        hasStoredUploadToken ? "Token saved" : "Token needed"
    }
}

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @State private var isSupportPromptPresented = false
    @State private var isResetHostedStorageConfirmationPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                HealthSyncTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        settingsHeader
                        overviewCard
                        storageDestinationCard
                        manualBackendCard
                        appleHealthCard
                        agentAccessCard
                        healthDataCard
                        syncControlsCard

                        Color.clear
                            .frame(height: 96)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .safeAreaPadding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSupportPromptPresented = true
                    } label: {
                        Image(systemName: "heart.circle.fill")
                            .font(.title3)
                            .foregroundStyle(HealthSyncTheme.primaryRed)
                    }
                    .accessibilityIdentifier("support-development-button")
                }
            }
            .sheet(isPresented: $isSupportPromptPresented) {
                SupportDevelopmentSheet(prompt: .current)
            }
            .confirmationDialog(
                "Reset hosted storage?",
                isPresented: $isResetHostedStorageConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Reset Hosted Storage", role: .destructive) {
                    Task { await appState.resetHostedStorage() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes the current hosted workspace data when the saved token is still valid, then creates a new hosted workspace and fresh agent token.")
            }
        }
    }

    private var settingsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Manage storage, Apple Health access, and sync behavior.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 4)
    }

    private var overviewCard: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            SettingsSummaryTile(
                title: "Destination",
                value: overviewPresentation.storageLabel,
                systemImage: "externaldrive.connected.to.line.below",
                color: .purple
            )
            SettingsSummaryTile(
                title: "Access",
                value: overviewPresentation.permissionLabel,
                systemImage: "heart.text.square.fill",
                color: permissionColor
            )
            SettingsSummaryTile(
                title: "Health Data",
                value: overviewPresentation.healthDataSummary,
                systemImage: "checklist",
                color: HealthSyncTheme.primaryBlue
            )
            SettingsSummaryTile(
                title: "Credentials",
                value: overviewPresentation.tokenLabel,
                systemImage: appState.hasStoredToken ? "key.fill" : "key.slash.fill",
                color: appState.hasStoredToken ? HealthSyncTheme.successGreen : HealthSyncTheme.warningOrange
            )
        }
    }

    private var storageDestinationCard: some View {
        SettingsCard(
            title: "Storage Destination",
            subtitle: overviewPresentation.storageDetail,
            systemImage: "server.rack",
            color: .purple
        ) {
            SettingsPickerRow(
                title: "Mode",
                detail: appState.settings.storageMode.label,
                systemImage: "externaldrive.connected.to.line.below",
                color: .purple
            ) {
                Menu {
                    ForEach(StorageMode.allCases) { mode in
                        Button {
                            appState.settings.storageMode = mode
                        } label: {
                            HStack {
                                Text(mode.label)
                                if appState.settings.storageMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }

            if appState.settings.storageMode == .hostedHealthSync {
                SettingsDivider()
                hostedStorageControls
            }
        }
    }

    @ViewBuilder
    private var manualBackendCard: some View {
        if appState.settings.storageMode.showsManualBackendSettings {
            SettingsCard(
                title: "Backend Configuration",
                subtitle: "Point HealthSync at your own ingestion endpoint.",
                systemImage: "link",
                color: HealthSyncTheme.primaryBlue
            ) {
                SettingsInputRow(
                    title: "Backend URL",
                    systemImage: "link",
                    color: HealthSyncTheme.primaryBlue
                ) {
                    TextField("https://api.example.com", text: $appState.settings.backendURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }

                SettingsInputRow(
                    title: appState.hasStoredToken ? "Auth Token" : "Token Required",
                    systemImage: "key.fill",
                    color: HealthSyncTheme.warningOrange
                ) {
                    SecureField(appState.hasStoredToken ? "New token (stored)" : "Auth token", text: $appState.authTokenDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await appState.saveSettingsAndToken() }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryBlue, filled: true))

                    Button {
                        Task { await appState.testConnection() }
                    } label: {
                        Label("Test", systemImage: "network")
                    }
                    .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryBlue, filled: false))
                }
            }
        }
    }

    private var appleHealthCard: some View {
        SettingsCard(
            title: "Apple Health Access",
            subtitle: "Review permissions and recover access from iPhone Settings.",
            systemImage: "heart.text.square.fill",
            color: HealthSyncTheme.primaryRed
        ) {
            let presentation = healthPermissionPresentation

            HStack(spacing: 12) {
                SettingsIconBadge(systemImage: "shield.checkered", color: permissionColor, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Permission status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(overviewPresentation.permissionLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()
            }

            SettingsDivider()

            Button {
                Task { await appState.connectAppleHealth() }
            } label: {
                Label(presentation.approvalButtonTitle, systemImage: presentation.approvalButtonSystemImage)
            }
            .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryRed, filled: true))
            .disabled(presentation.isApprovalButtonDisabled)
            .accessibilityIdentifier("request-apple-health-approval-button")

            if presentation.showsSettingsButton {
                Button {
                    openAppSettings()
                } label: {
                    Label(presentation.settingsButtonTitle, systemImage: "gearshape")
                }
                .buttonStyle(SettingsActionButtonStyle(color: .secondary, filled: false))
                .disabled(appState.isBusy)
                .accessibilityIdentifier("open-app-settings-health-permissions-button")
            }
        }
    }

    @ViewBuilder
    private var agentAccessCard: some View {
        if appState.settings.storageMode == .hostedHealthSync && hasAgentAccess {
            SettingsCard(
                title: "Agent Access Details",
                subtitle: "Copy workspace and read-only agent credentials.",
                systemImage: "key.viewfinder",
                color: HealthSyncTheme.successGreen
            ) {
                if !hostedWorkspaceID.isEmpty {
                    SettingsCopyBlock(title: "Workspace ID", value: hostedWorkspaceID)
                    Button {
                        copyToPasteboard(hostedWorkspaceID)
                    } label: {
                        Label("Copy workspace ID", systemImage: "number")
                    }
                    .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryBlue, filled: false))
                }

                if !hostedAgentEndpoint.isEmpty {
                    SettingsCopyBlock(title: "Endpoint URL", value: hostedAgentEndpoint, lineLimit: 4)
                    Button {
                        copyToPasteboard(hostedAgentEndpoint)
                    } label: {
                        Label("Copy agent endpoint", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryBlue, filled: false))
                }

                if !appState.hostedAgentToken.isEmpty {
                    Button {
                        copyToPasteboard(appState.hostedAgentToken)
                    } label: {
                        Label("Copy read-only agent token", systemImage: "key")
                    }
                    .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryBlue, filled: false))
                }

                Button {
                    Task { await appState.refreshHostedAgentToken() }
                } label: {
                    Label("Refresh read-only agent token", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.successGreen, filled: true))
                .disabled(appState.isBusy || !appState.hasStoredToken)
            }
        }
    }

    private var healthDataCard: some View {
        SettingsCard(
            title: "Health Data",
            subtitle: overviewPresentation.healthDataSummary,
            systemImage: "checklist",
            color: HealthSyncTheme.primaryBlue
        ) {
            let categories = HealthMetricCategory.allCases

            VStack(spacing: 0) {
                ForEach(categories.indices, id: \.self) { index in
                    let category = categories[index]

                    NavigationLink {
                        HealthMetricCategoryView(category: category)
                    } label: {
                        HealthMetricCategoryRow(
                            category: category,
                            selectedCount: category.selectedCount(from: appState.settings.selectedTypes),
                            totalCount: category.types.count
                        )
                    }
                    .buttonStyle(.plain)

                    if index < categories.count - 1 {
                        SettingsDivider()
                    }
                }
            }
        }
    }

    private var syncControlsCard: some View {
        SettingsCard(
            title: "Sync Controls",
            subtitle: "Set background cadence or start a manual sync.",
            systemImage: "arrow.triangle.2.circlepath.circle.fill",
            color: HealthSyncTheme.successGreen
        ) {
            SettingsPickerRow(
                title: "Background Sync",
                detail: appState.settings.syncFrequency.label,
                systemImage: "clock.arrow.circlepath",
                color: HealthSyncTheme.successGreen
            ) {
                Menu {
                    ForEach(SyncFrequency.allCases) { frequency in
                        Button {
                            appState.settings.syncFrequency = frequency
                        } label: {
                            HStack {
                                Text(frequency.label)
                                if appState.settings.syncFrequency == frequency {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }

            Button {
                Task { await appState.saveSettingsAndToken() }
            } label: {
                Label("Apply frequency", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.successGreen, filled: false))

            SettingsDivider()

            Button {
                Task { await appState.syncLast24Hours() }
            } label: {
                Label("Sync last 24 hours", systemImage: "arrow.up.doc")
            }
            .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryBlue, filled: true))

            NavigationLink {
                BackfillView()
            } label: {
                Label("Sync historical range", systemImage: "calendar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryPink, filled: false))
        }
    }

    private var hostedStorageControls: some View {
        let presentation = hostedStoragePresentation

        return VStack(alignment: .leading, spacing: 12) {
            SettingsInfoBanner(
                text: "Selected Apple Health data uploads to HealthSync-hosted storage and remains available through a private read-only endpoint.",
                systemImage: "lock.shield.fill",
                color: HealthSyncTheme.primaryBlue
            )

            if let progressMessage = presentation.progressMessage {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(progressMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let feedbackMessage = presentation.feedbackMessage {
                SettingsInfoBanner(
                    text: feedbackMessage,
                    systemImage: presentation.feedbackKind == .error ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    color: presentation.feedbackKind.color
                )
            }

            Button {
                Task { await appState.createHostedStorage() }
            } label: {
                Label(presentation.createButtonTitle, systemImage: presentation.createButtonSystemImage)
            }
            .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryBlue, filled: true))
            .disabled(presentation.isCreateButtonDisabled)
            .accessibilityIdentifier("create-hosted-storage-button")

            Button {
                Task { await appState.testConnection() }
            } label: {
                Label("Test hosted connection", systemImage: "network")
            }
            .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryBlue, filled: false))
            .disabled(appState.isBusy || !appState.hasStoredToken)
            .accessibilityIdentifier("test-hosted-connection-button")

            if presentation.showsResetButton {
                Button(role: .destructive) {
                    isResetHostedStorageConfirmationPresented = true
                } label: {
                    Label(presentation.resetButtonTitle, systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SettingsActionButtonStyle(color: HealthSyncTheme.primaryRed, filled: false))
                .disabled(presentation.isResetButtonDisabled)
                .accessibilityIdentifier("reset-hosted-storage-button")
            }
        }
    }

    private var overviewPresentation: SettingsOverviewPresentation {
        SettingsOverviewPresentation(
            storageMode: appState.settings.storageMode,
            permissionSummary: appState.permissionSummary,
            selectedHealthDataCount: appState.settings.selectedTypes.count,
            totalHealthDataCount: HealthDataType.allCases.count,
            hasStoredUploadToken: appState.hasStoredToken
        )
    }

    private var permissionColor: Color {
        switch appState.permissionSummary {
        case "Requested":
            HealthSyncTheme.successGreen
        case "Unavailable":
            HealthSyncTheme.primaryRed
        default:
            HealthSyncTheme.warningOrange
        }
    }

    private var hostedAgentEndpoint: String {
        appState.settings.hostedAgentEndpoint?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hostedWorkspaceID: String {
        appState.settings.hostedWorkspaceID?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hostedStoragePresentation: HostedStorageSetupPresentation {
        HostedStorageSetupPresentation(
            isBusy: appState.isBusy,
            backendURL: appState.settings.backendURL,
            lastError: appState.lastError,
            hostedAgentEndpoint: appState.settings.hostedAgentEndpoint,
            hostedAgentToken: appState.hostedAgentToken,
            hasStoredUploadToken: appState.hasStoredToken
        )
    }

    private var healthPermissionPresentation: HealthPermissionSettingsPresentation {
        HealthPermissionSettingsPresentation(
            permissionSummary: appState.permissionSummary,
            isBusy: appState.isBusy
        )
    }

    private var hasAgentAccess: Bool {
        !hostedAgentEndpoint.isEmpty || !appState.hostedAgentToken.isEmpty
    }

    private func copyToPasteboard(_ value: String) {
        UIPasteboard.general.string = value
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct HealthMetricCategoryRow: View {
    let category: HealthMetricCategory
    let selectedCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(systemImage: category.settingsIcon, color: category.settingsColor, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(category.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(selectedCount)/\(totalCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(category.settingsColor)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct HealthMetricCategoryView: View {
    @EnvironmentObject private var appState: AppState

    let category: HealthMetricCategory

    private var selectedCount: Int {
        category.selectedCount(from: appState.settings.selectedTypes)
    }

    var body: some View {
        ZStack {
            HealthSyncTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    SettingsCard(
                        title: category.title,
                        subtitle: "\(selectedCount) of \(category.types.count) selected",
                        systemImage: category.settingsIcon,
                        color: category.settingsColor
                    ) {
                        Text(category.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button {
                                setCategory(enabled: true)
                            } label: {
                                Label("Select all", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(SettingsActionButtonStyle(color: category.settingsColor, filled: true))

                            Button {
                                setCategory(enabled: false)
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            .buttonStyle(SettingsActionButtonStyle(color: category.settingsColor, filled: false))
                        }

                        SettingsDivider()

                        VStack(spacing: 0) {
                            ForEach(category.types.indices, id: \.self) { index in
                                let type = category.types[index]

                                HealthMetricToggleRow(type: type)

                                if index < category.types.count - 1 {
                                    SettingsDivider()
                                }
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 48)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .safeAreaPadding(.bottom, 32)
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setCategory(enabled: Bool) {
        for type in category.types {
            appState.set(type: type, enabled: enabled)
        }
    }
}

private struct HealthMetricToggleRow: View {
    @EnvironmentObject private var appState: AppState

    let type: HealthDataType

    var body: some View {
        Toggle(isOn: Binding(
            get: { appState.settings.selectedTypes.contains(type) },
            set: { enabled in appState.set(type: type, enabled: enabled) }
        )) {
            HStack(spacing: 12) {
                SettingsIconBadge(systemImage: type.settingsIcon, color: type.settingsColor, size: 34)

                Text(type.label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(type.settingsColor)
        .padding(.vertical, 10)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                SettingsIconBadge(systemImage: systemImage, color: color, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthCardStyle(padding: 14)
    }
}

private struct SettingsSummaryTile: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsIconBadge(systemImage: systemImage, color: color, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .healthCardStyle(padding: 14)
    }
}

private struct SettingsIconBadge: View {
    let systemImage: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(size * 0.28, 10), style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)

            Image(systemName: systemImage)
                .font(.system(size: size * 0.43, weight: .semibold))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .separator).opacity(0.35))
            .frame(height: 0.5)
    }
}

private struct SettingsPickerRow<PickerContent: View>: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color
    let picker: PickerContent

    init(
        title: String,
        detail: String,
        systemImage: String,
        color: Color,
        @ViewBuilder picker: () -> PickerContent
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.color = color
        self.picker = picker()
    }

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(systemImage: systemImage, color: color, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            picker
        }
    }
}

private struct SettingsInputRow<Field: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    let field: Field

    init(
        title: String,
        systemImage: String,
        color: Color,
        @ViewBuilder field: () -> Field
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.field = field()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsIconBadge(systemImage: systemImage, color: color, size: 34)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                field
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct SettingsInfoBanner: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.top, 1)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SettingsCopyBlock: View {
    let title: String
    let value: String
    var lineLimit = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct SettingsActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let color: Color
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .foregroundStyle(filled ? Color.white : color)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(filled ? color : color.opacity(0.12))
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private extension HealthMetricCategory {
    var settingsIcon: String {
        switch self {
        case .bodyMeasurements:
            "figure.arms.open"
        case .activity:
            "figure.run"
        case .heart:
            "heart.text.square.fill"
        case .mobility:
            "figure.walk.motion"
        case .nutrition:
            "fork.knife"
        case .hearingEnvironment:
            "ear.and.waveform"
        case .clinical:
            "cross.case.fill"
        case .respiratory:
            "lungs.fill"
        case .sleepMindfulness:
            "moon.zzz.fill"
        case .reproductiveHealth:
            "calendar.badge.heart"
        case .symptomsEvents:
            "list.bullet.clipboard.fill"
        }
    }

    var settingsColor: Color {
        switch self {
        case .bodyMeasurements:
            .teal
        case .activity:
            HealthSyncTheme.warningOrange
        case .heart:
            HealthSyncTheme.primaryRed
        case .mobility:
            HealthSyncTheme.primaryBlue
        case .nutrition:
            .green
        case .hearingEnvironment:
            .indigo
        case .clinical:
            .purple
        case .respiratory:
            .cyan
        case .sleepMindfulness:
            .blue
        case .reproductiveHealth:
            HealthSyncTheme.primaryPink
        case .symptomsEvents:
            .secondary
        }
    }

    func selectedCount(from selectedTypes: Set<HealthDataType>) -> Int {
        types.filter { selectedTypes.contains($0) }.count
    }
}

private extension HealthDataType {
    var settingsIcon: String {
        switch self {
        case .stepCount: "figure.walk"
        case .heartRate: "heart.fill"
        case .restingHeartRate: "heart.text.square"
        case .hrvSDNN: "waveform.path.ecg"
        case .activeEnergy: "flame.fill"
        case .basalEnergy: "bolt.fill"
        case .bodyMass: "scalemass.fill"
        case .bodyFatPercentage: "percent"
        case .dietaryEnergy: "fork.knife"
        case .dietaryProtein: "fish.fill"
        case .dietaryCarbohydrates: "leaf.fill"
        case .dietaryFat: "drop.fill"
        case .water: "drop.bubble.fill"
        case .sleepAnalysis: "moon.fill"
        case .workouts: "figure.run"
        default:
            switch kind {
            case .quantity:
                rawValue.hasPrefix("dietary_") ? "fork.knife" : "waveform.path.ecg.rectangle"
            case .category:
                "tag.fill"
            case .workout:
                "figure.run"
            }
        }
    }

    var settingsColor: Color {
        switch self {
        case .stepCount: HealthSyncTheme.primaryBlue
        case .heartRate: HealthSyncTheme.primaryRed
        case .restingHeartRate: HealthSyncTheme.primaryPink
        case .hrvSDNN: .purple
        case .activeEnergy: HealthSyncTheme.warningOrange
        case .basalEnergy: .orange
        case .bodyMass: .teal
        case .bodyFatPercentage: .indigo
        case .dietaryEnergy: .green
        case .dietaryProtein: .orange
        case .dietaryCarbohydrates: .yellow
        case .dietaryFat: .red
        case .water: .blue
        case .sleepAnalysis: .indigo
        case .workouts: .green
        default:
            switch kind {
            case .quantity:
                rawValue.hasPrefix("dietary_") ? .green : HealthSyncTheme.primaryBlue
            case .category:
                .purple
            case .workout:
                .green
            }
        }
    }
}

private extension HostedStorageFeedbackKind {
    var color: Color {
        switch self {
        case .none, .info:
            .secondary
        case .success:
            HealthSyncTheme.successGreen
        case .error:
            HealthSyncTheme.primaryRed
        }
    }
}

private struct SupportDevelopmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didCopyAddress = false

    let prompt: SupportDevelopmentPrompt

    var body: some View {
        NavigationStack {
            ZStack {
                HealthSyncTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Visual Header Icon
                    ZStack {
                        Circle()
                            .fill(HealthSyncTheme.primaryRed.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(HealthSyncTheme.primaryRed)
                    }
                    .padding(.top, 16)
                    
                    Text(prompt.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zcash Address")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        Button {
                            copyZcashAddress()
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(prompt.zcashAddress)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(8)
                                    .minimumScaleFactor(0.8)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                HStack {
                                    Image(systemName: didCopyAddress ? "checkmark.circle.fill" : "doc.on.doc")
                                        .font(.subheadline.weight(.semibold))
                                    Text(didCopyAddress ? "Address Copied" : "Tap to Copy Wallet Address")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(didCopyAddress ? HealthSyncTheme.successGreen : HealthSyncTheme.primaryBlue)
                                .padding(.leading, 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("copy-zcash-address-button")
                    }
                    .healthCardStyle(padding: 16)
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Support HealthSync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }

    private func copyZcashAddress() {
        UIPasteboard.general.string = prompt.zcashAddress

        withAnimation {
            didCopyAddress = true
        }
    }
}
