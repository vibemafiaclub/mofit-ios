import Foundation
import SwiftData

@MainActor
final class CoachingViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = ClaudeAPIService()

    func requestFeedback(
        type: String,
        userProfile: UserProfile,
        workoutSessions: [WorkoutSession],
        modelContext: ModelContext
    ) async -> String? {
        guard !workoutSessions.isEmpty else {
            return "아직 운동 기록이 없어서 피드백을 드리기 어려워요"
        }

        isLoading = true
        errorMessage = nil

        let prompt = buildPrompt(type: type, userProfile: userProfile, sessions: workoutSessions)

        do {
            let response = try await apiService.requestFeedback(prompt: prompt)

            let feedback = CoachingFeedback(
                date: Date(),
                type: type,
                content: response,
                createdAt: Date()
            )
            modelContext.insert(feedback)

            isLoading = false
            return response
        } catch {
            isLoading = false
            switch error {
            case ClaudeAPIError.apiError(let message):
                errorMessage = "API 오류: \(message)"
            case ClaudeAPIError.networkError:
                errorMessage = "네트워크 오류가 발생했습니다"
            default:
                errorMessage = "피드백을 받아오지 못했습니다"
            }
            return nil
        }
    }

    func hasUsedToday(type: String, feedbacks: [CoachingFeedback]) -> Bool {
        feedbacks.contains { feedback in
            feedback.type == type && Calendar.current.isDateInToday(feedback.date)
        }
    }

    func todayUsageCount(feedbacks: [CoachingFeedback]) -> Int {
        feedbacks.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    private func buildPrompt(type: String, userProfile: UserProfile, sessions: [WorkoutSession]) -> String {
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) else {
            return ""
        }

        let recentSessions = sessions.filter { $0.startedAt >= sevenDaysAgo }

        let workoutDays = Set(recentSessions.map { calendar.startOfDay(for: $0.startedAt) }).count
        let totalSessions = recentSessions.count
        let totalReps = recentSessions.reduce(0) { $0 + $1.totalReps }
        let avgRepsPerDay = workoutDays > 0 ? totalReps / workoutDays : 0

        let typeText = type == "pre" ? "운동 전" : "운동 후"
        let genderText = mapGender(userProfile.gender)
        let bodyTypeText = mapBodyType(userProfile.bodyType)
        let goalText = mapGoal(userProfile.goal)

        var dailySummary = ""
        let sortedDays = (0...6).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -6 + offset, to: calendar.startOfDay(for: Date()))
        }

        for day in sortedDays {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)!
            let daySessions = recentSessions.filter { $0.startedAt >= day && $0.startedAt < dayEnd }

            if daySessions.isEmpty {
                continue
            }

            let dayReps = daySessions.reduce(0) { $0 + $1.totalReps }
            let daySets = daySessions.reduce(0) { $0 + $1.totalSets }
            let avgPerSet = daySets > 0 ? dayReps / daySets : 0

            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            let dateStr = formatter.string(from: day)

            dailySummary += "- \(dateStr): \(dayReps)회, \(daySets)세트, 세트당 평균 \(avgPerSet)회\n"
        }

        if dailySummary.isEmpty {
            dailySummary = "- 기록 없음\n"
        }

        return """
        당신은 전문 피트니스 코치입니다. 사용자의 프로필과 최근 운동 기록을 바탕으로 \(typeText) 피드백을 제공해주세요.

        [사용자 프로필]
        - 성별: \(genderText)
        - 키: \(Int(userProfile.height))cm
        - 몸무게: \(Int(userProfile.weight))kg
        - 체형: \(bodyTypeText)
        - 목표: \(goalText)

        [최근 7일 운동 요약]
        - 운동한 날 수: \(workoutDays)/7일
        - 총 세션 수: \(totalSessions)회
        - 총 반복 수: \(totalReps)회
        - 일평균 반복 수: \(avgRepsPerDay)회

        [일별 추이] (최근 7일, 오래된 순)
        \(dailySummary)
        한국어로 응답해주세요. 200자 이내로 간결하게.
        """
    }

    private func mapGender(_ gender: String) -> String {
        switch gender {
        case "male": return "남성"
        case "female": return "여성"
        default: return gender
        }
    }

    private func mapBodyType(_ bodyType: String) -> String {
        switch bodyType {
        case "slim": return "마른 체형"
        case "normal": return "보통 체형"
        case "muscular": return "근육질 체형"
        case "chubby": return "통통한 체형"
        default: return bodyType
        }
    }

    private func mapGoal(_ goal: String) -> String {
        switch goal {
        case "weightLoss": return "체중 감량"
        case "strength": return "근력 증가"
        case "bodyShape": return "체형 개선"
        default: return goal
        }
    }
}
