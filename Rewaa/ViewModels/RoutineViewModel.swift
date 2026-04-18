import Combine
import Foundation
import SwiftData

@MainActor
final class RoutineViewModel: ObservableObject {
    @Published private(set) var routineGroups: [RoutineGroup] = []
    @Published private(set) var remainingSeconds: [UUID: Int] = [:]
    @Published var expandedGroupIDs: Set<UUID> = []
    @Published var focusedGroupID: UUID?

    private(set) var activeTimers: [UUID: AnyCancellable] = [:]
    private let modelContext: ModelContext
    private let notificationService: NotificationService
    private let calendar = Calendar.current

    init(
        modelContext: ModelContext,
        notificationService: NotificationService = .shared
    ) {
        self.modelContext = modelContext
        self.notificationService = notificationService

        Task {
            await notificationService.requestAuthorizationIfNeeded()
            loadRoutineGroups()
            refreshCompletionCyclesIfNeeded()
            restoreRunningTimers()
            await rescheduleAllNotifications()
        }
    }

    func loadRoutineGroups() {
        let descriptor = FetchDescriptor<RoutineGroup>(
            sortBy: [SortDescriptor(\.scheduledTime), SortDescriptor(\.name)]
        )
        routineGroups = ((try? modelContext.fetch(descriptor)) ?? []).map { group in
            group.items.sort { lhs, rhs in
                if lhs.order == rhs.order {
                    return lhs.title < rhs.title
                }
                return lhs.order < rhs.order
            }
            return group
        }
    }

