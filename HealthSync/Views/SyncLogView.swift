import SwiftUI

struct SyncLogView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(appState.logs) { log in
            SyncLogRow(log: log)
        }
        .navigationTitle("Sync Log")
        .refreshable {
            await appState.refresh()
        }
    }
}

struct SyncLogRow: View {
    let log: SyncLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(color)
                Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(log.message)
                .font(.callout)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch log.level {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    private var color: Color {
        switch log.level {
        case .info: .blue
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
