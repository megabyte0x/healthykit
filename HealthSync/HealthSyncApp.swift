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
