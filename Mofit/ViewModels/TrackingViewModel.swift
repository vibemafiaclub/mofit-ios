import AVFoundation
import Combine
import Foundation
import SwiftData
import UIKit
import Vision

enum TrackingState: Equatable {
    case idle
    case countdown(Int)
    case tracking
    case setComplete
}

enum DiagnosticHint {
    case outOfFrame
    case lowLight

    var message: String {
        switch self {
        case .outOfFrame: return TrackingViewModel.Diagnostic.outOfFrameCopy
        case .lowLight:  return TrackingViewModel.Diagnostic.lowLightCopy
        }
    }

    var iconName: String {
        switch self {
        case .outOfFrame: return "viewfinder"
        case .lowLight:  return "lightbulb"
        }
    }
}

@MainActor
final class TrackingViewModel: ObservableObject {
    @Published var state: TrackingState = .idle
    @Published var currentSet: Int = 1
    @Published var currentReps: Int = 0
    @Published var elapsedTime: Int = 0
    @Published var jointPoints: [CGPoint] = []
    @Published var repCounts: [Int] = []
    @Published var saveError: String?
    @Published var diagnosticHint: DiagnosticHint? = nil

    private let cameraManager: CameraManager
    private let poseDetectionService = PoseDetectionService()
    private let handDetectionService = HandDetectionService()
    private var evaluator = DiagnosticHintEvaluator()

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
        diagnosticHint = nil
        evaluator.reset()

        cameraManager.onFrameCaptured = { [weak self] sampleBuffer in
            Task { @MainActor [weak self] in
                self?.processFrame(sampleBuffer)
            }
        }

