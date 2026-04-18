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
    var duration: Int?
    var isCompleted: Bool
    var order: Int
    var lastCompletedAt: Date?
    var timerEndDate: Date?
    var group: RoutineGroup?

    init(
        id: UUID = UUID(),
        title: String,
        category: RoutineCategory,
        duration: Int? = nil,
        isCompleted: Bool = false,
        order: Int = 0,
        lastCompletedAt: Date? = nil,
        timerEndDate: Date? = nil,
        group: RoutineGroup? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.duration = duration
        self.isCompleted = isCompleted
        self.order = order
        self.lastCompletedAt = lastCompletedAt
        self.timerEndDate = timerEndDate
        self.group = group
    }
}
