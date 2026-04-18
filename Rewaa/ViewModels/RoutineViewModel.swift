import Combine
import Foundation
import SwiftData

@MainActor
final class RoutineViewModel: ObservableObject {
    @Published private(set) var routineItems: [RoutineItem] = []
    @Published private(set) var remainingSeconds: [UUID: Int] = [:]

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
            loadRoutineItems()
            refreshCompletionCyclesIfNeeded()
            restoreRunningTimers()
            await rescheduleAllNotifications()
        }
    }

    func loadRoutineItems() {
        let descriptor = FetchDescriptor<RoutineItem>(
            sortBy: [SortDescriptor(\.scheduledTime), SortDescriptor(\.title)]
        )
        routineItems = (try? modelContext.fetch(descriptor)) ?? []
    }

    func todayRoutineItems() -> [RoutineItem] {
        routineItems
            .filter(isScheduledForToday)
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    func groupedItems(for category: RoutineCategory?) -> [(RoutineFrequency, [RoutineItem])] {
        RoutineFrequency.allCases.compactMap { frequency in
            let items = routineItems
                .filter { $0.frequency == frequency }
                .filter { category == nil || $0.category == category }
                .sorted { $0.scheduledTime < $1.scheduledTime }

            guard !items.isEmpty else { return nil }
            return (frequency, items)
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

    func saveRoutine(
        editing item: RoutineItem?,
        title: String,
        category: RoutineCategory,
        scheduledTime: Date,
        duration: Int?,
        frequency: RoutineFrequency,
        days: [Int]
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDays = Array(Set(days)).sorted()

        let targetItem: RoutineItem
        if let item {
            clearTimerState(for: item)
            item.title = trimmedTitle
            item.category = category
            item.scheduledTime = scheduledTime
            item.duration = duration
            item.frequency = frequency
            item.days = normalizedDays
            item.notificationIdentifier = item.id.uuidString
            item.isCompleted = isCompletedInCurrentCycle(item)
            targetItem = item
        } else {
            let newItem = RoutineItem(
                title: trimmedTitle,
                category: category,
                scheduledTime: scheduledTime,
                duration: duration,
                frequency: frequency,
                days: normalizedDays
            )
            modelContext.insert(newItem)
            targetItem = newItem
        }

        persistChanges()
        loadRoutineItems()

        Task {
            await notificationService.scheduleRoutineNotifications(for: targetItem)
        }
    }

    func delete(_ item: RoutineItem) {
        stopTimer(for: item)
        modelContext.delete(item)
        persistChanges()
        loadRoutineItems()

        Task {
            await notificationService.removeRoutineNotifications(for: item.notificationIdentifier)
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
        for item in todayRoutineItems() where item.isCompleted {
            clearTimerState(for: item)
            item.isCompleted = false
            item.lastCompletedAt = nil
        }
        persistChanges()
        loadRoutineItems()
    }

    func syncTimersWithCurrentTime() {
        loadRoutineItems()
        refreshCompletionCyclesIfNeeded()
        restoreRunningTimers()
    }

    func refreshCompletionCyclesIfNeeded() {
        var needsSave = false

        for item in routineItems where item.isCompleted && !isCompletedInCurrentCycle(item) {
            item.isCompleted = false
            item.lastCompletedAt = nil
            needsSave = true
        }

        if needsSave {
            persistChanges()
            loadRoutineItems()
        }
    }

    func rescheduleAllNotifications() async {
        await notificationService.removeRoutineNotifications()
        for item in routineItems {
            await notificationService.scheduleRoutineNotifications(for: item)
        }
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
                identifier: item.notificationIdentifier,
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
            await notificationService.removeCompletionNotification(for: item.notificationIdentifier)
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
        loadRoutineItems()

        guard removePendingNotification else { return }

        Task {
            await notificationService.removeCompletionNotification(for: item.notificationIdentifier)
        }
    }

    private func isScheduledForToday(_ item: RoutineItem) -> Bool {
        switch item.frequency {
        case .daily:
            return true

        case .weekly:
            let weekday = calendar.component(.weekday, from: .now)
            let validDays = item.days.isEmpty ? [calendar.component(.weekday, from: item.scheduledTime)] : item.days
            return validDays.contains(weekday)

        case .biweekly:
            let weekday = calendar.component(.weekday, from: .now)
            let validDays = item.days.isEmpty ? [calendar.component(.weekday, from: item.scheduledTime)] : item.days
            guard validDays.contains(weekday) else { return false }

            let startOfReferenceWeek = calendar.dateInterval(of: .weekOfYear, for: item.scheduledTime)?.start ?? item.scheduledTime
            let startOfTodayWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let weeks = calendar.dateComponents([.weekOfYear], from: startOfReferenceWeek, to: startOfTodayWeek).weekOfYear ?? 0
            return weeks >= 0 && weeks % 2 == 0

        case .monthly:
            let currentDay = calendar.component(.day, from: .now)
            let scheduledDay = calendar.component(.day, from: item.scheduledTime)
            return currentDay == scheduledDay
        }
    }

    private func isCompletedInCurrentCycle(_ item: RoutineItem) -> Bool {
        guard item.isCompleted, let lastCompletedAt = item.lastCompletedAt else { return false }

        switch item.frequency {
        case .daily:
            return calendar.isDate(lastCompletedAt, inSameDayAs: .now)

        case .weekly:
            return calendar.isDate(lastCompletedAt, equalTo: .now, toGranularity: .weekOfYear)

        case .biweekly:
            let startOfReferenceWeek = calendar.dateInterval(of: .weekOfYear, for: item.scheduledTime)?.start ?? item.scheduledTime
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
        for item in routineItems {
            guard let endDate = item.timerEndDate else { continue }

            if endDate <= Date() {
                complete(item, removePendingNotification: false)
            } else {
                remainingSeconds[item.id] = max(Int(ceil(endDate.timeIntervalSinceNow)), 1)
                scheduleLiveTimer(for: item)
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
            await notificationService.removeCompletionNotification(for: item.notificationIdentifier)
        }
    }
}