    func todayRoutineGroups() -> [RoutineGroup] {
        routineGroups
            .filter(isScheduledForToday)
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    func groupedRoutines(for category: RoutineCategory?) -> [(RoutineFrequency, [RoutineGroup])] {
        RoutineFrequency.allCases.compactMap { frequency in
            let groups = routineGroups
                .filter { $0.frequency == frequency }
                .filter { group in
                    guard let category else { return true }
                    return group.items.contains { $0.category == category }
                }
                .sorted { $0.name < $1.name }

            guard !groups.isEmpty else { return nil }
            return (frequency, groups)
        }
    }

    func isTimerRunning(for item: RoutineItem) -> Bool {
        activeTimers[item.id] != nil
    }

    func formattedRemaining(for item: RoutineItem) -> String {
        let total = remainingSeconds[item.id] ?? 0
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func saveGroup(
        editing group: RoutineGroup?,
        name: String,
        scheduledTime: Date,
        frequency: RoutineFrequency,
        days: [Int],
        items: [EditableRoutineItem]
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDays = Array(Set(days)).sorted()
        let normalizedItems = items.enumerated().map { index, item in
            EditableRoutineItem(
                id: item.id,
                title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                category: item.category,
                duration: item.duration,
                order: index
            )
        }

        let targetGroup: RoutineGroup
        if let group {
            for existingItem in group.items where !normalizedItems.contains(where: { $0.id == existingItem.id }) {
                clearTimerState(for: existingItem)
                modelContext.delete(existingItem)
            }

            group.name = trimmedName
            group.scheduledTime = scheduledTime
            group.frequency = frequency
            group.days = normalizedDays

            for itemData in normalizedItems {
                if let existingItem = group.items.first(where: { $0.id == itemData.id }) {
                    clearTimerState(for: existingItem)
                    existingItem.title = itemData.title
                    existingItem.category = itemData.category
                    existingItem.duration = itemData.duration
                    existingItem.order = itemData.order
                    existingItem.isCompleted = isCompletedInCurrentCycle(existingItem, for: group)
                } else {
                    let newItem = RoutineItem(
                        id: itemData.id,
                        title: itemData.title,
                        category: itemData.category,
                        duration: itemData.duration,
                        order: itemData.order,
                        group: group
                    )
                    group.items.append(newItem)
                    modelContext.insert(newItem)
                }
            }

            targetGroup = group
        } else {
            let newItems = normalizedItems.map { itemData in
                RoutineItem(
                    id: itemData.id,
                    title: itemData.title,
                    category: itemData.category,
                    duration: itemData.duration,
                    order: itemData.order
                )
            }

            let newGroup = RoutineGroup(
                name: trimmedName,
                scheduledTime: scheduledTime,
                frequency: frequency,
                days: normalizedDays,
                items: newItems
            )
            newItems.forEach { $0.group = newGroup }
            modelContext.insert(newGroup)
            targetGroup = newGroup
        }

        persistChanges()
        loadRoutineGroups()
        expandedGroupIDs.insert(targetGroup.id)

        Task {
            await notificationService.scheduleRoutineNotification(for: targetGroup)
        }
    }

    func delete(_ group: RoutineGroup) {
        for item in group.items {
            clearTimerState(for: item)
        }

        modelContext.delete(group)
        persistChanges()
        loadRoutineGroups()
        expandedGroupIDs.remove(group.id)

        Task {
            await cancelNotification(for: group)
        }
    }

    func handlePrimaryAction(for item: RoutineItem) {
        if isTimerRunning(for: item) {
            stopTimer(for: item)
            return
        }

        guard !item.isCompleted else { return }

        if let duration = item.duration, duration > 0 {
            startTimer(for: item, durationInMinutes: duration)
        } else {
            complete(item)
        }
    }

    func resetTodayCompletions() {
        for group in todayRoutineGroups() {
            for item in group.items where item.isCompleted {
                clearTimerState(for: item)
                item.isCompleted = false
                item.lastCompletedAt = nil
            }
        }
        persistChanges()
        loadRoutineGroups()
    }

    func syncTimersWithCurrentTime() {
        loadRoutineGroups()
        refreshCompletionCyclesIfNeeded()
        restoreRunningTimers()
    }

    func refreshCompletionCyclesIfNeeded() {
        var needsSave = false

        for group in routineGroups {
            for item in group.items where item.isCompleted && !isCompletedInCurrentCycle(item, for: group) {
                item.isCompleted = false
                item.lastCompletedAt = nil
                needsSave = true
            }
        }

        if needsSave {
            persistChanges()
            loadRoutineGroups()
        }
    }

    func rescheduleAllNotifications() async {
        await notificationService.removeRoutineNotifications()
        for group in routineGroups {
            await scheduleNotification(for: group)
        }
    }

    func scheduleNotification(for group: RoutineGroup) async {
        await notificationService.scheduleRoutineNotification(for: group)
    }

    func cancelNotification(for group: RoutineGroup) async {
        await notificationService.cancelRoutineNotification(for: group)
    }

    func toggleGroupExpansion(_ group: RoutineGroup) {
        if expandedGroupIDs.contains(group.id) {
            expandedGroupIDs.remove(group.id)
        } else {
            expandedGroupIDs.insert(group.id)
        }
    }

    func isExpanded(_ group: RoutineGroup) -> Bool {
        expandedGroupIDs.contains(group.id)
    }

    func allItemsCompleted(in group: RoutineGroup) -> Bool {
        !group.items.isEmpty && group.items.allSatisfy(\.isCompleted)
    }

    func focusGroup(with id: UUID) {
        focusedGroupID = id
        expandedGroupIDs.insert(id)
    }

    private func startTimer(for item: RoutineItem, durationInMinutes: Int) {
        let durationInSeconds = durationInMinutes * 60
        item.timerEndDate = Date().addingTimeInterval(TimeInterval(durationInSeconds))
        persistChanges()

        remainingSeconds[item.id] = durationInSeconds
        scheduleLiveTimer(for: item)

        Task {
            await notificationService.scheduleCompletionNotification(
                for: item.title,
                identifier: item.id.uuidString,
                timeInterval: TimeInterval(durationInSeconds)
            )
        }
    }

    private func tick(for item: RoutineItem) {
        guard let endDate = item.timerEndDate else {
            stopTimer(for: item)
            return
        }

        let seconds = max(Int(ceil(endDate.timeIntervalSinceNow)), 0)
        if seconds == 0 {
            complete(item, removePendingNotification: false)
        } else {
            remainingSeconds[item.id] = seconds
        }
    }

    private func stopTimer(for item: RoutineItem) {
        activeTimers[item.id]?.cancel()
        activeTimers[item.id] = nil
        remainingSeconds[item.id] = nil
        item.timerEndDate = nil
        persistChanges()

        Task {
            await notificationService.removeCompletionNotification(for: item.id.uuidString)
        }
    }

    private func complete(_ item: RoutineItem, removePendingNotification: Bool = true) {
        activeTimers[item.id]?.cancel()
        activeTimers[item.id] = nil
        remainingSeconds[item.id] = nil
        item.timerEndDate = nil
        item.isCompleted = true
        item.lastCompletedAt = .now
        persistChanges()
        loadRoutineGroups()

        guard removePendingNotification else { return }

        Task {
            await notificationService.removeCompletionNotification(for: item.id.uuidString)
        }
    }

    private func isScheduledForToday(_ group: RoutineGroup) -> Bool {
        switch group.frequency {
        case .daily:
            return true

        case .weekly:
            let weekday = calendar.component(.weekday, from: .now)
            let validDays = group.days.isEmpty ? [calendar.component(.weekday, from: group.scheduledTime)] : group.days
            return validDays.contains(weekday)

        case .biweekly:
            let weekday = calendar.component(.weekday, from: .now)
            let validDays = group.days.isEmpty ? [calendar.component(.weekday, from: group.scheduledTime)] : group.days
            guard validDays.contains(weekday) else { return false }

            let startOfReferenceWeek = calendar.dateInterval(of: .weekOfYear, for: group.scheduledTime)?.start ?? group.scheduledTime
            let startOfTodayWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let weeks = calendar.dateComponents([.weekOfYear], from: startOfReferenceWeek, to: startOfTodayWeek).weekOfYear ?? 0
            return weeks >= 0 && weeks % 2 == 0

        case .monthly:
            let currentDay = calendar.component(.day, from: .now)
            let scheduledDay = calendar.component(.day, from: group.scheduledTime)
            return currentDay == scheduledDay
        }
    }

    private func isCompletedInCurrentCycle(_ item: RoutineItem, for group: RoutineGroup) -> Bool {
        guard item.isCompleted, let lastCompletedAt = item.lastCompletedAt else { return false }

        switch group.frequency {
        case .daily:
            return calendar.isDate(lastCompletedAt, inSameDayAs: .now)

        case .weekly:
            return calendar.isDate(lastCompletedAt, equalTo: .now, toGranularity: .weekOfYear)

        case .biweekly:
            let startOfReferenceWeek = calendar.dateInterval(of: .weekOfYear, for: group.scheduledTime)?.start ?? group.scheduledTime
            let completedWeek = calendar.dateInterval(of: .weekOfYear, for: lastCompletedAt)?.start ?? lastCompletedAt
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let completedOffset = calendar.dateComponents([.weekOfYear], from: startOfReferenceWeek, to: completedWeek).weekOfYear ?? -1
            let currentOffset = calendar.dateComponents([.weekOfYear], from: startOfReferenceWeek, to: currentWeek).weekOfYear ?? -2
            return completedOffset >= 0 && completedOffset == currentOffset

        case .monthly:
            return calendar.isDate(lastCompletedAt, equalTo: .now, toGranularity: .month)
        }
    }

    private func persistChanges() {
        try? modelContext.save()
    }

    private func restoreRunningTimers() {
        for group in routineGroups {
            for item in group.items {
            guard let endDate = item.timerEndDate else { continue }

            if endDate <= Date() {
                complete(item, removePendingNotification: false)
            } else {
                remainingSeconds[item.id] = max(Int(ceil(endDate.timeIntervalSinceNow)), 1)
                scheduleLiveTimer(for: item)
            }
            }
        }
    }

    private func scheduleLiveTimer(for item: RoutineItem) {
        activeTimers[item.id]?.cancel()

        let timer = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick(for: item)
            }

        activeTimers[item.id] = timer
    }

    private func clearTimerState(for item: RoutineItem) {
        activeTimers[item.id]?.cancel()
        activeTimers[item.id] = nil
        remainingSeconds[item.id] = nil
        item.timerEndDate = nil

        Task {
            await notificationService.removeCompletionNotification(for: item.id.uuidString)
        }
    }
}

struct EditableRoutineItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var category: RoutineCategory
    var duration: Int?
    var order: Int

    init(
        id: UUID = UUID(),
        title: String = "",
        category: RoutineCategory = .skin,
        duration: Int? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.duration = duration
        self.order = order
    }
}
