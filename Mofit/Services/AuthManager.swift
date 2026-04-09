import Foundation

struct AuthUser: Codable {
    let id: String
    let email: String
}

struct AuthResponse: Codable {
    let token: String
    let user: AuthUser
}

struct AuthErrorResponse: Codable {
    let error: String
}

enum AuthError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다"
        case .networkError(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "서버 응답을 처리할 수 없습니다"
        case .serverError(let message):
            return message
        }
    }
}

@MainActor
final class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: AuthUser?

    init() {
        if KeychainService.getToken() != nil {
            isLoggedIn = true
        }
    }

    func signup(email: String, password: String) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/auth/signup")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 201 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            KeychainService.save(token: authResponse.token)
            isLoggedIn = true
            currentUser = authResponse.user
        } else {
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                throw AuthError.serverError(errorResponse.error)
            }
            throw AuthError.invalidResponse
        }
    }

    func login(email: String, password: String) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/auth/login")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            KeychainService.save(token: authResponse.token)
            isLoggedIn = true
            currentUser = authResponse.user
        } else {
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                throw AuthError.serverError(errorResponse.error)
            }
            throw AuthError.invalidResponse
        }
    }

    func logout() {
        KeychainService.deleteToken()
        isLoggedIn = false
        currentUser = nil
    }
}
