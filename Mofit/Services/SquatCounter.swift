import Foundation
import Vision

final class SquatCounter: ObservableObject {
    @Published var currentReps: Int = 0

    private enum SquatState {
        case standing
        case squatting
    }

    private var state: SquatState = .standing

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
        if let leftAngle = calculateAngle(
            hip: joints[.leftHip],
            knee: joints[.leftKnee],
            ankle: joints[.leftAnkle]
        ) {
            return leftAngle
        }

        if let rightAngle = calculateAngle(
            hip: joints[.rightHip],
            knee: joints[.rightKnee],
            ankle: joints[.rightAnkle]
        ) {
            return rightAngle
        }

        return nil
    }

    private func calculateAngle(hip: CGPoint?, knee: CGPoint?, ankle: CGPoint?) -> Double? {
        guard let hip = hip, let knee = knee, let ankle = ankle else {
            return nil
        }

        let angleRadians = atan2(ankle.y - knee.y, ankle.x - knee.x) - atan2(hip.y - knee.y, hip.x - knee.x)
        var angleDegrees = abs(angleRadians * 180 / .pi)

        if angleDegrees > 180 {
            angleDegrees = 360 - angleDegrees
        }

        return angleDegrees
    }
}