        cameraManager.startSession()
    }

    func stopSession(modelContext: ModelContext, isLoggedIn: Bool) {
        cameraManager.stopSession()
        countdownTimer?.invalidate()
        countdownTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        diagnosticHint = nil

        if currentReps > 0 {
            repCounts.append(currentReps)
        }

        guard !repCounts.isEmpty else { return }

        let startedAt = sessionStartTime ?? Date()
        let endedAt = Date()

        if isLoggedIn {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let serverSession = ServerSession(
                id: nil,
                exerciseType: exerciseType,
                startedAt: formatter.string(from: startedAt),
                endedAt: formatter.string(from: endedAt),
                totalDuration: elapsedTime,
                repCounts: repCounts
            )
            Task {
                do {
                    _ = try await APIService.shared.createSession(serverSession)
                } catch {
                    saveError = error.localizedDescription
                }
            }
        } else {
            let session = WorkoutSession(
                exerciseType: exerciseType,
                startedAt: startedAt,
                endedAt: endedAt,
                totalDuration: elapsedTime,
                repCounts: repCounts
            )
            modelContext.insert(session)
        }
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let isPalmDetected = handDetectionService.detectOpenPalm(in: sampleBuffer)
        handlePalmDetection(isPalmDetected)

        guard case .tracking = state else { return }

        // 호출 순서 고정: (1) detectPoseDetailed → (2) processJointsForExercise → (3) updateJointPoints → (4)+(5) evaluator.update → diagnosticHint 반영
        // 순서 변경 시 squatCounter.currentReps 갱신이 evaluator.update 보다 늦어져 한 프레임 힌트 잔상 발생.
        let result = poseDetectionService.detectPoseDetailed(in: sampleBuffer)
        let joints = result?.joints ?? [:]
        processJointsForExercise(joints)
        updateJointPoints(joints)
        diagnosticHint = evaluator.update(
            now: Date(),
            hasCompleteSideForSquat: result?.hasCompleteSideForSquat ?? false,
            lowerBodyAvgConfidence: result?.lowerBodyAvgConfidence,
            currentReps: currentReps
        )
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
                triggerSetAction()
            }
        } else {
            palmDetectionStartTime = nil
        }
    }

    func handleScreenTap() {
        switch state {
        case .idle:
            triggerSetAction()
        case .tracking:
            guard currentReps > 0 else { return }
            triggerHapticFeedback()
            triggerSetAction()
        case .countdown, .setComplete:
            return
        }
    }

    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func triggerSetAction() {
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
        evaluator.startTracking(at: Date())
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

extension TrackingViewModel {
    /// 이 파일의 상수는 Diagnostic 힌트 UX 정책용. Vision raw confidence 필터(0.3)는 PoseDetectionService 에 있음.
    fileprivate enum Diagnostic {
        static let graceSeconds: TimeInterval = 5.0
        static let sustainSeconds: TimeInterval = 3.0
        static let lowLightConfidenceThreshold: Double = 0.5
        static let outOfFrameCopy = "전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)"
        static let lowLightCopy = "조명이 어두울 수 있어요 · 실내 조명을 밝혀주세요"
    }
}

// DiagnosticHintEvaluator 는 Foundation 외 import 없이 동작하는 pure struct.
// lowerBodyAvgConfidence 는 0.5 경계 근처에서 프레임마다 튈 수 있다.
// 3초 sustain 규칙이 이 노이즈를 흡수하므로 히스테리시스 로직은 별도 추가하지 않는다.
// 만약 힌트 점멸이 관찰되면 threshold 를 내리거나 sustain 을 늘리는 방향으로 튜닝.
// startTracking(at:) 은 trackingStartedAt 만 세팅한다. hintHidden/streak 은 reset() 만 초기화한다.
fileprivate struct DiagnosticHintEvaluator {
    private var trackingStartedAt: Date?
    private var outOfFrameStreakStart: Date?
    private var lowLightStreakStart: Date?
    private var hintHidden: Bool = false

    mutating func reset() {
        trackingStartedAt = nil
        outOfFrameStreakStart = nil
        lowLightStreakStart = nil
        hintHidden = false
    }

    mutating func startTracking(at now: Date) {
        trackingStartedAt = now
        // hintHidden, streak 은 의도적으로 리셋하지 않는다 — 세션 범위로 유지.
    }

    mutating func update(now: Date, hasCompleteSideForSquat: Bool, lowerBodyAvgConfidence: Double?, currentReps: Int) -> DiagnosticHint? {
        // 1) rep 카운트되면 숨김 고정
        if currentReps > 0 {
            hintHidden = true
            outOfFrameStreakStart = nil
            lowLightStreakStart = nil
            return nil
        }
        // 2) 한 번 숨김되면 세션 내 재표시 금지
        if hintHidden {
            outOfFrameStreakStart = nil
            lowLightStreakStart = nil
            return nil
        }
        // 3) grace — 트래킹 시작 직후 5초간 streak 계산 안 함
        guard let trackStart = trackingStartedAt,
              now.timeIntervalSince(trackStart) >= TrackingViewModel.Diagnostic.graceSeconds else {
            outOfFrameStreakStart = nil
            lowLightStreakStart = nil
            return nil
        }
        // 4) outOfFrame 분기 — 상호배타로 lowLightStreak 강제 리셋
        if !hasCompleteSideForSquat {
            lowLightStreakStart = nil
            if outOfFrameStreakStart == nil {
                outOfFrameStreakStart = now
            }
            if let outStart = outOfFrameStreakStart,
               now.timeIntervalSince(outStart) >= TrackingViewModel.Diagnostic.sustainSeconds {
                return .outOfFrame
            }
            return nil
        }
        // 5) lowLight 분기 — 상호배타로 outOfFrameStreak 강제 리셋
        outOfFrameStreakStart = nil
        if let avg = lowerBodyAvgConfidence,
           avg < TrackingViewModel.Diagnostic.lowLightConfidenceThreshold {
            if lowLightStreakStart == nil {
                lowLightStreakStart = now
            }
            if let lowStart = lowLightStreakStart,
               now.timeIntervalSince(lowStart) >= TrackingViewModel.Diagnostic.sustainSeconds {
                return .lowLight
            }
            return nil
        }
        // 6) 정상 프레임 — 모든 streak 리셋
        lowLightStreakStart = nil
        return nil
    }
}
