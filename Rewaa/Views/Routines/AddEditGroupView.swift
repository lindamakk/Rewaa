import SwiftUI

struct AddEditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var routineViewModel: RoutineViewModel

    private let editingGroup: RoutineGroup?

    @State private var name: String
    @State private var scheduledTime: Date
    @State private var frequency: RoutineFrequency
    @State private var selectedDays: Set<Int>
    @State private var items: [EditableRoutineItem]
    @State private var editingItem: EditableRoutineItem?
    @State private var isPresentingItemSheet = false

    init(editingGroup: RoutineGroup? = nil) {
        self.editingGroup = editingGroup
        _name = State(initialValue: editingGroup?.name ?? "")
        _scheduledTime = State(initialValue: editingGroup?.scheduledTime ?? .now)
        _frequency = State(initialValue: editingGroup?.frequency ?? .daily)
        _selectedDays = State(initialValue: Set(editingGroup?.days ?? []))
        _items = State(initialValue: editingGroup?.items.sorted(by: { $0.order < $1.order }).map {
            EditableRoutineItem(
                id: $0.id,
                title: $0.title,
                category: $0.category,
                duration: $0.duration,
                order: $0.order
            )
        } ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group") {
                    TextField("Group name", text: $name)

                    DatePicker(
                        "Time",
                        selection: $scheduledTime,
                        displayedComponents: .hourAndMinute
                    )

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

                Section("Items") {
                    if items.isEmpty {
                        Text("Add items to this routine group.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.category.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let duration = item.duration {
                                    Text("\(duration) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingItem = item
                                isPresentingItemSheet = true
                            }
                        }
                        .onMove(perform: moveItems)
                        .onDelete(perform: deleteItems)
                    }

                    Button {
                        editingItem = nil
                        isPresentingItemSheet = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(editingGroup == nil ? "Add Group" : "Edit Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        routineViewModel.saveGroup(
                            editing: editingGroup,
                            name: name,
                            scheduledTime: scheduledTime,
                            frequency: frequency,
                            days: Array(selectedDays).sorted(),
                            items: normalizedItems
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .disabled(items.isEmpty)
                }
            }
            .sheet(isPresented: $isPresentingItemSheet) {
                AddEditItemView(item: editingItem) { savedItem in
                    upsert(savedItem)
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
        let hasValidName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let needsDays = frequency == .weekly || frequency == .biweekly
        return hasValidName && !items.isEmpty && (!needsDays || !selectedDays.isEmpty)
    }

    private var normalizedItems: [EditableRoutineItem] {
        items.enumerated().map { index, item in
            var updated = item
            updated.order = index
            return updated
        }
    }

    private func upsert(_ item: EditableRoutineItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }

        for index in items.indices {
            items[index].order = index
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        for index in items.indices {
            items[index].order = index
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        for index in items.indices {
            items[index].order = index
        }
    }
}
