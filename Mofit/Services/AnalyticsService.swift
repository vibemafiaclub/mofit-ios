import Foundation
import Mixpanel

enum AnalyticsEvent: String {
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case signUp = "sign_up"
    case login = "login"
    case workoutStarted = "workout_started"
    case workoutCompleted = "workout_completed"
    case workoutCancelled = "workout_cancelled"
    case coachingRequested = "coaching_requested"
    case coachingReceived = "coaching_received"
    case screenViewed = "screen_viewed"
}

final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    func initialize() {
        Mixpanel.initialize(token: Secrets.mixpanelToken, trackAutomaticEvents: true)
    }

    func track(_ event: AnalyticsEvent, properties: Properties? = nil) {
        Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)
    }

    func identify(userId: String) {
        Mixpanel.mainInstance().identify(distinctId: userId)
    }

    func reset() {
        Mixpanel.mainInstance().reset()
    }
}
