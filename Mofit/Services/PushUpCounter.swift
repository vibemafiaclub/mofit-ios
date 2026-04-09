import Foundation
import Vision

final class PushUpCounter: ObservableObject, ExerciseCounter {
    @Published var currentReps: Int = 0

    private enum PushUpState {
        case up
        case down
    }

    private var state: PushUpState = .up
    private var smoother = SignalSmoother(windowSize: 5)
    private var holdCount: Int = 0

    // Optimized via scripts/optimize.py — elbow angle (Shoulder→Elbow→Wrist)
    private let downThreshold: Double = 94    // arm bent → "down"
    private let upThreshold: Double = 132     // arm extended → "up" (count!)
    private let minHoldFrames: Int = 3

    func processJoints(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        guard let angle = calculateElbowAngle(from: joints) else { return }
        let smoothed = smoother.push(angle)

        switch state {
        case .up:
            if smoothed < downThreshold {
                holdCount += 1
                if holdCount >= minHoldFrames {
                    state = .down
                    holdCount = 0
                }
            } else {
                holdCount = 0
            }
        case .down:
            if smoothed > upThreshold {
                holdCount += 1
                if holdCount >= minHoldFrames {
                    state = .up
                    currentReps += 1
                    holdCount = 0
                }
            } else {
                holdCount = 0
            }
        }
    }

    func reset() {
        currentReps = 0
        state = .up
        holdCount = 0
        smoother.reset()
    }

    private func calculateElbowAngle(from joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> Double? {
        // Try left side first, then right
        if let shoulder = joints[.leftShoulder],
           let elbow = joints[.leftElbow],
           let wrist = joints[.leftWrist] {
            return calculateAngle(p1: shoulder, vertex: elbow, p3: wrist)
        }

        if let shoulder = joints[.rightShoulder],
           let elbow = joints[.rightElbow],
           let wrist = joints[.rightWrist] {
            return calculateAngle(p1: shoulder, vertex: elbow, p3: wrist)
        }

        return nil
    }
}
