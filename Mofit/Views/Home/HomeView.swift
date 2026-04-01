import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [WorkoutSession]

    @State private var selectedExerciseName = "스쿼트"
    @State private var showExercisePicker = false
    @State private var showProfileEdit = false
    @State private var showTracking = false
    @State private var showConfetti = false

    private var todaySessions: [WorkoutSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: startOfDay) }
    }

    private var todayTotalSets: Int {
        todaySessions.reduce(0) { $0 + $1.totalSets }
    }

    private var todayTotalReps: Int {
        todaySessions.reduce(0) { $0 + $1.totalReps }
    }

    private var todayTotalDuration: Int {
        todaySessions.reduce(0) { $0 + $1.totalDuration }
    }

    var body: some View {
        ZStack {
            Theme.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        exerciseSelector
                            .padding(.top, 32)

                        startButton
                            .padding(.horizontal)

                        todaySummaryCard
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
            }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            showConfetti = false
                        }
                    }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView(selectedExerciseName: $selectedExerciseName)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showProfileEdit) {
            ProfileEditView()
        }
        .fullScreenCover(isPresented: $showTracking) {
            TrackingView(showConfetti: $showConfetti)
        }
    }

    private var topBar: some View {
        HStack {
            Text("모핏")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Button {
                showProfileEdit = true
            } label: {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }

    private var exerciseSelector: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack {
                Text(selectedExerciseName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Image(systemName: "chevron.down")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
    }

    private var startButton: some View {
        Button {
            showTracking = true
        } label: {
            Text("운동 시작")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.darkBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Theme.neonGreen)
                .cornerRadius(16)
        }
    }

    private var todaySummaryCard: some View {
        VStack(spacing: 16) {
            Text("오늘의 기록")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if todaySessions.isEmpty {
                Text("첫 운동을 시작해보세요!")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                HStack(spacing: 0) {
                    summaryItem(value: "\(todayTotalSets)", label: "세트")
                    Spacer()
                    summaryItem(value: "\(todayTotalReps)", label: "rep")
                    Spacer()
                    summaryItem(value: formatDuration(todayTotalDuration), label: "시간")
                }
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let rect = CGRect(
                    x: particle.x * size.width - 10,
                    y: particle.y * size.height - 10,
                    width: 20,
                    height: 20
                )
                context.draw(Text(particle.emoji).font(.title), at: CGPoint(x: rect.midX, y: rect.midY))
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }

    private func createParticles() {
        let emojis = ["🎉", "🎊", "✨", "⭐️", "💚"]
        particles = (0..<30).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0.1...0.9),
                y: -0.1,
                emoji: emojis.randomElement()!
            )
        }
    }

    private func animateParticles() {
        withAnimation(.easeOut(duration: 2.5)) {
            particles = particles.map { particle in
                var p = particle
                p.y = CGFloat.random(in: 1.2...1.5)
                p.x += CGFloat.random(in: -0.2...0.2)
                return p
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var emoji: String
}