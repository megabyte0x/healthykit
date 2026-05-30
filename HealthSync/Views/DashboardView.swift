import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("HealthKit", value: appState.permissionSummary)
                    LabeledContent("Last success", value: appState.status.lastSuccessfulSyncAt.displayValue)
                    LabeledContent("Last attempt", value: appState.status.lastAttemptedSyncAt.displayValue)
                    LabeledContent("Pending uploads", value: "\(appState.status.pendingUploadCount)")
                    if let error = appState.status.lastError ?? appState.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section("Sync") {
                    Button {
                        Task { await appState.syncLast24Hours() }
                    } label: {
                        if appState.isBusy {
                            ProgressView()
                        } else {
                            Label("Manual sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(appState.isBusy)

                    NavigationLink {
                        BackfillView()
                    } label: {
                        Label("Backfill date range", systemImage: "calendar.badge.clock")
                    }
                }

                Section("Recent Log") {
                    if appState.logs.isEmpty {
                        Text("No sync activity yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.logs.prefix(6)) { log in
                            SyncLogRow(log: log)
                        }
                        NavigationLink("View all") {
                            SyncLogView()
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await appState.refresh()
            }
        }
    }
}

private extension Optional where Wrapped == Date {
    var displayValue: String {
        guard let self else { return "Never" }
        return self.formatted(date: .abbreviated, time: .shortened)
    }
}
