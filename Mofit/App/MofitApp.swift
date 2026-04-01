import SwiftData
import SwiftUI

@main
struct MofitApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [UserProfile.self, WorkoutSession.self, CoachingFeedback.self])
    }
}

struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first, profile.onboardingCompleted {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}
