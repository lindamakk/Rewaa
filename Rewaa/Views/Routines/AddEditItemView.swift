import SwiftUI

struct AddEditItemView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var category: RoutineCategory
    @State private var hasDuration: Bool
    @State private var duration: Int

    let onSave: (EditableRoutineItem) -> Void
    private let existingItem: EditableRoutineItem?

    init(
        item: EditableRoutineItem? = nil,
        onSave: @escaping (EditableRoutineItem) -> Void
    ) {
        self.onSave = onSave
        self.existingItem = item
        _title = State(initialValue: item?.title ?? "")
        _category = State(initialValue: item?.category ?? .skin)
        _hasDuration = State(initialValue: (item?.duration ?? 0) > 0)
        _duration = State(initialValue: item?.duration ?? 10)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $title)

                    Picker("Category", selection: $category) {
                        ForEach(RoutineCategory.allCases) { category in
                            Text("\(category.icon) \(category.title)").tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Duration") {
                    Toggle("Use countdown timer", isOn: $hasDuration.animation())

                    if hasDuration {
                        Stepper(value: $duration, in: 1...120) {
                            Text("\(duration) min")
                        }
                    }
                }
            }
            .navigationTitle(existingItem == nil ? "Add Item" : "Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            EditableRoutineItem(
                                id: existingItem?.id ?? UUID(),
                                title: title,
                                category: category,
                                duration: hasDuration ? duration : nil,
                                order: existingItem?.order ?? 0
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
