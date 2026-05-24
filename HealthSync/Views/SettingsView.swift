import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Form {
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
        }
    }
}
