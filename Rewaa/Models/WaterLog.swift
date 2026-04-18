import Foundation
import SwiftData

@Model
final class WaterLog {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var amount: Int

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        amount: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.amount = amount
    }
}
