import Foundation

enum AppConstants {
    static let appName = "رواء Rewaa"
    static let waterReminderIdentifier = "water-reminder"
    static let defaultWaterGoal = 2_000
    static let defaultWaterReminderHours = 2
    static let quickWaterAmounts = [250, 500]
    static let weekdaySymbols = [
        1: "Sun",
        2: "Mon",
        3: "Tue",
        4: "Wed",
        5: "Thu",
        6: "Fri",
        7: "Sat"
    ]
}

enum AppearanceOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}
