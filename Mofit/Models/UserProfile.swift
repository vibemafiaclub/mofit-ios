import SwiftData

@Model
class UserProfile {
    var gender: String
    var height: Double
    var weight: Double
    var bodyType: String
    var goal: String
    var onboardingCompleted: Bool

    init(
        gender: String = "male",
        height: Double = 170.0,
        weight: Double = 70.0,
        bodyType: String = "normal",
        goal: String = "bodyShape",
        onboardingCompleted: Bool = false
    ) {
        self.gender = gender
        self.height = height
        self.weight = weight
        self.bodyType = bodyType
        self.goal = goal
        self.onboardingCompleted = onboardingCompleted
    }
}
