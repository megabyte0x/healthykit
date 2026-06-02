import SwiftUI

struct SyncLogView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            HealthSyncTheme.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    if appState.logs.isEmpty {
                        ContentUnavailableView(
                            "No Activity Yet",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("Sync logs and connection checks will appear here after HealthSync starts uploading data.")
                        )
                        .padding(.top, 96)
                    } else {
                        ForEach(appState.logs) { log in
                            SyncLogRow(log: log)
                        }
                    }

                    Color.clear
                        .frame(height: 96)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .safeAreaPadding(.bottom, 32)
            }
            .refreshable {
                await appState.refresh()
            }
        }
        .navigationTitle("Sync Logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SyncLogRow: View {
    let log: SyncLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(log.level.rawValue.capitalized, systemImage: iconName)
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .foregroundStyle(color)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(DashboardMetricDateFormatter.displayValue(for: log.createdAt))
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            
            Text(HealthSyncUserMessages.displayLogMessage(log.message))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthCardStyle(padding: 16)
    }

    private var iconName: String {
        switch log.level {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch log.level {
        case .info: HealthSyncTheme.primaryBlue
        case .success: HealthSyncTheme.successGreen
        case .warning: HealthSyncTheme.warningOrange
        case .error: HealthSyncTheme.primaryRed
        }
    }
}
