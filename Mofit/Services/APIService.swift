import Foundation

// MARK: - Server Response Models

struct ServerProfile: Codable {
    let gender: String
    let height: Double
    let weight: Double
    let bodyType: String
    let goal: String
    let coachStyle: String
}

struct ServerSession: Codable {
    let id: String?
    let exerciseType: String
    let startedAt: String
    let endedAt: String
    let totalDuration: Int
    let repCounts: [Int]
}

struct ServerFeedback: Codable {
    let id: String?
    let date: String
    let type: String
    let content: String
    let createdAt: String?
}

// MARK: - API Response Wrappers

private struct ProfileResponse: Codable {
    let profile: ServerProfile
}

private struct SessionsResponse: Codable {
    let sessions: [ServerSession]
}

private struct SessionResponse: Codable {
    let session: ServerSession
}

private struct FeedbacksResponse: Codable {
    let feedbacks: [ServerFeedback]
}

private struct FeedbackResponse: Codable {
    let feedback: ServerFeedback
}

private struct ErrorResponse: Codable {
    let error: String
}

// MARK: - API Error

enum APIError: LocalizedError {
    case unauthorized
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case noToken

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .networkError(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "서버 응답을 처리할 수 없습니다"
        case .serverError(let message):
            return message
        case .noToken:
            return "로그인이 필요합니다"
        }
    }
}

// MARK: - APIService

class APIService {
    static let shared = APIService()

    private init() {}

    private var authManager: AuthManager?

    func setAuthManager(_ manager: AuthManager) {
        self.authManager = manager
    }

    // MARK: - Profile

    func getProfile() async throws -> ServerProfile {
        let data = try await request(path: "/profile", method: "GET")
        let response = try JSONDecoder().decode(ProfileResponse.self, from: data)
        return response.profile
    }

    func updateProfile(_ profile: ServerProfile) async throws -> ServerProfile {
        let body = try JSONEncoder().encode(profile)
        let data = try await request(path: "/profile", method: "PUT", body: body)
        let response = try JSONDecoder().decode(ProfileResponse.self, from: data)
        return response.profile
    }

    // MARK: - Sessions

    func getSessions(date: Date?) async throws -> [ServerSession] {
        var path = "/sessions"
        if let date = date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let dateString = formatter.string(from: date)
            path += "?date=\(dateString)"
        }
        let data = try await request(path: path, method: "GET")
        let response = try JSONDecoder().decode(SessionsResponse.self, from: data)
        return response.sessions
    }

    func createSession(_ session: ServerSession) async throws -> ServerSession {
        let body = try JSONEncoder().encode(session)
        let data = try await request(path: "/sessions", method: "POST", body: body)
        let response = try JSONDecoder().decode(SessionResponse.self, from: data)
        return response.session
    }

    func deleteSession(id: String) async throws {
        _ = try await request(path: "/sessions/\(id)", method: "DELETE")
    }

    // MARK: - Coaching

    func getFeedbacks(date: Date?) async throws -> [ServerFeedback] {
        var path = "/coaching"
        if let date = date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let dateString = formatter.string(from: date)
            path += "?date=\(dateString)"
        }
        let data = try await request(path: path, method: "GET")
        let response = try JSONDecoder().decode(FeedbacksResponse.self, from: data)
        return response.feedbacks
    }

    func requestCoaching(prompt: String, type: String) async throws -> ServerFeedback {
        let requestBody = ["prompt": prompt, "type": type]
        let body = try JSONEncoder().encode(requestBody)
        let data = try await request(path: "/coaching/request", method: "POST", body: body)
        let response = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        return response.feedback
    }

    // MARK: - Private Helpers

    private func request(path: String, method: String, body: Data? = nil) async throws -> Data {
        guard let token = KeychainService.getToken() else {
            throw APIError.noToken
        }

        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            await handleUnauthorized()
            throw APIError.unauthorized
        }

        if httpResponse.statusCode == 204 {
            return Data()
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }

        return data
    }

    @MainActor
    private func handleUnauthorized() {
        authManager?.logout()
    }
}
