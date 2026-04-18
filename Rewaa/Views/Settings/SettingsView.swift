import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var routineViewModel: RoutineViewModel
    @EnvironmentObject private var waterViewModel: WaterViewModel
    @AppStorage("preferredAppearance") private var preferredAppearance = AppearanceOption.system.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("Water") {
                    Stepper(value: goalBinding, in: 250...6_000, step: 250) {
                        Text("Daily goal: \(waterViewModel.dailyGoal) ml")
                    }

                    Stepper(value: intervalBinding, in: 1...12) {
                        Text("Reminder every \(waterViewModel.reminderIntervalHours) hour\(waterViewModel.reminderIntervalHours == 1 ? "" : "s")")
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $preferredAppearance) {
                        ForEach(AppearanceOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                }

                Section("Routine") {
                    Button("Reset today's completions") {
                        routineViewModel.resetTodayCompletions()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .formStyle(.grouped)
        }
    }

    private var goalBinding: Binding<Int> {
        Binding(
            get: { waterViewModel.dailyGoal },
            set: { waterViewModel.updateDailyGoal($0) }
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { waterViewModel.reminderIntervalHours },
            set: { waterViewModel.updateReminderInterval($0) }
        )
    }
}
