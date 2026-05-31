import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                HealthSyncTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    Image("HealthSyncLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 8)
                        .padding(.bottom, 8)
                    
                    // Title and Description
                    VStack(spacing: 12) {
                        Text("HealthSync")
                            .font(.system(.largeTitle, design: .rounded).weight(.black))
                            .tracking(-0.5)
                        
                        Text("Sync your Apple Health metrics and workouts directly to your private backend database, with absolute security.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // Premium Feature Cards List
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "lock.shield.fill",
                            iconColor: .purple,
                            title: "Privacy First",
                            description: "Your health metrics never leave this device except to your own configured private backend URL."
                        )
                        
                        FeatureRow(
                            icon: "heart.text.square.fill",
                            iconColor: HealthSyncTheme.primaryRed,
                            title: "Comprehensive Tracking",
                            description: "Easily read Steps, Heart Rate, HRV, Energy, Body Composition, Sleep, Workouts, and Macros."
                        )
                        
                        FeatureRow(
                            icon: "key.fill",
                            iconColor: HealthSyncTheme.primaryBlue,
                            title: "Keychain Security",
                            description: "Your authentication tokens and custom endpoints are securely encrypted within the iOS Keychain."
                        )
                    }
                    .padding(.horizontal, 4)
                    
                    Spacer()
                    
                    // Action Area
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
                        
                        Button {
                            Task { await appState.connectAppleHealth() }
                        } label: {
                            HStack(spacing: 10) {
                                if appState.isBusy {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "heart.fill")
                                    Text("Connect Apple Health")
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
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthCardStyle(padding: 12)
    }
}
