import SwiftUI

struct AddEditRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var routineViewModel: RoutineViewModel

    private let editingItem: RoutineItem?

    @State private var title: String
    @State private var category: RoutineCategory
    @State private var scheduledTime: Date
    @State private var frequency: RoutineFrequency
    @State private var selectedDays: Set<Int>
    @State private var hasDuration: Bool
    @State private var duration: Int

    init(editingItem: RoutineItem? = nil) {
        self.editingItem = editingItem
        _title = State(initialValue: editingItem?.title ?? "")
        _category = State(initialValue: editingItem?.category ?? .skin)
        _scheduledTime = State(initialValue: editingItem?.scheduledTime ?? .now)
        _frequency = State(initialValue: editingItem?.frequency ?? .daily)
        _selectedDays = State(initialValue: Set(editingItem?.days ?? []))
        _hasDuration = State(initialValue: (editingItem?.duration ?? 0) > 0)
        _duration = State(initialValue: editingItem?.duration ?? 10)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Title", text: $title)

                    Picker("Category", selection: $category) {
                        ForEach(RoutineCategory.allCases) { category in
                            Text("\(category.icon) \(category.title)").tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker(
                        "Time",
                        selection: $scheduledTime,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        ForEach(RoutineFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)

                    if frequency == .weekly || frequency == .biweekly {
                        weekdaySelector
                    }
                }

                Section("Duration") {
                    Toggle("Use countdown timer", isOn: $hasDuration.animation())

                    if hasDuration {
                        Stepper(value: $duration, in: 1...120) {
                            Text("\(duration) min")
                        }

                        Text("e.g. 10 min face mask")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(editingItem == nil ? "Add Routine" : "Edit Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        routineViewModel.saveRoutine(
                            editing: editingItem,
                            title: title,
                            category: category,
                            scheduledTime: scheduledTime,
                            duration: hasDuration ? duration : nil,
                            frequency: frequency,
                            days: Array(selectedDays).sorted()
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var weekdaySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Days")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    } label: {
                        Text(AppConstants.weekdaySymbols[day] ?? "")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedDays.contains(day) ? Theme.rose : Theme.cream)
                            .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var canSave: Bool {
        let hasValidTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let needsDays = frequency == .weekly || frequency == .biweekly
        return hasValidTitle && (!needsDays || !selectedDays.isEmpty)
    }
}
