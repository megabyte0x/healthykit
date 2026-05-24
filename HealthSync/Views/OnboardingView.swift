import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("HealthSync")
                        .font(.largeTitle.bold())
                    Text("Read selected Apple Health metrics and workouts on this iPhone, then sync them only to the private backend you configure.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Steps, heart metrics, energy, body composition, sleep, workouts, and optional dietary data", systemImage: "heart.text.square")
                    Label("Read-only HealthKit access", systemImage: "lock.shield")
                    Label("Token stored in Keychain", systemImage: "key")
                }
                .font(.callout)

                Spacer()

                Button {
                    Task { await appState.connectAppleHealth() }
                } label: {
                    if appState.isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Connect Apple Health", systemImage: "heart")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)

                if let error = appState.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Onboarding")
        }
    }
}
