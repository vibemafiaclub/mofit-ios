import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("홈")
                }

            RecordsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("기록")
                }

            CoachingView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI코칭")
                }
        }
        .tint(Theme.neonGreen)
    }
}
