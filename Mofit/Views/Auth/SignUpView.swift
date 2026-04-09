import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false

    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }

    private var isPasswordValid: Bool {
        password.count >= 6
    }

    private var isConfirmPasswordValid: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    private var canSignUp: Bool {
        isEmailValid && isPasswordValid && isConfirmPasswordValid
    }

    var body: some View {
        ZStack {
            Theme.darkBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("회원가입")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("이메일", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)

                        if !email.isEmpty && !isEmailValid {
                            Text("올바른 이메일 형식이 아닙니다")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("비밀번호", text: $password)
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)

                        if !password.isEmpty && !isPasswordValid {
                            Text("비밀번호는 6자 이상이어야 합니다")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("비밀번호 확인", text: $confirmPassword)
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)

                        if !confirmPassword.isEmpty && !isConfirmPasswordValid {
                            Text("비밀번호가 일치하지 않습니다")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
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
                        await signUp()
                    }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(Theme.darkBackground)
                        } else {
                            Text("가입하기")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(Theme.darkBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canSignUp && !isLoading ? Theme.neonGreen : Theme.textSecondary)
                    .cornerRadius(16)
                }
                .disabled(!canSignUp || isLoading)
                .padding(.horizontal)

                Spacer()

                HStack(spacing: 4) {
                    Text("이미 계정이 있으신가요?")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    Button {
                        dismiss()
                    } label: {
                        Text("로그인")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.neonGreen)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn && !showSuccessMessage {
                dismiss()
            }
        }
        .alert("가입 완료", isPresented: $showSuccessMessage) {
            Button("확인") {
                dismiss()
            }
        } message: {
            Text("회원가입이 완료되었습니다!")
        }
    }

    private func signUp() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signup(email: email, password: password)
            showSuccessMessage = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
