import SwiftData

@Model
class UserProfile {
    var gender: String
    var height: Double
    var weight: Double
    var bodyType: String
    var goal: String
    var coachStyle: String

    init(
        gender: String = "male",
        height: Double = 170.0,
        weight: Double = 70.0,
        bodyType: String = "normal",
        goal: String = "bodyShape",
        coachStyle: String = "warm"
    ) {
        self.gender = gender
        self.height = height
        self.weight = weight
        self.bodyType = bodyType
        self.goal = goal
        self.coachStyle = coachStyle
    }
}
