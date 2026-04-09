import Foundation
import Vision

final class SquatCounter: ObservableObject, ExerciseCounter {
    @Published var currentReps: Int = 0

    private enum SquatState {
        case standing
        case squatting
    }

    private var state: SquatState = .standing

    // Optimized via scripts/optimize.py — knee angle (Hip→Knee→Ankle)
    private let standingThreshold: Double = 160
    private let squattingThreshold: Double = 100

    func processJoints(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        guard let angle = calculateKneeAngle(from: joints) else { return }

        switch state {
        case .standing:
            if angle < squattingThreshold {
                state = .squatting
            }
        case .squatting:
            if angle > standingThreshold {
                state = .standing
                currentReps += 1
            }
        }
    }

    func reset() {
        currentReps = 0
        state = .standing
    }

    private func calculateKneeAngle(from joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> Double? {
        if let hip = joints[.leftHip],
           let knee = joints[.leftKnee],
           let ankle = joints[.leftAnkle] {
            return calculateAngle(p1: hip, vertex: knee, p3: ankle)
        }

        if let hip = joints[.rightHip],
           let knee = joints[.rightKnee],
           let ankle = joints[.rightAnkle] {
            return calculateAngle(p1: hip, vertex: knee, p3: ankle)
        }

        return nil
    }
}
