import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")

    private init() {}

    func requestAuthorizationIfNeeded() async {
        guard !isUITesting else { return }

        let settings = await notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        _ = try? await requestAuthorization(
            options: [.alert, .badge, .sound]
        )
    }

    func removeRoutineNotifications(for baseIdentifier: String? = nil) async {
        let requests = await pendingRequests()
        let ids = requests
            .map(\.identifier)
            .filter { identifier in
                guard let baseIdentifier else {
                    return identifier.hasPrefix("routine-")
                }
                return identifier.contains(baseIdentifier)
            }

        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func scheduleRoutineNotifications(for item: RoutineItem) async {
        await removeRoutineNotifications(for: item.notificationIdentifier)

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = "Time for your \(item.category.title.lowercased()) routine."
        content.sound = .default

        let requests = routineRequests(for: item, content: content)
        for request in requests {
            try? await add(request)
        }
    }

    func scheduleCompletionNotification(for title: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Routine Complete"
        content.body = "✅ \(title) done!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(identifier)-completion",
            content: content,
            trigger: trigger
        )

        try? await add(request)
    }

    func scheduleWaterReminder(intervalHours: Int) async {
        await removeWaterReminder()

        let content = UNMutableNotificationContent()
        content.title = "Hydration Check"
        content.body = "Drink some water to stay refreshed."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(intervalHours, 1) * 3_600),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: AppConstants.waterReminderIdentifier,
            content: content,
            trigger: trigger
        )

        try? await add(request)
    }

    func removeWaterReminder() async {
        center.removePendingNotificationRequests(
            withIdentifiers: [AppConstants.waterReminderIdentifier]
        )
    }

    private func routineRequests(
        for item: RoutineItem,
        content: UNMutableNotificationContent
    ) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: item.scheduledTime)
        let baseIdentifier = "routine-\(item.notificationIdentifier)"

        switch item.frequency {
        case .daily:
            let components = DateComponents(
                hour: timeComponents.hour,
                minute: timeComponents.minute
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [UNNotificationRequest(identifier: baseIdentifier, content: content, trigger: trigger)]

        case .weekly:
            let weekdays = item.days.isEmpty
                ? [calendar.component(.weekday, from: item.scheduledTime)]
                : item.days

            return weekdays.map { weekday in
                let components = DateComponents(
                    hour: timeComponents.hour,
                    minute: timeComponents.minute,
                    weekday: weekday
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                return UNNotificationRequest(
                    identifier: "\(baseIdentifier)-weekly-\(weekday)",
                    content: content,
                    trigger: trigger
                )
            }

        case .biweekly:
            let weekdays = item.days.isEmpty
                ? [calendar.component(.weekday, from: item.scheduledTime)]
                : item.days

            let dates = weekdays.flatMap { weekday in
                upcomingBiweeklyDates(
                    from: item.scheduledTime,
                    weekday: weekday,
                    occurrences: 12
                )
            }

            return dates.enumerated().map { index, date in
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                return UNNotificationRequest(
                    identifier: "\(baseIdentifier)-biweekly-\(index)",
                    content: content,
                    trigger: trigger
                )
            }

        case .monthly:
            let day = calendar.component(.day, from: item.scheduledTime)
            let components = DateComponents(
                day: day,
                hour: timeComponents.hour,
                minute: timeComponents.minute
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [UNNotificationRequest(identifier: "\(baseIdentifier)-monthly", content: content, trigger: trigger)]
        }
    }

    private func upcomingBiweeklyDates(
        from referenceDate: Date,
        weekday: Int,
        occurrences: Int
    ) -> [Date] {
        let calendar = Calendar.current
        let referenceWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
        let referenceWeekday = calendar.component(.weekday, from: referenceWeek)
        let weekdayOffset = (weekday - referenceWeekday + 7) % 7
        let referenceDay = calendar.date(byAdding: .day, value: weekdayOffset, to: referenceWeek) ?? referenceDate

        let time = calendar.dateComponents([.hour, .minute], from: referenceDate)
        let anchoredReference = calendar.date(
            bySettingHour: time.hour ?? 9,
            minute: time.minute ?? 0,
            second: 0,
            of: referenceDay
        ) ?? referenceDate

        var dates: [Date] = []
        var candidate = anchoredReference

        while candidate < Date() {
            candidate = calendar.date(byAdding: .day, value: 14, to: candidate) ?? candidate
        }

        while dates.count < occurrences {
            dates.append(candidate)
            candidate = calendar.date(byAdding: .day, value: 14, to: candidate) ?? candidate
        }

        return dates
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: options) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
