import Foundation
import UserNotifications

extension Notification.Name {
    static let openRoutineGroup = Notification.Name("openRoutineGroup")
}

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")

    private override init() {
        super.init()
        center.delegate = self
    }

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

    func scheduleRoutineNotification(for group: RoutineGroup) async {
        await removeRoutineNotifications(for: group.notificationIdentifier)

        let content = UNMutableNotificationContent()
        content.title = group.name
        content.body = "Time for your \(group.name)! 🌿"
        content.sound = .default
        content.userInfo = ["routineGroupID": group.id.uuidString]

        let requests = routineRequests(for: group, content: content)
        for request in requests {
            try? await add(request)
        }
    }

    func cancelRoutineNotification(for group: RoutineGroup) async {
        await removeRoutineNotifications(for: group.notificationIdentifier)
    }

    func scheduleCompletionNotification(
        for title: String,
        identifier: String,
        timeInterval: TimeInterval
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Routine Complete"
        content.body = "✅ \(title) done!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(timeInterval, 1),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: completionNotificationIdentifier(for: identifier),
            content: content,
            trigger: trigger
        )

        try? await add(request)
    }

    func removeCompletionNotification(for identifier: String) async {
        center.removePendingNotificationRequests(
            withIdentifiers: [completionNotificationIdentifier(for: identifier)]
        )
    }

    func completionNotificationIdentifier(for identifier: String) -> String {
        "routine-completion-\(identifier)"
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let groupID = response.notification.request.content.userInfo["routineGroupID"] as? String else {
            return
        }

        NotificationCenter.default.post(
            name: .openRoutineGroup,
            object: nil,
            userInfo: ["routineGroupID": groupID]
        )
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
        for group: RoutineGroup,
        content: UNMutableNotificationContent
    ) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: group.scheduledTime)
        let baseIdentifier = "routine-\(group.notificationIdentifier)"

        switch group.frequency {
        case .daily:
            let components = DateComponents(
                hour: timeComponents.hour,
                minute: timeComponents.minute
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [UNNotificationRequest(identifier: baseIdentifier, content: content, trigger: trigger)]

        case .weekly:
            let weekdays = group.days.isEmpty
                ? [calendar.component(.weekday, from: group.scheduledTime)]
                : group.days

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
            let weekdays = group.days.isEmpty
                ? [calendar.component(.weekday, from: group.scheduledTime)]
                : group.days

            let dates = weekdays.flatMap { weekday in
                upcomingBiweeklyDates(
                    from: group.scheduledTime,
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
            let day = calendar.component(.day, from: group.scheduledTime)
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
