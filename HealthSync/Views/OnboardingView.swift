import SwiftUI

enum OnboardingStorageDisclosure {
    static let message = "Continue creates private hosted storage, then requests Health access. You can switch to your own backend later."
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                HealthSyncTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 28) {
                    Spacer()
                    
                    Image("HealthSyncLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                        .padding(.bottom, 8)
                    
                    VStack(spacing: 12) {
                        Text("HealthSync")
                            .font(.largeTitle.weight(.bold))

                        Text("Send selected Apple Health metrics and workouts to the storage destination you control.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                    }
                    
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "heart.text.square.fill",
                            iconColor: HealthSyncTheme.primaryRed,
                            title: "Apple Health access",
                            description: "Choose the read permissions HealthSync needs. iOS keeps access under your control."
                        )
                        
                        FeatureRow(
                            icon: "externaldrive.badge.checkmark",
                            iconColor: HealthSyncTheme.primaryBlue,
                            title: "Private hosted storage",
                            description: OnboardingStorageDisclosure.message
                        )

                        FeatureRow(
                            icon: "clock.arrow.circlepath",
                            iconColor: HealthSyncTheme.successGreen,
                            title: "Controlled sync",
                            description: "Upload the last 24 hours, sync a historical range, or let background sync run on your schedule."
                        )
                    }
                    .padding(.horizontal, 4)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        if let error = appState.lastError {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
                            )
                            .transition(.opacity)
                        }

                        if let feedback = appState.actionFeedback {
                            HealthActionFeedbackBanner(feedback: feedback)
                        }
                        
                        Button {
                            Task { await appState.connectAppleHealth() }
                        } label: {
                            HStack(spacing: 10) {
                                if appState.isBusy {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Setting Up…")
                                } else {
                                    Text("Continue")
                                }
                            }
                        }
                        .buttonStyle(HealthSyncTheme.PrimaryButtonStyle(isBusy: appState.isBusy, gradient: HealthSyncTheme.heartGradient))
                        .disabled(appState.isBusy)
                    }
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Custom Feature Row Component
private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthCardStyle(padding: 12)
    }
}
