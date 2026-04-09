import Foundation
import Vision

final class SitUpCounter: ObservableObject, ExerciseCounter {
    @Published var currentReps: Int = 0

    private enum SitUpState {
        case down
        case up
    }

    private var state: SitUpState = .down
    private var smoother = SignalSmoother(windowSize: 7)
    private var holdCount: Int = 0

    // Optimized via scripts/optimize.py — shoulder Y position (peaks when sitting up)
    // Vision API Y: 0=bottom, 1=top. Shoulder rises during sit-up.
    // Scaled by 180 in Python → Swift values divided back by 180.
    private let downThreshold: Double = 59.0 / 180.0  // ~0.328 — lying down
    private let upThreshold: Double = 80.0 / 180.0    // ~0.444 — sitting up (count!)
    private let minHoldFrames: Int = 3

    func processJoints(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        guard let shoulderY = averageShoulderY(from: joints) else { return }
        let smoothed = smoother.push(shoulderY)

        switch state {
        case .down:
            if smoothed > upThreshold {
                holdCount += 1
                if holdCount >= minHoldFrames {
                    state = .up
                    holdCount = 0
                }
            } else {
                holdCount = 0
            }
        case .up:
            if smoothed < downThreshold {
                holdCount += 1
                if holdCount >= minHoldFrames {
                    state = .down
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
        state = .down
        holdCount = 0
        smoother.reset()
    }

    private func averageShoulderY(from joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> Double? {
        let left = joints[.leftShoulder]
        let right = joints[.rightShoulder]

        switch (left, right) {
        case let (.some(l), .some(r)):
            return (l.y + r.y) / 2.0
        case let (.some(l), .none):
            return l.y
        case let (.none, .some(r)):
            return r.y
        case (.none, .none):
            return nil
        }
    }
}
