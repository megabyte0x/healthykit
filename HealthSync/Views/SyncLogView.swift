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
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "doc.plaintext")
                                .font(.system(size: 64))
                                .foregroundStyle(.secondary)
                                .padding(.top, 100)
                            Text("No Activity Yet")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("Your synchronization logs and connection check history will appear here once sync actions start.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                    } else {
                        ForEach(appState.logs) { log in
                            SyncLogRow(log: log)
                        }
                    }
                }
                .padding(16)
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
                // Log Level Badge
                Text(log.level.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .foregroundStyle(color)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Timestamp
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            
            // Log Message Content
            Text(log.message)
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
