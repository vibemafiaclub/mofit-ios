import Foundation
import Vision

/// Protocol for all exercise counters.
/// Each exercise implements its own signal extraction and threshold logic.
protocol ExerciseCounter: ObservableObject {
    var currentReps: Int { get set }
    func processJoints(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint])
    func reset()
}

/// Simple moving-average buffer for smoothing noisy joint signals.
struct SignalSmoother {
    private var buffer: [Double] = []
    let windowSize: Int

    init(windowSize: Int) {
        self.windowSize = max(1, windowSize)
    }

    mutating func push(_ value: Double) -> Double {
        buffer.append(value)
        if buffer.count > windowSize {
            buffer.removeFirst()
        }
        return buffer.reduce(0, +) / Double(buffer.count)
    }

    mutating func reset() {
        buffer.removeAll()
    }
}

/// Shared angle calculation — identical across all counters.
func calculateAngle(p1: CGPoint, vertex: CGPoint, p3: CGPoint) -> Double {
    let angleRadians = atan2(p3.y - vertex.y, p3.x - vertex.x)
                     - atan2(p1.y - vertex.y, p1.x - vertex.x)
    var angleDegrees = abs(angleRadians * 180 / .pi)
    if angleDegrees > 180 {
        angleDegrees = 360 - angleDegrees
    }
    return angleDegrees
}
