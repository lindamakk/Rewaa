import Foundation
import SwiftData

@Model
final class RoutineGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var scheduledTime: Date
    var frequency: RoutineFrequency
    var days: [Int]
    var notificationIdentifier: String
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.group) var items: [RoutineItem]

    init(
        id: UUID = UUID(),
        name: String,
        scheduledTime: Date,
        frequency: RoutineFrequency,
        days: [Int] = [],
        notificationIdentifier: String? = nil,
        items: [RoutineItem] = []
    ) {
        self.id = id
        self.name = name
        self.scheduledTime = scheduledTime
        self.frequency = frequency
        self.days = days
        self.notificationIdentifier = notificationIdentifier ?? id.uuidString
        self.items = items
    }
}
