import SwiftData
import SwiftUI

struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @Query private var sessions: [WorkoutSession]

    @State private var selectedDate = Date()
    @State private var displayedDates: [Date] = []
    @State private var serverSessions: [ServerSession] = []
    @State private var isLoadingServerData = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    private var filteredSessions: [WorkoutSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDate) }
    }

    private var filteredServerSessions: [ServerSession] {
        let calendar = Calendar.current
        return serverSessions.filter { session in
            if let date = parseISO8601Date(session.startedAt) {
                return calendar.isDate(date, inSameDayAs: selectedDate)
            }
            return false
        }
    }

    private var hasFilteredSessions: Bool {
        if authManager.isLoggedIn {
            return !filteredServerSessions.isEmpty
        }
        return !filteredSessions.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                datePickerBar
                    .padding(.top, 16)

                sessionList
            }
        }
        .onAppear {
            initializeDates()
            AnalyticsService.shared.track(.screenViewed, properties: ["screen_name": "records"])
        }
        .task {
            await loadServerData()
        }
        .refreshable {
            await loadServerData()
        }
        .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                Task { await loadServerData() }
            } else {
                serverSessions = []
            }
        }
        .alert("삭제 실패", isPresented: $showDeleteError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    private func loadServerData() async {
        guard authManager.isLoggedIn else { return }
        isLoadingServerData = true
        do {
            serverSessions = try await APIService.shared.getSessions(date: nil)
        } catch {
            serverSessions = []
        }
        isLoadingServerData = false
    }

    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    private var datePickerBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(displayedDates, id: \.self) { date in
                        dateItem(for: date)
                            .id(date)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(selectedDate, anchor: .center)
                }
            }
        }
    }

    private func dateItem(for date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        let dayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "E"
            return formatter
        }()

        let dayOfMonth = calendar.component(.day, from: date)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text(dayFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(isSelected ? Theme.darkBackground : Theme.textSecondary)

                Text("\(dayOfMonth)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? Theme.darkBackground : Theme.textPrimary)
            }
            .frame(width: 44, height: 60)
            .background(
                Circle()
                    .fill(isSelected ? Theme.neonGreen : Color.clear)
                    .frame(width: 44, height: 44)
                    .offset(y: 6)
            )
        }
    }

    private var sessionList: some View {
        Group {
            if !hasFilteredSessions {
                emptyState
            } else if authManager.isLoggedIn {
                serverSessionList
            } else {
                localSessionList
            }
        }
    }

    private var localSessionList: some View {
        List {
            ForEach(filteredSessions, id: \.id) { session in
                sessionCard(for: session)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var serverSessionList: some View {
        List {
            ForEach(filteredServerSessions, id: \.id) { session in
                serverSessionCard(for: session)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteServerSessions)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("이 날은 운동 기록이 없어요")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
    }

    private func sessionCard(for session: WorkoutSession) -> some View {
        HStack(spacing: 16) {
            Image(systemName: exerciseIcon(for: session.exerciseType))
                .font(.title2)
                .foregroundColor(Theme.neonGreen)
                .frame(width: 44, height: 44)
                .background(Theme.darkBackground)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(exerciseName(for: session.exerciseType))
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Text("\(session.totalSets)세트 · \(session.totalReps)회 · \(formatDuration(session.totalDuration))")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text(formatTime(session.startedAt))
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }

    private func initializeDates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        displayedDates = (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.reversed()
        selectedDate = today
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = filteredSessions[index]
            modelContext.delete(session)
        }
    }

    private func deleteServerSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = filteredServerSessions[index]
            guard let sessionId = session.id else { continue }
            Task {
                do {
                    try await APIService.shared.deleteSession(id: sessionId)
                    serverSessions.removeAll { $0.id == sessionId }
                } catch {
                    deleteErrorMessage = error.localizedDescription
                    showDeleteError = true
                }
            }
        }
    }

    private func serverSessionCard(for session: ServerSession) -> some View {
        let startedAt = parseISO8601Date(session.startedAt) ?? Date()
        let totalSets = session.repCounts.count
        let totalReps = session.repCounts.reduce(0, +)

        return HStack(spacing: 16) {
            Image(systemName: exerciseIcon(for: session.exerciseType))
                .font(.title2)
                .foregroundColor(Theme.neonGreen)
                .frame(width: 44, height: 44)
                .background(Theme.darkBackground)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(exerciseName(for: session.exerciseType))
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Text("\(totalSets)세트 · \(totalReps)회 · \(formatDuration(session.totalDuration))")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text(formatTime(startedAt))
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }

    private func exerciseIcon(for type: String) -> String {
        switch type {
        case "squat": return "figure.strengthtraining.traditional"
        case "pushup": return "figure.strengthtraining.functional"
        case "situp": return "figure.core.training"
        default: return "figure.strengthtraining.traditional"
        }
    }

    private func exerciseName(for type: String) -> String {
        switch type {
        case "squat": return "스쿼트"
        case "pushup": return "푸쉬업"
        case "situp": return "싯업"
        default: return "스쿼트"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
