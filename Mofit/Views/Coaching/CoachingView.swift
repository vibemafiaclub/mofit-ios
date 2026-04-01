import SwiftData
import SwiftUI

struct CoachingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CoachingFeedback.createdAt, order: .reverse) private var feedbacks: [CoachingFeedback]
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [WorkoutSession]

    @StateObject private var viewModel = CoachingViewModel()
    @State private var expandedFeedbackId: UUID?

    private var profile: UserProfile? {
        profiles.first
    }

    private var todayUsageCount: Int {
        viewModel.todayUsageCount(feedbacks: feedbacks)
    }

    private var hasUsedPre: Bool {
        viewModel.hasUsedToday(type: "pre", feedbacks: feedbacks)
    }

    private var hasUsedPost: Bool {
        viewModel.hasUsedToday(type: "post", feedbacks: feedbacks)
    }

    var body: some View {
        ZStack {
            Theme.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal)
                    .padding(.top, 16)

                buttonSection
                    .padding(.horizontal)
                    .padding(.top, 24)

                feedbackList
                    .padding(.top, 24)
            }
        }
        .onAppear {
            if let firstFeedback = feedbacks.first {
                expandedFeedbackId = firstFeedback.id
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI 코칭")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            Text("오늘 \(todayUsageCount)회 / 2회 사용")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttonSection: some View {
        VStack(spacing: 12) {
            feedbackButton(type: "pre", title: "운동 전 피드백", isUsed: hasUsedPre)
            feedbackButton(type: "post", title: "운동 후 피드백", isUsed: hasUsedPost)
        }
    }

    private func feedbackButton(type: String, title: String, isUsed: Bool) -> some View {
        Button {
            Task {
                await requestFeedback(type: type)
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Theme.darkBackground)
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(isUsed ? Theme.textSecondary : Theme.darkBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isUsed ? Theme.cardBackground : Theme.neonGreen)
            .cornerRadius(16)
        }
        .disabled(isUsed || viewModel.isLoading)
    }

    private func requestFeedback(type: String) async {
        guard let profile = profile else { return }

        let _ = await viewModel.requestFeedback(
            type: type,
            userProfile: profile,
            workoutSessions: Array(sessions),
            modelContext: modelContext
        )

        if let firstFeedback = feedbacks.first {
            expandedFeedbackId = firstFeedback.id
        }
    }

    private var feedbackList: some View {
        Group {
            if feedbacks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let errorMessage = viewModel.errorMessage {
                            errorCard(message: errorMessage)
                        }

                        ForEach(feedbacks, id: \.id) { feedback in
                            feedbackCard(for: feedback)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("아직 피드백 기록이 없어요")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()
        }
    }

    private func errorCard(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    private func feedbackCard(for feedback: CoachingFeedback) -> some View {
        let isExpanded = expandedFeedbackId == feedback.id

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedFeedbackId = nil
                } else {
                    expandedFeedbackId = feedback.id
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(formatDate(feedback.date))
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    typeBadge(for: feedback.type)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                if isExpanded {
                    Text(feedback.content)
                        .font(.body)
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private func typeBadge(for type: String) -> some View {
        let text = type == "pre" ? "운동 전" : "운동 후"

        return Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(Theme.neonGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.neonGreen.opacity(0.2))
            .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}
