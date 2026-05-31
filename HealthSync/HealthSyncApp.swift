import SwiftUI

@main
struct HealthSyncApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}

struct ContentRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.shouldShowOnboarding {
                OnboardingView()
            } else {
                TabView {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "waveform.path.ecg")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }
            }
        }
    }
}

// MARK: - HealthSync Theme & Premium Style Guide

struct HealthSyncTheme {
    // Curated color palette
    static let primaryRed = Color(red: 255/255, green: 45/255, blue: 85/255)
    static let primaryPink = Color(red: 255/255, green: 73/255, blue: 129/255)
    static let primaryBlue = Color(red: 0/255, green: 122/255, blue: 255/255)
    static let primaryCyan = Color(red: 50/255, green: 198/255, blue: 255/255)
    static let successGreen = Color(red: 52/255, green: 199/255, blue: 89/255)
    static let successEmerald = Color(red: 46/255, green: 204/255, blue: 113/255)
    static let warningOrange = Color(red: 255/255, green: 149/255, blue: 0/255)
    static let warningAmber = Color(red: 241/255, green: 196/255, blue: 15/255)
    
    // Sleek Gradients
    static var heartGradient: LinearGradient {
        LinearGradient(colors: [primaryRed, primaryPink], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    static var stepsGradient: LinearGradient {
        LinearGradient(colors: [primaryBlue, primaryCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    static var successGradient: LinearGradient {
        LinearGradient(colors: [successGreen, successEmerald], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    static var warningGradient: LinearGradient {
        LinearGradient(colors: [warningOrange, warningAmber], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // Glassmorphic / Premium Card Modifier
    struct CardModifier: ViewModifier {
        let padding: CGFloat
        
        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    struct InteractiveCardModifier: ViewModifier {
        let padding: CGFloat
        @State private var isPressed = false
        
        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
    }
    
    // Action Button Styles
    struct PrimaryButtonStyle: ButtonStyle {
        let isBusy: Bool
        let gradient: LinearGradient
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(gradient)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                )
                .opacity(configuration.isPressed || isBusy ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
        }
    }
}

extension View {
    func healthCardStyle(padding: CGFloat = 16) -> some View {
        modifier(HealthSyncTheme.CardModifier(padding: padding))
    }
    
    func interactiveHealthCardStyle(padding: CGFloat = 16) -> some View {
        modifier(HealthSyncTheme.InteractiveCardModifier(padding: padding))
    }
}

// Glowing Pulse Indicator
struct PulsingDot: View {
    let color: Color
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 14, height: 14)
                .scaleEffect(animate ? 1.8 : 1.0)
                .opacity(animate ? 0.0 : 1.0)
            
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// Premium Status Pill
struct StatusBadge: View {
    let text: String
    let color: Color
    let iconName: String?
    
    var body: some View {
        HStack(spacing: 6) {
            if let iconName {
                Image(systemName: iconName)
                    .font(.caption.weight(.bold))
            } else {
                PulsingDot(color: color)
            }
            
            Text(text)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .foregroundStyle(color)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
