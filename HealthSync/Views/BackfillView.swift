import SwiftUI

struct BackfillView: View {
    @EnvironmentObject private var appState: AppState
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()

    var body: some View {
        Form {
            Section("Date Range") {
                DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
            }

            Section {
                Button {
                    Task { await appState.backfill(start: startDate, end: endDate) }
                } label: {
                    if appState.isBusy {
                        ProgressView()
                    } else {
                        Label("Start backfill", systemImage: "tray.and.arrow.up")
                    }
                }
                .disabled(endDate <= startDate)

                if appState.backfillProgress > 0 {
                    ProgressView(value: appState.backfillProgress)
                }
            }
        }
        .navigationTitle("Backfill")
    }
}
