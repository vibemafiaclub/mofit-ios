import SwiftData
import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

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

    private var canSave: Bool {
        heightValidation != .invalid && weightValidation != .invalid
    }

    var body: some View {
        ZStack {
            Theme.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 32) {
                        genderSection
                        heightSection
                        weightSection
                        bodyTypeSection
                        goalSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }

                saveButton
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            loadProfile()
        }
        .alert("정말 \(heightText)cm가 맞나요?", isPresented: $showHeightWarning) {
            Button("취소", role: .cancel) {}
            Button("확인") {
                saveProfile()
            }
        }
        .alert("정말 \(weightText)kg이 맞나요?", isPresented: $showWeightWarning) {
            Button("취소", role: .cancel) {}
            Button("확인") {
                saveProfile()
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("프로필 수정")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("성별")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 16) {
                genderButton(title: "남성", value: "male")
                genderButton(title: "여성", value: "female")
            }
        }
    }

    private func genderButton(title: String, value: String) -> some View {
        Button {
            gender = value
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(gender == value ? Theme.darkBackground : Theme.neonGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(gender == value ? Theme.neonGreen : Color.clear)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.neonGreen, lineWidth: 2)
                )
        }
    }

    private var heightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("키")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)

            HStack {
                TextField("", text: $heightText)
                    .keyboardType(.numberPad)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)

                Text("cm")
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
            }

            if heightValidation == .invalid && !heightText.isEmpty {
                Text("올바른 키를 입력해주세요")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("몸무게")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)

            HStack {
                TextField("", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)

                Text("kg")
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
            }

            if weightValidation == .invalid && !weightText.isEmpty {
                Text("올바른 몸무게를 입력해주세요")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    private var bodyTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("체형")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 8) {
                bodyTypeButton(title: "마른 체형", value: "slim")
                bodyTypeButton(title: "보통 체형", value: "normal")
                bodyTypeButton(title: "근육질 체형", value: "muscular")
                bodyTypeButton(title: "통통한 체형", value: "chubby")
            }
        }
    }

    private func bodyTypeButton(title: String, value: String) -> some View {
        Button {
            bodyType = value
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(bodyType == value ? Theme.darkBackground : Theme.neonGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(bodyType == value ? Theme.neonGreen : Color.clear)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.neonGreen, lineWidth: 1.5)
                )
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("목표")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 8) {
                goalButton(title: "체중 감량", value: "weightLoss")
                goalButton(title: "근력 증가", value: "strength")
                goalButton(title: "체형 개선", value: "bodyShape")
            }
        }
    }

    private func goalButton(title: String, value: String) -> some View {
        Button {
            goal = value
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(goal == value ? Theme.darkBackground : Theme.neonGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(goal == value ? Theme.neonGreen : Color.clear)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.neonGreen, lineWidth: 1.5)
                )
        }
    }

    private var saveButton: some View {
        Button {
            if heightValidation == .warning {
                showHeightWarning = true
            } else if weightValidation == .warning {
                showWeightWarning = true
            } else {
                saveProfile()
            }
        } label: {
            Text("저장")
                .font(.headline)
                .foregroundColor(Theme.darkBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canSave ? Theme.neonGreen : Theme.textSecondary)
                .cornerRadius(12)
        }
        .disabled(!canSave)
    }

    private func loadProfile() {
        guard let profile = profiles.first else { return }
        gender = profile.gender
        heightText = String(Int(profile.height))
        weightText = String(format: "%.1f", profile.weight)
        bodyType = profile.bodyType
        goal = profile.goal
    }

    private func saveProfile() {
        guard let profile = profiles.first else { return }
        let h = height ?? profile.height
        let w = weight ?? profile.weight

        profile.gender = gender
        profile.height = h
        profile.weight = w
        profile.bodyType = bodyType
        profile.goal = goal

        dismiss()
    }
}

private enum ValidationState {
    case valid
    case warning
    case invalid
}
