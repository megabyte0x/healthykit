import SwiftUI
import UIKit

struct SupportDevelopmentPrompt: Equatable {
    let paymentMethodLabel: String
    let zcashAddress: String

    var message: String {
        "Support the application development by paying some \(paymentMethodLabel)."
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

    var createButtonTitle: String {
        if isBusy {
            return "Creating Hosted Storage..."
        }

        return hasAgentAccess ? "Hosted Storage Created" : "Create Hosted Storage"
    }

    var createButtonSystemImage: String {
        if isBusy {
            return "hourglass"
        }

        return hasAgentAccess ? "checkmark.circle" : "externaldrive.badge.plus"
    }

    var isCreateButtonDisabled: Bool {
        isBusy || hasAgentAccess
    }

    var progressMessage: String? {
        isBusy ? "Creating hosted storage..." : nil
    }

    var feedbackMessage: String? {
        if let errorMessage = trimmed(lastError), !errorMessage.isEmpty {
            return errorMessage
        }

        if hasAgentAccess {
            return "Hosted storage is ready."
        }

        return nil
    }

    var feedbackKind: HostedStorageFeedbackKind {
        if let errorMessage = trimmed(lastError), !errorMessage.isEmpty {
            return .error
        }

        if hasAgentAccess {
            return .success
        }

        return .none
    }

    private var hasAgentAccess: Bool {
        !(trimmed(hostedAgentEndpoint) ?? "").isEmpty || !(trimmed(hostedAgentToken) ?? "").isEmpty
    }

    private func trimmed(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSupportPromptPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Storage Mode", selection: $appState.settings.storageMode) {
                        ForEach(StorageMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if appState.settings.storageMode == .hostedHealthSync {
                        let presentation = hostedStoragePresentation

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your selected Apple Health data will be uploaded to HealthSync-hosted storage and made available through a private read-only endpoint.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)

                            if let progressMessage = presentation.progressMessage {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(progressMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }

                            if let feedbackMessage = presentation.feedbackMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: presentation.feedbackKind == .error ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    Text(feedbackMessage)
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(presentation.feedbackKind.color)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)

                        Button {
                            Task { await appState.createHostedStorage() }
                        } label: {
                            HStack {
                                Image(systemName: presentation.createButtonSystemImage)
                                Text(presentation.createButtonTitle)
                            }
                        }
                        .disabled(presentation.isCreateButtonDisabled)
                        .accessibilityIdentifier("create-hosted-storage-button")
                    }
                } header: {
                    Text("Storage Destination")
                }

                if appState.settings.storageMode.showsManualBackendSettings {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("https://api.example.com", text: $appState.settings.backendURL)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            SecureField(appState.hasStoredToken ? "New token (stored)" : "Auth token", text: $appState.authTokenDraft)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Button {
                            Task { await appState.saveSettingsAndToken() }
                        } label: {
                            Label("Save settings", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            Task { await appState.testConnection() }
                        } label: {
                            Label("Test connection", systemImage: "network")
                        }
                    } header: {
                        Text("Backend Configuration")
                    }
                }

                if appState.settings.storageMode == .hostedHealthSync && hasAgentAccess {
                    Section {
                        if !hostedAgentEndpoint.isEmpty {
                            Button {
                                copyToPasteboard(hostedAgentEndpoint)
                            } label: {
                                Label("Copy agent endpoint", systemImage: "doc.on.doc")
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Endpoint URL")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                
                                Text(hostedAgentEndpoint)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.primary)
                                    .lineLimit(4)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.vertical, 4)
                        }

                        if !appState.hostedAgentToken.isEmpty {
                            Button {
                                copyToPasteboard(appState.hostedAgentToken)
                            } label: {
                                Label("Copy read-only agent token", systemImage: "key")
                            }
                        }
                    } header: {
                        Text("Agent Access Details")
                    }
                }

                Section {
                    ForEach(HealthDataType.allCases) { type in
                        Toggle(isOn: Binding(
                            get: { appState.settings.selectedTypes.contains(type) },
                            set: { enabled in appState.set(type: type, enabled: enabled) }
                        )) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(dataTypeColor(for: type).opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: dataTypeIcon(for: type))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(dataTypeColor(for: type))
                                }
                                
                                Text(type.label)
                                    .font(.body)
                            }
                        }
                        .tint(dataTypeColor(for: type))
                    }
                } header: {
                    Text("Select Health Metrics")
                }

                Section {
                    Picker("Sync Frequency", selection: $appState.settings.syncFrequency) {
                        ForEach(SyncFrequency.allCases) { frequency in
                            Text(frequency.label).tag(frequency)
                        }
                    }

                    Button {
                        Task { await appState.saveSettingsAndToken() }
                    } label: {
                        Label("Apply frequency", systemImage: "clock.arrow.circlepath")
                    }
                } header: {
                    Text("Background Synchronization")
                }

                Section {
                    Button {
                        Task { await appState.syncLast24Hours() }
                    } label: {
                        Label("Sync last 24 hours", systemImage: "arrow.up.doc")
                    }

                    NavigationLink {
                        BackfillView()
                    } label: {
                        Label("Backfill date range", systemImage: "calendar")
                    }
                } header: {
                    Text("Manual Operations")
                }
            }
            .navigationTitle("Settings")
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
        }
    }

    private var hostedAgentEndpoint: String {
        appState.settings.hostedAgentEndpoint?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hostedStoragePresentation: HostedStorageSetupPresentation {
        HostedStorageSetupPresentation(
            isBusy: appState.isBusy,
            backendURL: appState.settings.backendURL,
            lastError: appState.lastError,
            hostedAgentEndpoint: appState.settings.hostedAgentEndpoint,
            hostedAgentToken: appState.hostedAgentToken
        )
    }

    private var hasAgentAccess: Bool {
        !hostedAgentEndpoint.isEmpty || !appState.hostedAgentToken.isEmpty
    }

    private func copyToPasteboard(_ value: String) {
        UIPasteboard.general.string = value
    }
    
    // Mapping icon systems to health data types
    private func dataTypeIcon(for type: HealthDataType) -> String {
        switch type {
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
        }
    }
    
    // Mapping theme colors to health data types
    private func dataTypeColor(for type: HealthDataType) -> Color {
        switch type {
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
                            .frame(width: 80, height: 80)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 36))
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
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        
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
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
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
            .navigationTitle("Support Development")
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
