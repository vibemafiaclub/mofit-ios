import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    @State private var currentStep = OnboardingStep.gender
    @State private var gender = "male"
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var bodyType = "normal"
    @State private var goal = "bodyShape"
    @State private var coachStyle = "warm"

    @State private var showHeightWarning = false
    @State private var showWeightWarning = false
    @FocusState private var heightFocused: Bool
    @FocusState private var weightFocused: Bool

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
                if currentStep != .gender {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if let prev = currentStep.previous { currentStep = prev }
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
                    case .gender:
                        genderSelectionView
                    case .height:
                        heightInputView
                    case .weight:
                        weightInputView
                    case .bodyType:
                        bodyTypeSelectionView
                    case .goal:
                        goalSelectionView
                    case .coachStyle:
                        coachStyleSelectionView
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .gesture(
                    DragGesture(minimumDistance: 50, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width > 50, let prev = currentStep.previous {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep = prev
                                }
                            }
                        }
                )

                Spacer()
            }
        }
        .onChange(of: currentStep) { _, newStep in
            heightFocused = false
            weightFocused = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if newStep == .height { heightFocused = true }
                if newStep == .weight { weightFocused = true }
            }
        }
        .alert("정말 \(heightText)cm가 맞나요?", isPresented: $showHeightWarning) {
            Button("취소", role: .cancel) {}
            Button("확인") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = .weight
                }
            }
        }
        .alert("정말 \(weightText)kg이 맞나요?", isPresented: $showWeightWarning) {
            Button("취소", role: .cancel) {}
            Button("확인") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = .bodyType
                }
            }
        }
        .onAppear {
            AnalyticsService.shared.track(.onboardingStarted)
            AnalyticsService.shared.track(.screenViewed, properties: ["screen_name": "onboarding"])
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
                if let next = currentStep.next { currentStep = next }
            }
        } label: {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.neonGreen)
                .frame(width: 120, height: 120)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.neonGreen, lineWidth: 2)
                )
        }
    }

    private var heightInputView: some View {
        VStack(spacing: 32) {
            Text("키를 입력해주세요")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            HStack {
                TextField("170", text: $heightText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 150)
                    .focused($heightFocused)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(Theme.neonGreen.opacity(0.5)),
                        alignment: .bottom
                    )

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
                        if let next = currentStep.next { currentStep = next }
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
                TextField("70", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 150)
                    .focused($weightFocused)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(Theme.neonGreen.opacity(0.5)),
                        alignment: .bottom
                    )

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
                        if let next = currentStep.next { currentStep = next }
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
                if let next = currentStep.next { currentStep = next }
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
            withAnimation(.easeInOut(duration: 0.3)) {
                if let next = currentStep.next { currentStep = next }
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

    private var coachStyleSelectionView: some View {
        VStack(spacing: 32) {
            Text("어떤 코치를 원하세요?")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: 16) {
                coachStyleButton(title: "빡센 코치", subtitle: "직설적이고 거친 동기부여", value: "tough")
                coachStyleButton(title: "따뜻한 코치", subtitle: "친절하고 격려 위주", value: "warm")
                coachStyleButton(title: "분석형 코치", subtitle: "데이터 중심, 냉철한 조언", value: "analytical")
            }
        }
        .padding()
    }

    private func coachStyleButton(title: String, subtitle: String, value: String) -> some View {
        Button {
            coachStyle = value
            completeOnboarding()
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.neonGreen)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
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
            existingProfile.coachStyle = coachStyle
        } else {
            let newProfile = UserProfile(
                gender: gender,
                height: h,
                weight: w,
                bodyType: bodyType,
                goal: goal,
                coachStyle: coachStyle
            )
            modelContext.insert(newProfile)
        }

        AnalyticsService.shared.track(.onboardingCompleted)
        onboardingCompleted = true
    }
}

private enum ValidationState {
    case valid
    case warning
    case invalid
}

private enum OnboardingStep: Int, CaseIterable {
    case gender = 0
    case height = 1
    case weight = 2
    case bodyType = 3
    case goal = 4
    case coachStyle = 5

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}
