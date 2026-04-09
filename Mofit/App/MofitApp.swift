import SwiftData
import SwiftUI

@main
struct MofitApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
        .modelContainer(for: [UserProfile.self, WorkoutSession.self, CoachingFeedback.self])
    }
}

struct RootView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    var body: some View {
        if onboardingCompleted {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}
