import AVFoundation
import Vision

final class HandDetectionService {
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()

    func detectOpenPalm(in sampleBuffer: CMSampleBuffer) -> Bool {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return false
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return false
        }

        guard let observation = request.results?.first else {
            return false
        }

        return isOpenPalm(observation: observation)
    }

    private func isOpenPalm(observation: VNHumanHandPoseObservation) -> Bool {
        let extendedFingers = countExtendedFingers(observation: observation)
        return extendedFingers >= 4
    }

    private func countExtendedFingers(observation: VNHumanHandPoseObservation) -> Int {
        var count = 0

        if isFingerExtended(observation: observation, tip: .thumbTip, pip: .thumbIP) {
            count += 1
        }
        if isFingerExtended(observation: observation, tip: .indexTip, pip: .indexPIP) {
            count += 1
        }
        if isFingerExtended(observation: observation, tip: .middleTip, pip: .middlePIP) {
            count += 1
        }
        if isFingerExtended(observation: observation, tip: .ringTip, pip: .ringPIP) {
            count += 1
        }
        if isFingerExtended(observation: observation, tip: .littleTip, pip: .littlePIP) {
            count += 1
        }

        return count
    }

    private func isFingerExtended(
        observation: VNHumanHandPoseObservation,
        tip: VNHumanHandPoseObservation.JointName,
        pip: VNHumanHandPoseObservation.JointName
    ) -> Bool {
        guard let tipPoint = try? observation.recognizedPoint(tip),
              let pipPoint = try? observation.recognizedPoint(pip),
              let wristPoint = try? observation.recognizedPoint(.wrist),
              tipPoint.confidence > 0.3,
              pipPoint.confidence > 0.3,
              wristPoint.confidence > 0.3 else {
            return false
        }

        let tipToWrist = distance(from: tipPoint.location, to: wristPoint.location)
        let pipToWrist = distance(from: pipPoint.location, to: wristPoint.location)

        return tipToWrist > pipToWrist
    }

    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}
