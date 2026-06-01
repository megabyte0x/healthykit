import SwiftUI

struct BackfillView: View {
    @EnvironmentObject private var appState: AppState
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()

    var body: some View {
        ZStack {
            HealthSyncTheme.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Info Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(HealthSyncTheme.primaryBlue)
                        Text("Legacy Backfill Zone")
                            .font(.headline)
                    }
                    
                    Text("Select a custom date range to fetch historical metrics and workouts from Apple Health, normalize them, and upload them securely to your database.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .healthCardStyle(padding: 16)
                .padding(.top, 16)
                
                // Date Selectors Card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(HealthSyncTheme.primaryPink)
                        Text("Select Date Range")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .font(.subheadline.weight(.medium))
                        
                        DatePicker("End Date", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                            .font(.subheadline.weight(.medium))
                    }
                }
                .healthCardStyle(padding: 16)
                
                // Progress / Action Card
                VStack(spacing: 16) {
                    let isInvalidRange = endDate <= startDate
                    
                    if appState.backfillProgress > 0 && appState.isBusy {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Backfill in progress...")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(Int(appState.backfillProgress * 100))%")
                                    .font(.subheadline.weight(.bold).monospaced())
                                    .foregroundStyle(HealthSyncTheme.primaryBlue)
                            }
                            
                            ProgressView(value: appState.backfillProgress)
                                .tint(HealthSyncTheme.stepsGradient)
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            HStack(spacing: 6) {
                                PulsingDot(color: HealthSyncTheme.primaryBlue)
                                Text("Uploading chunks securely...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } else if let backfillError = appState.backfillError, !appState.isBusy {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(HealthSyncTheme.primaryRed.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(HealthSyncTheme.primaryRed)
                                    .font(.title3)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Backfill Failed")
                                    .font(.subheadline.weight(.bold))
                                Text(backfillError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(HealthSyncTheme.primaryRed.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HealthSyncTheme.primaryRed.opacity(0.2), lineWidth: 1)
                        )
                    } else if appState.backfillProgress == 1.0 && !appState.isBusy {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(HealthSyncTheme.successGreen.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HealthSyncTheme.successGreen)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Backfill Successful!")
                                    .font(.subheadline.weight(.bold))
                                Text("All historical data uploaded and synced.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(HealthSyncTheme.successGreen.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HealthSyncTheme.successGreen.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    Button {
                        Task { await appState.backfill(start: startDate, end: endDate) }
                    } label: {
                        HStack {
                            if appState.isBusy {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "tray.and.arrow.up.fill")
                                Text("Start Backfill Sync")
                            }
                        }
                    }
                    .buttonStyle(HealthSyncTheme.PrimaryButtonStyle(
                        isBusy: appState.isBusy,
                        gradient: isInvalidRange || appState.isBusy ? LinearGradient(colors: [.secondary, .secondary], startPoint: .top, endPoint: .bottom) : HealthSyncTheme.heartGradient
                    ))
                    .disabled(isInvalidRange || appState.isBusy)
                    
                    if isInvalidRange {
                        Text("End date must be strictly after start date")
                            .font(.caption)
                            .foregroundStyle(HealthSyncTheme.primaryRed)
                    }
                }
                .healthCardStyle(padding: 16)
                
                Spacer()
            }
            .padding(16)
        }
        .navigationTitle("Backfill")
        .navigationBarTitleDisplayMode(.inline)
    }
}
