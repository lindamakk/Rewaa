import Foundation
import SwiftData

@MainActor
final class WaterViewModel: ObservableObject {
    @Published private(set) var todayLogs: [WaterLog] = []
    @Published var dailyGoal: Int
    @Published var reminderIntervalHours: Int

    private let modelContext: ModelContext
    private let notificationService: NotificationService
    private let defaults: UserDefaults
    private let goalKey = "waterDailyGoal"
    private let intervalKey = "waterReminderInterval"
    private let calendar = Calendar.current

    init(
        modelContext: ModelContext,
        notificationService: NotificationService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.modelContext = modelContext
        self.notificationService = notificationService
        self.defaults = defaults

        let storedGoal = defaults.integer(forKey: goalKey)
        self.dailyGoal = storedGoal == 0 ? AppConstants.defaultWaterGoal : storedGoal

        let storedInterval = defaults.integer(forKey: intervalKey)
        self.reminderIntervalHours = storedInterval == 0 ? AppConstants.defaultWaterReminderHours : storedInterval

        Task {
            refreshTodayLogs()
            await notificationService.requestAuthorizationIfNeeded()
            await notificationService.scheduleWaterReminder(intervalHours: reminderIntervalHours)
        }
    }

    var totalToday: Int {
        todayLogs.reduce(0) { $0 + $1.amount }
    }

    var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(totalToday) / Double(dailyGoal), 1)
    }

    func refreshTodayLogs() {
        let descriptor = FetchDescriptor<WaterLog>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        todayLogs = logs.filter { calendar.isDateInToday($0.timestamp) }
    }

    func addWater(amount: Int) {
        guard amount > 0 else { return }
        modelContext.insert(WaterLog(amount: amount))
        persistChanges()
        refreshTodayLogs()
    }

    func deleteLog(_ log: WaterLog) {
        modelContext.delete(log)
        persistChanges()
        refreshTodayLogs()
    }

    func updateDailyGoal(_ goal: Int) {
        dailyGoal = max(goal, 250)
        defaults.set(dailyGoal, forKey: goalKey)
    }

    func updateReminderInterval(_ hours: Int) {
        reminderIntervalHours = max(hours, 1)
        defaults.set(reminderIntervalHours, forKey: intervalKey)

        Task {
            await notificationService.scheduleWaterReminder(intervalHours: reminderIntervalHours)
        }
    }

    private func persistChanges() {
        try? modelContext.save()
    }
}
