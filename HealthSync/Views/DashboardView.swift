import Foundation
import SwiftUI

struct HealthPermissionPromptPresentation: Equatable {
    let permissionSummary: String
    let lastError: String?
    let isBusy: Bool

    var shouldShowConnectAction: Bool {
        permissionSummary != "Requested" || isAuthorizationNotDeterminedError
    }

    var connectButtonTitle: String {
        "Continue"
    }

    var isConnectButtonDisabled: Bool {
        isBusy
    }

    private var isAuthorizationNotDeterminedError: Bool {
        lastError == HealthKitManagerError.authorizationNotDetermined.errorDescription
    }
}

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
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("HealthSync")
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text("Private health data sync")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            
                            let isConnected = appState.permissionSummary == "Requested"
                            StatusBadge(
                                text: isConnected ? "Connected" : "Not Active",
                                color: isConnected ? HealthSyncTheme.successGreen : .red,
                                iconName: isConnected ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                            )
                        }
                        .padding(.horizontal, 4)
                        
                        if let error = appState.status.lastError ?? appState.lastError {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title3)
                                        .foregroundStyle(HealthSyncTheme.warningOrange)
                                    Text("Needs Attention")
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
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(HealthSyncTheme.warningOrange.opacity(0.3), lineWidth: 1.5)
                            )
                            .transition(.opacity)
                        }

                        if let feedback = appState.actionFeedback {
                            HealthActionFeedbackBanner(feedback: feedback)
                        }
                        
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
                                subtitle: appState.settings.storageMode == .hostedHealthSync ? "Managed storage" : "Custom backend"
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .foregroundStyle(HealthSyncTheme.primaryBlue)
                                Text("Sync")
                                    .font(.headline)
                            }

                            if healthPermissionPresentation.shouldShowConnectAction {
                                HealthPermissionActionView(
                                    presentation: healthPermissionPresentation,
                                    onConnect: { Task { await appState.connectAppleHealth() } }
                                )
                                Divider()
                                    .padding(.vertical, 4)
                            }
                            
                            // Manual Sync Button
                            Button {
                                Task { await appState.syncLast24Hours() }
                            } label: {
                                HStack(spacing: 8) {
                                    if appState.isBusy {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Syncing…")
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.headline)
                                        Text("Sync Last 24 Hours")
                                    }
                                }
                            }
                            .buttonStyle(HealthSyncTheme.PrimaryButtonStyle(
                                isBusy: appState.isBusy,
                                gradient: appState.isBusy ? HealthSyncTheme.disabledGradient : HealthSyncTheme.stepsGradient
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
                                        Text("Sync historical data")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("Choose a custom date range")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .healthCardStyle(padding: 16)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(HealthSyncTheme.primaryBlue)
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
                                        Image(systemName: "clock")
                                            .font(.title)
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
                                                
                                                Text(HealthSyncUserMessages.displayLogMessage(log.message))
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

                        Color.clear
                            .frame(height: 88)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .safeAreaPadding(.bottom, 32)
                }
                .refreshable {
                    await appState.refresh()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var healthPermissionPresentation: HealthPermissionPromptPresentation {
        HealthPermissionPromptPresentation(
            permissionSummary: appState.permissionSummary,
            lastError: appState.status.lastError ?? appState.lastError,
            isBusy: appState.isBusy
        )
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

private struct HealthPermissionActionView: View {
    let presentation: HealthPermissionPromptPresentation
    let onConnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(HealthSyncTheme.primaryRed)
                Text("Apple Health Access")
                    .font(.subheadline.weight(.semibold))
            }

            Text("Allow HealthSync to read the health categories you select. You can review or revoke access in iPhone Settings at any time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onConnect) {
                HStack(spacing: 8) {
                    if presentation.isConnectButtonDisabled {
                        ProgressView()
                            .tint(.white)
                        Text("Requesting Access…")
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                        Text(presentation.connectButtonTitle)
                    }
                }
            }
            .buttonStyle(HealthSyncTheme.PrimaryButtonStyle(
                isBusy: presentation.isConnectButtonDisabled,
                gradient: buttonGradient
            ))
            .disabled(presentation.isConnectButtonDisabled)
            .accessibilityIdentifier("connect-apple-health-sync-button")
        }
        .padding(.bottom, 2)
    }

    private var buttonGradient: LinearGradient {
        if presentation.isConnectButtonDisabled {
            HealthSyncTheme.disabledGradient
        } else {
            HealthSyncTheme.heartGradient
        }
    }
}

struct HealthActionFeedbackBanner: View {
    let feedback: HealthActionFeedback

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.kind.systemImage)
                .foregroundStyle(feedback.kind.color)
            Text(feedback.message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthCardStyle(padding: 14)
        .accessibilityIdentifier("health-action-feedback")
    }
}

extension HealthActionFeedback.Kind {
    var color: Color {
        switch self {
        case .success: HealthSyncTheme.successGreen
        case .info: HealthSyncTheme.primaryBlue
        case .error: HealthSyncTheme.primaryRed
        }
    }

    var systemImage: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .error: "exclamationmark.circle.fill"
        }
    }
}

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
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthCardStyle(padding: 14)
    }
}

private extension Optional where Wrapped == Date {
    var displayValue: String {
        DashboardMetricDateFormatter.displayValue(for: self)
    }
}

enum DashboardMetricDateFormatter {
    static func displayValue(for date: Date?, timeZone: TimeZone = .current) -> String {
        guard let date else { return "Never" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter.string(from: date)
    }
}
