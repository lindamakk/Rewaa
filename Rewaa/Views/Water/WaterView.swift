import SwiftUI

struct WaterView: View {
    @EnvironmentObject private var waterViewModel: WaterViewModel

    @State private var isPresentingCustomAmount = false
    @State private var customAmount = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WaterProgressCard(
                        total: waterViewModel.totalToday,
                        goal: waterViewModel.dailyGoal,
                        reminderInterval: waterViewModel.reminderIntervalHours,
                        onQuickAdd: { amount in
                            waterViewModel.addWater(amount: amount)
                        },
                        onCustomAdd: {
                            isPresentingCustomAmount = true
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Reminder Interval") {
                    Stepper(value: reminderBinding, in: 1...12) {
                        Text("Every \(waterViewModel.reminderIntervalHours) hour\(waterViewModel.reminderIntervalHours == 1 ? "" : "s")")
                    }
                }

                Section("Today's Logs") {
                    if waterViewModel.todayLogs.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "drop")
                                .font(.system(size: 30))
                                .foregroundStyle(Theme.sage)
                            Text("No water logged today")
                                .font(.headline)
                            Text("Use the quick-add buttons to stay on track.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(waterViewModel.todayLogs) { log in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(log.amount) ml")
                                        .font(.headline)
                                    Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    waterViewModel.deleteLog(log)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.automatic)
            .scrollContentBackground(.hidden)
            .background(Theme.cream.opacity(0.35))
            .navigationTitle("Water")
            .sheet(isPresented: $isPresentingCustomAmount) {
                NavigationStack {
                    Form {
                        TextField("Amount in ml", text: $customAmount)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif
                    }
                    .navigationTitle("Custom Water")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                customAmount = ""
                                isPresentingCustomAmount = false
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                if let amount = Int(customAmount), amount > 0 {
                                    waterViewModel.addWater(amount: amount)
                                }
                                customAmount = ""
                                isPresentingCustomAmount = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var reminderBinding: Binding<Int> {
        Binding(
            get: { waterViewModel.reminderIntervalHours },
            set: { waterViewModel.updateReminderInterval($0) }
        )
    }
}
