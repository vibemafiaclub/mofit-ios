import AVFoundation
import Vision

final class PoseDetectionService {
    private let request = VNDetectHumanBodyPoseRequest()

    func detectPose(in sampleBuffer: CMSampleBuffer) -> [VNHumanBodyPoseObservation.JointName: CGPoint]? {
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

        return extractJoints(from: observation)
    }

    private func extractJoints(from observation: VNHumanBodyPoseObservation) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .leftHip, .leftKnee, .leftAnkle,
            .rightHip, .rightKnee, .rightAnkle,
            .root, .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist
        ]

        for jointName in jointNames {
            if let point = try? observation.recognizedPoint(jointName),
               point.confidence > 0.3 {
                joints[jointName] = CGPoint(x: point.location.x, y: point.location.y)
            }
        }

        return joints
    }

    func convertToScreenCoordinates(
        _ point: CGPoint,
        viewSize: CGSize,
        isFrontCamera: Bool = true
    ) -> CGPoint {
        let x = isFrontCamera ? (1 - point.x) : point.x
        let y = 1 - point.y

        return CGPoint(
            x: x * viewSize.width,
            y: y * viewSize.height
        )
    }
}
