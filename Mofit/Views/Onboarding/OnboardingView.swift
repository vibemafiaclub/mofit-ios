import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var currentStep = 0
    @State private var gender = "male"
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var bodyType = "normal"
    @State private var goal = "bodyShape"

    @State private var showHeightWarning = false
    @State private var showWeightWarning = false

    private var height: Double? {
        Double(heightText)
    }

    private var weight: Double? {
        Double(weightText)
    }

    private var heightValidation: ValidationState {
        guard let h = height else { return .invalid }
        if h < 100 || h > 250 { return .invalid }
        if (h >= 100 && h <= 140) || (h >= 200 && h <= 250) { return .warning }
        return .valid
    }

    private var weightValidation: ValidationState {
        guard let w = weight else { return .invalid }
        if w < 20 || w > 300 { return .invalid }
        if (w >= 20 && w <= 35) || (w >= 150 && w <= 300) { return .warning }
        return .valid
    }

    var body: some View {
        ZStack {
            Theme.darkBackground.ignoresSafeArea()

            VStack {
                if currentStep > 0 {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Group {
                    switch currentStep {
                    case 0:
                        genderSelectionView
                    case 1:
                        heightInputView
                    case 2:
                        weightInputView
                    case 3:
                        bodyTypeSelectionView
                    case 4:
                        goalSelectionView
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

                Spacer()
            }
        }
        .alert("정말 \(heightText)cm가 맞나요?", isPresented: $showHeightWarning) {
            Button("취소", role: .cancel) {}
            Button("확인") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = 2
                }
            }
        }
        .alert("정말 \(weightText)kg이 맞나요?", isPresented: $showWeightWarning) {
            Button("취소", role: .cancel) {}
            Button("확인") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = 3
                }
            }
        }
    }

    private var genderSelectionView: some View {
        VStack(spacing: 32) {
            Text("성별을 선택해주세요")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 20) {
                genderButton(title: "남성", value: "male")
                genderButton(title: "여성", value: "female")
            }
        }
        .padding()
    }

    private func genderButton(title: String, value: String) -> some View {
        Button {
            gender = value
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = 1
            }
        } label: {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.darkBackground)
                .frame(width: 120, height: 120)
                .background(Theme.neonGreen)
                .cornerRadius(16)
        }
    }

    private var heightInputView: some View {
        VStack(spacing: 32) {
            Text("키를 입력해주세요")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            HStack {
                TextField("", text: $heightText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 150)

                Text("cm")
                    .font(.title)
                    .foregroundColor(Theme.textSecondary)
            }

            if heightValidation == .invalid && !heightText.isEmpty {
                Text("올바른 키를 입력해주세요")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }

            Button {
                if heightValidation == .warning {
                    showHeightWarning = true
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 2
                    }
                }
            } label: {
                Text("다음")
                    .font(.headline)
                    .foregroundColor(Theme.darkBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(heightValidation != .invalid ? Theme.neonGreen : Theme.textSecondary)
                    .cornerRadius(12)
            }
            .disabled(heightValidation == .invalid)
            .padding(.horizontal, 40)
        }
        .padding()
    }

    private var weightInputView: some View {
        VStack(spacing: 32) {
            Text("몸무게를 입력해주세요")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            HStack {
                TextField("", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 150)

                Text("kg")
                    .font(.title)
                    .foregroundColor(Theme.textSecondary)
            }

            if weightValidation == .invalid && !weightText.isEmpty {
                Text("올바른 몸무게를 입력해주세요")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }

            Button {
                if weightValidation == .warning {
                    showWeightWarning = true
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 3
                    }
                }
            } label: {
                Text("다음")
                    .font(.headline)
                    .foregroundColor(Theme.darkBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(weightValidation != .invalid ? Theme.neonGreen : Theme.textSecondary)
                    .cornerRadius(12)
            }
            .disabled(weightValidation == .invalid)
            .padding(.horizontal, 40)
        }
        .padding()
    }

    private var bodyTypeSelectionView: some View {
        VStack(spacing: 32) {
            Text("체형을 선택해주세요")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: 16) {
                bodyTypeButton(title: "마른 체형", value: "slim")
                bodyTypeButton(title: "보통 체형", value: "normal")
                bodyTypeButton(title: "근육질 체형", value: "muscular")
                bodyTypeButton(title: "통통한 체형", value: "chubby")
            }
        }
        .padding()
    }

    private func bodyTypeButton(title: String, value: String) -> some View {
        Button {
            bodyType = value
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = 4
            }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.neonGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.neonGreen, lineWidth: 2)
                )
        }
        .padding(.horizontal, 40)
    }

    private var goalSelectionView: some View {
        VStack(spacing: 32) {
            Text("목표를 선택해주세요")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: 16) {
                goalButton(title: "체중 감량", value: "weightLoss")
                goalButton(title: "근력 증가", value: "strength")
                goalButton(title: "체형 개선", value: "bodyShape")
            }
        }
        .padding()
    }

    private func goalButton(title: String, value: String) -> some View {
        Button {
            goal = value
            completeOnboarding()
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.neonGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.neonGreen, lineWidth: 2)
                )
        }
        .padding(.horizontal, 40)
    }

    private func completeOnboarding() {
        let h = height ?? 170.0
        let w = weight ?? 70.0

        if let existingProfile = profiles.first {
            existingProfile.gender = gender
            existingProfile.height = h
            existingProfile.weight = w
            existingProfile.bodyType = bodyType
            existingProfile.goal = goal
            existingProfile.onboardingCompleted = true
        } else {
            let newProfile = UserProfile(
                gender: gender,
                height: h,
                weight: w,
                bodyType: bodyType,
                goal: goal,
                onboardingCompleted: true
            )
            modelContext.insert(newProfile)
        }
    }
}

private enum ValidationState {
    case valid
    case warning
    case invalid
}
