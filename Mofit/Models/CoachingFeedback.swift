import Foundation
import SwiftData

@Model
class CoachingFeedback {
    var id: UUID
    var date: Date
    var type: String
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: String = "pre",
        content: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.content = content
        self.createdAt = createdAt
    }
}
