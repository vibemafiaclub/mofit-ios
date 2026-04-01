import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExerciseName: String

    private let exercises: [(name: String, icon: String)] = [
        ("스쿼트", "figure.strengthtraining.traditional"),
        ("푸쉬업", "figure.strengthtraining.functional"),
        ("런지", "figure.walk"),
        ("플랭크", "figure.core.training")
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Theme.darkBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("운동 선택")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.top, 24)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(exercises, id: \.name) { exercise in
                        exerciseCard(name: exercise.name, icon: exercise.icon)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func exerciseCard(name: String, icon: String) -> some View {
        Button {
            selectedExerciseName = name
            dismiss()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(selectedExerciseName == name ? Theme.neonGreen : Theme.textPrimary)

                Text(name)
                    .font(.headline)
                    .foregroundColor(selectedExerciseName == name ? Theme.neonGreen : Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedExerciseName == name ? Theme.neonGreen : Color.clear, lineWidth: 2)
            )
        }
    }
}
