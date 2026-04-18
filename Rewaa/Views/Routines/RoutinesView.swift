import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var routineViewModel: RoutineViewModel

    @State private var selectedFilter: RoutineCategory?
    @State private var editingItem: RoutineItem?
    @State private var isPresentingAddRoutine = false

    var body: some View {
        NavigationStack {
            List {
                filterSection

                if routineViewModel.groupedItems(for: selectedFilter).isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.sage)

                            Text("No routines yet")
                                .font(.headline)

                            Text("Create skin, hair, or wellness reminders to see them here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(routineViewModel.groupedItems(for: selectedFilter), id: \.0) { frequency, items in
                        Section(frequency.title) {
                            ForEach(items) { item in
                                RoutineItemRow(item: item)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .contentShape(Rectangle()).padding(.vertical, 6)
                                    .onTapGesture {
                                        editingItem = item
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            routineViewModel.delete(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .listStyle(.automatic)
            .scrollContentBackground(.hidden)
            .background(Theme.cream.opacity(0.35))
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddRoutine = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingItem) { item in
                AddEditRoutineView(editingItem: item)
            }
            .sheet(isPresented: $isPresentingAddRoutine) {
                AddEditRoutineView()
            }
        }
    }

    private var filterSection: some View {
        Section {
            Picker("Category", selection: filterBinding) {
                Text("All").tag(Optional<RoutineCategory>.none)
                ForEach(RoutineCategory.allCases) { category in
                    Text(category.title).tag(Optional(category))
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(Color.clear)
    }

    private var filterBinding: Binding<RoutineCategory?> {
        Binding(
            get: { selectedFilter },
            set: { selectedFilter = $0 }
        )
    }
}
