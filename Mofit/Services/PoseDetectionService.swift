import AVFoundation
import Vision

struct PoseFrameResult {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let lowerBodyAvgConfidence: Double?
    let hasCompleteSideForSquat: Bool
}

final class PoseDetectionService {
    private let request = VNDetectHumanBodyPoseRequest()

    func detectPoseDetailed(in sampleBuffer: CMSampleBuffer) -> PoseFrameResult? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else {
            return nil
        }

        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var lowerBodyConfidences: [Double] = []

        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .leftHip, .leftKnee, .leftAnkle,
            .rightHip, .rightKnee, .rightAnkle,
            .root, .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist
        ]

        let lowerBodySet: Set<VNHumanBodyPoseObservation.JointName> = [
            .leftHip, .leftKnee, .leftAnkle,
            .rightHip, .rightKnee, .rightAnkle
        ]

        for jointName in jointNames {
            if let point = try? observation.recognizedPoint(jointName),
               point.confidence > 0.3 {
                joints[jointName] = CGPoint(x: point.location.x, y: point.location.y)
                if lowerBodySet.contains(jointName) {
                    lowerBodyConfidences.append(Double(point.confidence))
                }
            }
        }

        let lowerBodyAvgConfidence: Double? = lowerBodyConfidences.isEmpty
            ? nil
            : lowerBodyConfidences.reduce(0, +) / Double(lowerBodyConfidences.count)

        let hasLeft = joints[.leftHip] != nil && joints[.leftKnee] != nil && joints[.leftAnkle] != nil
        let hasRight = joints[.rightHip] != nil && joints[.rightKnee] != nil && joints[.rightAnkle] != nil
        let hasCompleteSideForSquat = hasLeft || hasRight

        return PoseFrameResult(
            joints: joints,
            lowerBodyAvgConfidence: lowerBodyAvgConfidence,
            hasCompleteSideForSquat: hasCompleteSideForSquat
        )
    }

    func convertToScreenCoordinates(
        _ point: CGPoint,
        viewSize: CGSize,
        isFrontCamera: Bool = true
    ) -> CGPoint {
        let x = isFrontCamera ? (1 - point.x) : point.x
        let y = 1 - point.y
        return CGPoint(x: x * viewSize.width, y: y * viewSize.height)
    }
}
