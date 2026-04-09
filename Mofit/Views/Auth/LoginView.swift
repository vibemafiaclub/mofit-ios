import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignUp = false

    private var canLogin: Bool {
        !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Text("로그인")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    VStack(spacing: 16) {
                        TextField("이메일", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)

                        SecureField("비밀번호", text: $password)
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            await login()
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(Theme.darkBackground)
                            } else {
                                Text("로그인")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(Theme.darkBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canLogin && !isLoading ? Theme.neonGreen : Theme.textSecondary)
                        .cornerRadius(16)
                    }
                    .disabled(!canLogin || isLoading)
                    .padding(.horizontal)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("아직 계정이 없으신가요?")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        Button {
                            showSignUp = true
                        } label: {
                            Text("회원가입")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.neonGreen)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
        .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                dismiss()
            }
        }
        .onAppear {
            AnalyticsService.shared.track(.screenViewed, properties: ["screen_name": "login"])
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authManager.login(email: email, password: password)
            AnalyticsService.shared.track(.login)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
