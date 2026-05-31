import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HealthSyncTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Custom App Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OVERVIEW")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .tracking(1.2)
                                Text("HealthSync")
                                    .font(.system(.title, design: .rounded).weight(.black))
                            }
                            Spacer()
                            
                            // HealthKit connection pill
                            let isConnected = appState.permissionSummary == "Requested"
                            StatusBadge(
                                text: isConnected ? "Connected" : "Not Active",
                                color: isConnected ? HealthSyncTheme.successGreen : .red,
                                iconName: isConnected ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                            )
                        }
                        .padding(.horizontal, 4)
                        
                        // Sleek Error Notice Card (if any error is active)
                        if let error = appState.status.lastError ?? appState.lastError {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title3)
                                        .foregroundStyle(HealthSyncTheme.warningOrange)
                                    Text("Sync Connection Issue")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .healthCardStyle(padding: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(HealthSyncTheme.warningOrange.opacity(0.3), lineWidth: 1.5)
                            )
                            .transition(.opacity)
                        }
                        
                        // 2x2 Grid of Status Metrics
                        LazyVGrid(columns: columns, spacing: 16) {
                            MetricCard(
                                title: "Last Success",
                                value: appState.status.lastSuccessfulSyncAt.displayValue,
                                icon: "checkmark.circle.fill",
                                iconColor: HealthSyncTheme.successGreen,
                                subtitle: appState.status.lastSuccessfulSyncAt == nil ? "No sync recorded" : "Uploaded"
                            )
                            
                            MetricCard(
                                title: "Last Attempt",
                                value: appState.status.lastAttemptedSyncAt.displayValue,
                                icon: "network",
                                iconColor: HealthSyncTheme.primaryBlue,
                                subtitle: "Connection check"
                            )
                            
                            MetricCard(
                                title: "Pending Queue",
                                value: "\(appState.status.pendingUploadCount)",
                                icon: "tray.and.arrow.up.fill",
                                iconColor: appState.status.pendingUploadCount > 0 ? HealthSyncTheme.warningOrange : .secondary,
                                subtitle: appState.status.pendingUploadCount > 0 ? "Retrying network" : "All uploads clear"
                            )
                            
                            MetricCard(
                                title: "Storage Destination",
                                value: appState.settings.storageMode == .hostedHealthSync ? "Hosted" : "Custom",
                                icon: "server.rack",
                                iconColor: .purple,
                                subtitle: appState.settings.storageMode.label
                            )
                        }
                        
                        // Control Center & Actions Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(HealthSyncTheme.primaryBlue)
                                Text("Control Center")
                                    .font(.headline)
                            }
                            
                            // Manual Sync Button
                            Button {
                                Task { await appState.syncLast24Hours() }
                            } label: {
                                HStack(spacing: 8) {
                                    if appState.isBusy {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.headline)
                                        Text("Sync Last 24 Hours")
                                    }
                                }
                            }
                            .buttonStyle(HealthSyncTheme.PrimaryButtonStyle(
                                isBusy: appState.isBusy,
                                gradient: appState.isBusy ? LinearGradient(colors: [.secondary, .secondary], startPoint: .top, endPoint: .bottom) : HealthSyncTheme.stepsGradient
                            ))
                            .disabled(appState.isBusy)
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Backfill Navigation Row
                            NavigationLink {
                                BackfillView()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(HealthSyncTheme.primaryPink.opacity(0.1))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "calendar.badge.clock")
                                            .foregroundStyle(HealthSyncTheme.primaryPink)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Backfill historical data")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("Upload selected custom date ranges")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .healthCardStyle(padding: 16)
                        
                        // Recent Sync Logs Timeline Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(.purple)
                                Text("Recent Activity")
                                    .font(.headline)
                                Spacer()
                                if !appState.logs.isEmpty {
                                    NavigationLink {
                                        SyncLogView()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text("View All")
                                            Image(systemName: "chevron.right")
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(HealthSyncTheme.primaryBlue)
                                    }
                                }
                            }
                            
                            if appState.logs.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "doc.plaintext")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                        Text("No sync logs recorded yet")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 24)
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    let logsToDisplay = Array(appState.logs.prefix(4))
                                    ForEach(0..<logsToDisplay.count, id: \.self) { index in
                                        let log = logsToDisplay[index]
                                        let isLast = index == logsToDisplay.count - 1
                                        
                                        HStack(alignment: .top, spacing: 14) {
                                            // Timeline dot and line
                                            VStack(spacing: 0) {
                                                Circle()
                                                    .fill(logColor(for: log.level))
                                                    .frame(width: 10, height: 10)
                                                    .padding(.top, 4)
                                                
                                                if !isLast {
                                                    Rectangle()
                                                        .fill(Color.primary.opacity(0.08))
                                                        .frame(width: 2)
                                                        .frame(minHeight: 34)
                                                }
                                            }
                                            
                                            // Log details
                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack {
                                                    Text(log.level.rawValue.uppercased())
                                                        .font(.caption2.weight(.bold).monospaced())
                                                        .foregroundStyle(logColor(for: log.level))
                                                    Spacer()
                                                    Text(log.createdAt.formatted(date: .omitted, time: .shortened))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                
                                                Text(log.message)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(2)
                                            }
                                            .padding(.bottom, isLast ? 0 : 12)
                                        }
                                    }
                                }
                            }
                        }
                        .healthCardStyle(padding: 16)
                    }
                    .padding(16)
                }
                .refreshable {
                    await appState.refresh()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func logColor(for level: SyncLogLevel) -> Color {
        switch level {
        case .info: HealthSyncTheme.primaryBlue
        case .success: HealthSyncTheme.successGreen
        case .warning: HealthSyncTheme.warningOrange
        case .error: HealthSyncTheme.primaryRed
        }
    }
}

// Custom Premium Metric Card Component
private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.footnote)
                        .foregroundStyle(iconColor)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthCardStyle(padding: 14)
    }
}

private extension Optional where Wrapped == Date {
    var displayValue: String {
        guard let self else { return "Never" }
        return self.formatted(date: .abbreviated, time: .shortened)
    }
}
