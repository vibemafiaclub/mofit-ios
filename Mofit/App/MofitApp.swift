import SwiftData
import SwiftUI

@main
struct MofitApp: App {
    @StateObject private var authManager = AuthManager()
    let modelContainer: ModelContainer

    init() {
        let container = try! ModelContainer(for: UserProfile.self, WorkoutSession.self, CoachingFeedback.self)
        self.modelContainer = container
        AnalyticsService.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .onAppear {
                    setupAuthCallbacks()
                }
        }
        .modelContainer(modelContainer)
    }

    private func setupAuthCallbacks() {
        let context = modelContainer.mainContext
        authManager.onAuthStateChanged = {
            clearLocalData(context: context)
        }
    }

    @MainActor
    private func clearLocalData(context: ModelContext) {
        do {
            try context.delete(model: WorkoutSession.self)
            try context.delete(model: CoachingFeedback.self)
        } catch {
            // 로컬 데이터 삭제 실패 시 무시
        }
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
