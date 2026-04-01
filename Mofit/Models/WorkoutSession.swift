import Foundation
import SwiftData

@Model
class WorkoutSession {
    var id: UUID
    var exerciseType: String
    var startedAt: Date
    var endedAt: Date
    var totalDuration: Int
    var repCounts: [Int]

    var totalSets: Int {
        repCounts.count
    }

    var totalReps: Int {
        repCounts.reduce(0, +)
    }

    init(
        id: UUID = UUID(),
        exerciseType: String = "squat",
        startedAt: Date = Date(),
        endedAt: Date = Date(),
        totalDuration: Int = 0,
        repCounts: [Int] = []
    ) {
        self.id = id
        self.exerciseType = exerciseType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalDuration = totalDuration
        self.repCounts = repCounts
    }
}
