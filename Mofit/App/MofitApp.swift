import SwiftData
import SwiftUI

// 최소한의 앱 진입점. Phase 2에서 온보딩 분기 + TabView로 교체 예정.
@main
struct MofitApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Mofit")
        }
        .modelContainer(for: [UserProfile.self, WorkoutSession.self, CoachingFeedback.self])
    }
}
