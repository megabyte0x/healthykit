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

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSupportPromptPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Storage") {
                    Picker("Storage", selection: $appState.settings.storageMode) {
                        ForEach(StorageMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }

                    if appState.settings.storageMode == .hostedHealthSync {
                        Text("Your selected Apple Health data will be uploaded to HealthSync-hosted storage and made available through a private read-only endpoint.")
                            .foregroundStyle(.secondary)

                        Button {
                            Task { await appState.createHostedStorage() }
                        } label: {
                            Label("Create Hosted Storage", systemImage: "externaldrive.badge.plus")
                        }
                    }
                }

                Section("Backend") {
                    TextField("https://api.example.com", text: $appState.settings.backendURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    SecureField(appState.hasStoredToken ? "New token (stored)" : "Auth token", text: $appState.authTokenDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

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
                }

                if appState.settings.storageMode == .hostedHealthSync && hasAgentAccess {
                    Section("Agent Access") {
                        if !hostedAgentEndpoint.isEmpty {
                            Button {
                                copyToPasteboard(hostedAgentEndpoint)
                            } label: {
                                Label("Copy agent endpoint", systemImage: "doc.on.doc")
                            }

                            Text(hostedAgentEndpoint)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }

                        if !appState.hostedAgentToken.isEmpty {
                            Button {
                                copyToPasteboard(appState.hostedAgentToken)
                            } label: {
                                Label("Copy read-only agent token", systemImage: "key")
                            }
                        }
                    }
                }

                Section("Data Types") {
                    ForEach(HealthDataType.allCases) { type in
                        Toggle(type.label, isOn: Binding(
                            get: { appState.settings.selectedTypes.contains(type) },
                            set: { enabled in appState.set(type: type, enabled: enabled) }
                        ))
                    }
                }

                Section("Sync Frequency") {
                    Picker("Frequency", selection: $appState.settings.syncFrequency) {
                        ForEach(SyncFrequency.allCases) { frequency in
                            Text(frequency.label).tag(frequency)
                        }
                    }

                    Button {
                        Task { await appState.saveSettingsAndToken() }
                    } label: {
                        Label("Apply frequency", systemImage: "clock.arrow.circlepath")
                    }
                }

                Section("Manual Actions") {
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
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSupportPromptPresented = true
                    } label: {
                        Label("Support", systemImage: "heart.circle")
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

    private var hasAgentAccess: Bool {
        !hostedAgentEndpoint.isEmpty || !appState.hostedAgentToken.isEmpty
    }

    private func copyToPasteboard(_ value: String) {
        UIPasteboard.general.string = value
    }
}

private struct SupportDevelopmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didCopyAddress = false

    let prompt: SupportDevelopmentPrompt

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(prompt.message)
                        .font(.body)
                }

                Section("Zcash Address") {
                    Button {
                        copyZcashAddress()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                didCopyAddress ? "Copied to clipboard" : "Tap to copy address",
                                systemImage: didCopyAddress ? "checkmark.circle.fill" : "doc.on.doc"
                            )
                            .foregroundStyle(didCopyAddress ? .green : .primary)

                            Text(prompt.zcashAddress)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("copy-zcash-address-button")
                }
            }
            .navigationTitle("Support Development")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
