import AVFoundation
import Combine
import Foundation
import SwiftData
import Vision

enum TrackingState: Equatable {
    case idle
    case countdown(Int)
    case tracking
    case setComplete
}

@MainActor
final class TrackingViewModel: ObservableObject {
    @Published var state: TrackingState = .idle
    @Published var currentSet: Int = 1
    @Published var currentReps: Int = 0
    @Published var elapsedTime: Int = 0
    @Published var jointPoints: [CGPoint] = []
    @Published var repCounts: [Int] = []

    private let cameraManager: CameraManager
    private let poseDetectionService = PoseDetectionService()
    private let handDetectionService = HandDetectionService()

    let exerciseType: String
    private let squatCounter: SquatCounter?
    private let pushUpCounter: PushUpCounter?
    private let sitUpCounter: SitUpCounter?

    private var countdownTimer: Timer?
    private var elapsedTimer: Timer?
    private var palmDetectionStartTime: Date?
    private var sessionStartTime: Date?
    private var hasStartedElapsedTimer = false
    private var cancellables = Set<AnyCancellable>()

    var viewSize: CGSize = .zero

    init(exerciseType: String = "squat", cameraManager: CameraManager = CameraManager()) {
        self.exerciseType = exerciseType
        self.cameraManager = cameraManager

        switch exerciseType {
        case "pushup":
            let counter = PushUpCounter()
            self.pushUpCounter = counter
            self.squatCounter = nil
            self.sitUpCounter = nil
        case "situp":
            let counter = SitUpCounter()
            self.sitUpCounter = counter
            self.squatCounter = nil
            self.pushUpCounter = nil
        default:
            let counter = SquatCounter()
            self.squatCounter = counter
            self.pushUpCounter = nil
            self.sitUpCounter = nil
        }

        setupBindings()
    }

    private func setupBindings() {
        if let counter = squatCounter {
            counter.$currentReps
                .receive(on: DispatchQueue.main)
                .sink { [weak self] reps in self?.currentReps = reps }
                .store(in: &cancellables)
        } else if let counter = pushUpCounter {
            counter.$currentReps
                .receive(on: DispatchQueue.main)
                .sink { [weak self] reps in self?.currentReps = reps }
                .store(in: &cancellables)
        } else if let counter = sitUpCounter {
            counter.$currentReps
                .receive(on: DispatchQueue.main)
                .sink { [weak self] reps in self?.currentReps = reps }
                .store(in: &cancellables)
        }
    }

    var captureSession: AVCaptureSession {
        cameraManager.captureSession
    }

    func startSession() {
        state = .idle
        currentSet = 1
        currentReps = 0
        elapsedTime = 0
        jointPoints = []
        repCounts = []
        palmDetectionStartTime = nil
        sessionStartTime = nil
        hasStartedElapsedTimer = false
        resetCounter()

        cameraManager.onFrameCaptured = { [weak self] sampleBuffer in
            Task { @MainActor [weak self] in
                self?.processFrame(sampleBuffer)
            }
        }

        cameraManager.startSession()
    }

    func stopSession(modelContext: ModelContext) {
        cameraManager.stopSession()
        countdownTimer?.invalidate()
        countdownTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil

        if currentReps > 0 {
            repCounts.append(currentReps)
        }

        if !repCounts.isEmpty {
            let session = WorkoutSession(
                exerciseType: exerciseType,
                startedAt: sessionStartTime ?? Date(),
                endedAt: Date(),
                totalDuration: elapsedTime,
                repCounts: repCounts
            )
            modelContext.insert(session)
        }
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let isPalmDetected = handDetectionService.detectOpenPalm(in: sampleBuffer)
        handlePalmDetection(isPalmDetected)

        if case .tracking = state {
            if let joints = poseDetectionService.detectPose(in: sampleBuffer) {
                processJointsForExercise(joints)
                updateJointPoints(joints)
            }
        }
    }

    private func handlePalmDetection(_ detected: Bool) {
        guard state == .idle || state == .tracking else {
            palmDetectionStartTime = nil
            return
        }

        if detected {
            if palmDetectionStartTime == nil {
                palmDetectionStartTime = Date()
            } else if let startTime = palmDetectionStartTime,
                      Date().timeIntervalSince(startTime) >= 1.0 {
                palmDetectionStartTime = nil
                triggerPalmAction()
            }
        } else {
            palmDetectionStartTime = nil
        }
    }

    private func triggerPalmAction() {
        switch state {
        case .idle:
            startCountdown()
        case .tracking:
            completeSet()
        default:
            break
        }
    }

    private func startCountdown() {
        state = .countdown(5)

        if !hasStartedElapsedTimer {
            hasStartedElapsedTimer = true
            sessionStartTime = Date()
            startElapsedTimer()
        }

        countdownTimer?.invalidate()
        var countdown = 5
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                countdown -= 1
                if countdown > 0 {
                    self.state = .countdown(countdown)
                } else {
                    timer.invalidate()
                    self.countdownTimer = nil
                    self.startTracking()
                }
            }
        }
    }

    private func startTracking() {
        state = .tracking
        resetCounter()
        currentReps = 0
    }

    private func processJointsForExercise(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        squatCounter?.processJoints(joints)
        pushUpCounter?.processJoints(joints)
        sitUpCounter?.processJoints(joints)
    }

    private func resetCounter() {
        squatCounter?.reset()
        pushUpCounter?.reset()
        sitUpCounter?.reset()
    }

    private func completeSet() {
        if currentReps > 0 {
            repCounts.append(currentReps)
        }
        state = .setComplete
        currentSet += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startCountdown()
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedTime += 1
            }
        }
    }

    private func updateJointPoints(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }

        jointPoints = joints.values.map { point in
            poseDetectionService.convertToScreenCoordinates(
                point,
                viewSize: viewSize,
                isFrontCamera: true
            )
        }
    }
}
