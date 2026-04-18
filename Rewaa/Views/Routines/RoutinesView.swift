import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var routineViewModel: RoutineViewModel

    @State private var selectedFilter: RoutineCategory?
    @State private var editingGroup: RoutineGroup?
    @State private var isPresentingAddGroup = false

    var body: some View {
        NavigationStack {
            List {
                filterSection

                if routineViewModel.groupedRoutines(for: selectedFilter).isEmpty {
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
                    ForEach(routineViewModel.groupedRoutines(for: selectedFilter), id: \.0) { frequency, groups in
                        Section(frequency.title) {
                            ForEach(groups) { group in
                                groupRow(group)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            routineViewModel.delete(group)
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
                        isPresentingAddGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingGroup) { group in
                AddEditGroupView(editingGroup: group)
            }
            .sheet(isPresented: $isPresentingAddGroup) {
                AddEditGroupView()
            }
        }
    }

    private func groupRow(_ group: RoutineGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                    Text(group.scheduledTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if routineViewModel.allItemsCompleted(in: group) {
                    Text("Done")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.sage)
                }

                Image(systemName: routineViewModel.isExpanded(group) ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if routineViewModel.isExpanded(group) {
                ForEach(group.items.sorted(by: { $0.order < $1.order })) { item in
                    RoutineItemRow(item: item)
                }

                Button("Edit Group") {
                    editingGroup = group
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.rose)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            routineViewModel.toggleGroupExpansion(group)
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
