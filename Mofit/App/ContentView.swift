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

            Text("AI Coaching Tab")
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.darkBackground)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI코칭")
                }
        }
        .tint(Theme.neonGreen)
    }
}
