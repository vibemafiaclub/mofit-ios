import AVFoundation
import Vision
import Foundation

// MARK: - Joint Extraction

struct JointFrame: Codable {
    let t: Double
    let joints: [String: [Double]]  // jointName -> [x, y]
    let confidence: [String: Double]
}

let jointNames: [VNHumanBodyPoseObservation.JointName] = [
    .leftHip, .leftKnee, .leftAnkle,
    .rightHip, .rightKnee, .rightAnkle,
    .root, .nose, .neck,
    .leftShoulder, .rightShoulder,
    .leftElbow, .rightElbow,
    .leftWrist, .rightWrist
]

func jointNameString(_ name: VNHumanBodyPoseObservation.JointName) -> String {
    switch name {
    case .leftHip: return "leftHip"
    case .leftKnee: return "leftKnee"
    case .leftAnkle: return "leftAnkle"
    case .rightHip: return "rightHip"
    case .rightKnee: return "rightKnee"
    case .rightAnkle: return "rightAnkle"
    case .root: return "root"
    case .nose: return "nose"
    case .neck: return "neck"
    case .leftShoulder: return "leftShoulder"
    case .rightShoulder: return "rightShoulder"
    case .leftElbow: return "leftElbow"
    case .rightElbow: return "rightElbow"
    case .leftWrist: return "leftWrist"
    case .rightWrist: return "rightWrist"
    default: return name.rawValue.rawValue
    }
}

func extractJoints(from videoURL: URL, interval: Double = 0.05) throws -> [JointFrame] {
    let asset = AVURLAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    guard let duration = asset.tracks(withMediaType: .video).first?.timeRange.duration else {
        throw NSError(domain: "ExtractJoints", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read video duration"])
    }

    let durationSeconds = CMTimeGetSeconds(duration)
    let request = VNDetectHumanBodyPoseRequest()
    var frames: [JointFrame] = []

    var currentTime: Double = 0
    while currentTime <= durationSeconds {
        let cmTime = CMTimeMakeWithSeconds(currentTime, preferredTimescale: 600)

        guard let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) else {
            currentTime += interval
            continue
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            currentTime += interval
            continue
        }

        var jointsDict: [String: [Double]] = [:]
        var confDict: [String: Double] = [:]

        for jointName in jointNames {
            if let point = try? observation.recognizedPoint(jointName) {
                let name = jointNameString(jointName)
                jointsDict[name] = [
                    (point.location.x * 10000).rounded() / 10000,
                    (point.location.y * 10000).rounded() / 10000
                ]
                confDict[name] = Double((point.confidence * 1000).rounded() / 1000)
            }
        }

        frames.append(JointFrame(
            t: (currentTime * 1000).rounded() / 1000,
            joints: jointsDict,
            confidence: confDict
        ))

        currentTime += interval
    }

    return frames
}

// MARK: - Main

let args = CommandLine.arguments
let videosDir: String
let outputDir: String

if args.count >= 3 {
    videosDir = args[1]
    outputDir = args[2]
} else {
    videosDir = "../../videos"
    outputDir = "../data"
}

let fileManager = FileManager.default

// Create output directory
try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// Find all .MOV files
let videosURL = URL(fileURLWithPath: videosDir)
let videoFiles = try fileManager.contentsOfDirectory(at: videosURL, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.uppercased() == "MOV" }

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

for videoURL in videoFiles {
    let name = videoURL.deletingPathExtension().lastPathComponent
    print("Processing \(name)...")

    let startTime = Date()
    let frames = try extractJoints(from: videoURL, interval: 0.05)
    let elapsed = Date().timeIntervalSince(startTime)

    let outputURL = URL(fileURLWithPath: outputDir).appendingPathComponent("\(name).json")
    let data = try encoder.encode(frames)
    try data.write(to: outputURL)

    print("  \(frames.count) frames extracted in \(String(format: "%.1f", elapsed))s → \(outputURL.lastPathComponent)")
}

print("Done!")
