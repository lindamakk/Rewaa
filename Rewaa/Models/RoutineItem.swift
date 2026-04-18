import Foundation
import SwiftData

enum RoutineCategory: String, Codable, CaseIterable, Identifiable {
    case skin
    case hair
    case nutrition
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skin:
            return "Skin"
        case .hair:
            return "Hair"
        case .nutrition:
            return "Nutrition"
        case .other:
            return "Other"
        }
    }

    var icon: String {
        switch self {
        case .skin:
            return "🧴"
        case .hair:
            return "💇🏻‍♀️"
        case .nutrition:
            return "🥗"
        case .other:
            return "✨"
        }
    }
}

enum RoutineFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

@Model
final class RoutineItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: RoutineCategory
    var scheduledTime: Date
    var duration: Int?
    var frequency: RoutineFrequency
    var days: [Int]
    var isCompleted: Bool
    var notificationIdentifier: String
    var lastCompletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        category: RoutineCategory,
        scheduledTime: Date,
        duration: Int? = nil,
        frequency: RoutineFrequency,
        days: [Int] = [],
        isCompleted: Bool = false,
        notificationIdentifier: String? = nil,
        lastCompletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.scheduledTime = scheduledTime
        self.duration = duration
        self.frequency = frequency
        self.days = days
        self.isCompleted = isCompleted
        self.notificationIdentifier = notificationIdentifier ?? id.uuidString
        self.lastCompletedAt = lastCompletedAt
    }
}
