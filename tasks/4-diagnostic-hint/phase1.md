# Phase 1: hint-impl

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다 (Phase 0 이 이미 커밋되어 있어야 한다).

```bash
git status --porcelain -- docs/ Mofit/ project.yml README.md
```

출력되는 파일이 있으면 working tree 가 더럽다. 진행하지 말고 `tasks/4-diagnostic-hint/index.json` 의 phase 1 status 를 `"error"`로 변경, `error_message` 에 `dirty working tree before phase 1` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/spec.md` (§2.4 카메라 파이프라인, §2.5 트래킹 진단 힌트 — Phase 0 신규. 이번 phase 설계 원전)
- `docs/adr.md` (ADR-018 — 이번 phase 의 설계 원전. ADR-017, ADR-015, ADR-014, ADR-013 참조)
- `docs/code-architecture.md` (§디렉토리 구조. Phase 0 에서 Services/ViewModels 주석 갱신됨)
- `docs/testing.md` (**MofitTests 타겟 신설 금지**. 이번 phase 는 build + grep 으로 AC 커버, 단위 테스트는 phase 1 에이전트의 코드 트레이스)
- `docs/user-intervention.md` (실기기 QA 절차 — Phase 0 에서 신규 추가)
- `tasks/4-diagnostic-hint/docs-diff.md` (Phase 0 docs 변경 실제 diff — runner 자동 생성)
- `iterations/5-20260424_210420/requirement.md` (iteration 원문 읽기 전용. 특히 §구현 스케치, §CTO 승인 조건부 1~5)

그리고 이전 phase 의 작업물 + 기존 코드를 반드시 확인하라:

- `Mofit/Services/PoseDetectionService.swift` — **재작성 대상.** 현재 `detectPose(in:) -> [VNHumanBodyPoseObservation.JointName: CGPoint]?` 와 `extractJoints(from:)` 두 메서드가 있다. 이번 phase 에서 전체를 `PoseFrameResult` 구조체 + `detectPoseDetailed(in:)` 단일 메서드 + `convertToScreenCoordinates(...)` (불변) 로 교체한다.
- `Mofit/ViewModels/TrackingViewModel.swift` — 수정 대상. 기존 파일의 핵심 구조:
  - L8~13 `enum TrackingState` — **불변**
  - L17~23 `@Published` 프로퍼티 7개 — **불변** (+ 이번 phase 에서 `diagnosticHint` 1개 추가)
  - L26~27 `poseDetectionService`, `handDetectionService` — **불변**
  - L29~32 `exerciseType`, 3종 Counter — **불변**
  - L91~110 `startSession()` — evaluator.reset() + `diagnosticHint = nil` 추가만
  - L158~168 `processFrame` — 5단계 고정 호출 순서로 재작성 (아래 § 구현 요구사항 1-b 참조)
  - L247~251 `startTracking()` — `evaluator.startTracking(at: Date())` 호출 추가만
  - L112~156 `stopSession` — `diagnosticHint = nil` 추가만
- `Mofit/Views/Tracking/TrackingView.swift` — 수정 대상. 기존 ZStack(L21~40) 에 `hintBanner` 오버레이 1개 + `hintBanner(hint:)` private func 1개 추가.
- `Mofit/Services/SquatCounter.swift`, `Mofit/Services/HandDetectionService.swift` — **수정 금지.**
- `Mofit/Services/PushUpCounter.swift`, `Mofit/Services/SitUpCounter.swift`, `Mofit/Services/ExerciseCounter.swift` — **수정 금지** (ADR-017 조건부 #1 자산 보존).
- `Mofit/Camera/CameraManager.swift`, `Mofit/Camera/CameraPreviewView.swift` — **수정 금지.**
- `Mofit/Views/Home/HomeView.swift` — **수정 금지** (`TrackingView(exerciseType: "squat", ...)` 호출 그대로 유지).
- `project.yml` — 수정 금지. 글롭 기반이므로 파일 수정만으로 pbxproj 재생성 시 반영됨.

이전 phase 의 문서(ADR-018, spec §2.5) 가 선언한 설계를 실코드로 옮긴다. 목표: **Service 1 파일 재작성 + ViewModel 1 파일 확장 + View 1 파일 확장**. 신규 `.swift` 파일 생성 금지. `MofitTests/` 디렉토리 생성 금지.

## 작업 내용

### 대상 파일 (정확히 3개 + xcodegen 재생성)

1. **재작성**: `Mofit/Services/PoseDetectionService.swift`
2. **확장**: `Mofit/ViewModels/TrackingViewModel.swift`
3. **확장**: `Mofit/Views/Tracking/TrackingView.swift`
4. **재생성**: `Mofit.xcodeproj/project.pbxproj` (xcodegen 자동)

### 목적

iter 5 persona(`home-workout-newbie-20s`, tech_literacy: medium, 3일 체험 삭제 패턴) 가 "왜 안 세어지나요?" 를 혼자 추정하는 부담을 제거. 가치제안 §5.2 자체 고지 "실패 가이드 UI 얕음" 을 인앱에서 증명. 2종 진단 배너(.outOfFrame / .lowLight) 를 상단 반투명 1줄로 노출.

### 구현 요구사항

#### 1-a) `Mofit/Services/PoseDetectionService.swift` — 전체 재작성

기존 파일을 아래 구조로 교체한다. **기존 `detectPose(in:)` 와 `extractJoints(from:)` 는 삭제** (CTO 조건부 #3 해석: 외부 호출자 Grep 결과 TVM 1곳뿐이고 이번 phase 에서 detailed 로 스왑되므로 dead code 를 남길 이유 없음). `convertToScreenCoordinates(...)` 는 **그대로 유지**.

**시그니처**:

```swift
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
        // 1) CVPixelBuffer 추출 실패 또는 VN perform 실패 시 nil 반환
        // 2) observation.results.first 없으면 nil 반환
        // 3) 15개 관절(leftHip/leftKnee/leftAnkle/rightHip/rightKnee/rightAnkle/root/nose/neck/leftShoulder/rightShoulder/leftElbow/rightElbow/leftWrist/rightWrist) 을 순회하며
        //    - confidence > 0.3 통과분의 location(CGPoint) 를 joints dict 에 저장
        //    - 하체 6개(leftHip/leftKnee/leftAnkle/rightHip/rightKnee/rightAnkle) 중 통과분의 confidence 를 별도 배열에 수집
        // 4) lowerBodyAvgConfidence:
        //    - 수집된 하체 confidence 배열이 empty 면 nil
        //    - 아니면 배열 평균(Double)
        // 5) hasCompleteSideForSquat:
        //    - joints dict 에 (leftHip, leftKnee, leftAnkle) 3개 모두 있거나 (rightHip, rightKnee, rightAnkle) 3개 모두 있으면 true
        //    - 둘 다 아니면 false
        // 6) PoseFrameResult(joints, lowerBodyAvgConfidence, hasCompleteSideForSquat) 반환
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
```

**규칙**:
- `detectPose(in:)` 메서드 또는 `extractJoints` 헬퍼를 다시 추가하지 마라.
- confidence 필터 임계치 `0.3` 은 이 파일에 literal 로 유지 (raw Vision 노이즈 필터 — UX 정책 상수와 분리).
- `PoseFrameResult` 는 필드 3개 고정. 추가 필드/미래 확장 금지.
- `convertToScreenCoordinates` 시그니처 불변.

#### 1-b) `Mofit/ViewModels/TrackingViewModel.swift` — 확장

##### 1-b-i) 파일 상단 `enum TrackingState` 선언부 **뒤** (line 13 `}` 이후 빈 줄 뒤) 에 추가:

```swift
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
```

- `DiagnosticHint` 는 top-level (enum TrackingState 와 동일 레벨). `TrackingViewModel` 내부 nested 가 아님.
- case 정확히 **2개**. 추가 금지.

##### 1-b-ii) `TrackingViewModel` 클래스 **상단 프로퍼티** 에 추가:

- `@Published var diagnosticHint: DiagnosticHint? = nil` — 기존 `@Published` 프로퍼티 블록(line 17~23) 의 **맨 끝** 에 한 줄 추가 (saveError 다음).
- 기존 `private let poseDetectionService = PoseDetectionService()` 뒤 블록 내부에 저장 프로퍼티 한 줄 추가:
  ```swift
  private var evaluator = DiagnosticHintEvaluator()
  ```

##### 1-b-iii) `TrackingViewModel` 클래스 **안쪽** 에 nested 타입 2개 추가 (파일 하단, `updateJointPoints` 다음, 클래스 닫는 `}` 바로 전 위치):

```swift
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

    mutating func update(
        now: Date,
        hasCompleteSideForSquat: Bool,
        lowerBodyAvgConfidence: Double?,
        currentReps: Int
    ) -> DiagnosticHint? {
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
```

- Evaluator update 는 위 6단계 pseudo-code 를 **그대로 구현**. 단계 합치거나 순서 바꾸지 마라.
- `Date` / `TimeInterval` / `Double` / `Bool` / `Int` / `Optional` 만 사용. Vision/Combine/SwiftUI import 금지. (TrackingViewModel.swift 자체는 AVFoundation/Combine/SwiftData/UIKit/Vision 을 import 하지만, DiagnosticHintEvaluator struct 내부는 Foundation 타입만 쓴다.)

##### 1-b-iv) `startSession()` 수정 — 기존 L91~110 에서 `hasStartedElapsedTimer = false` 다음 줄에 2 줄 추가:

```swift
        diagnosticHint = nil
        evaluator.reset()
```

- 기존 로직 순서 불변.

##### 1-b-v) `startTracking()` 수정 — 기존 L247~251:

```swift
    private func startTracking() {
        state = .tracking
        resetCounter()
        currentReps = 0
    }
```

**신규** (evaluator.startTracking(at:) 호출 1줄 추가):

```swift
    private func startTracking() {
        state = .tracking
        resetCounter()
        currentReps = 0
        evaluator.startTracking(at: Date())
    }
```

##### 1-b-vi) `processFrame(_:)` 수정 — 호출 순서 **5단계 고정**. 기존 L158~168:

```swift
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
```

**신규** (호출 순서 5단계 고정 주석 포함):

```swift
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
```

- **`poseDetectionService.detectPoseDetailed(` 호출 정확히 1곳.** 다른 곳 추가 금지.
- `result` 가 nil 인 경우(Vision 실패 또는 사람 미감지) `hasCompleteSideForSquat=false` 로 취급해 outOfFrame 경로 진입.
- `currentReps` 는 `@Published` 프로퍼티로, `setupBindings` 를 통해 active counter 의 reps 를 반영. squat 외 운동에서도 동일하게 동작(exercise-agnostic).
- `processJointsForExercise(joints)` 가 `squatCounter.currentReps` 를 증가시키고, Combine 바인딩으로 `self.currentReps` 가 같은 frame 에서 갱신된 뒤 evaluator 에 전달된다. 이 순서를 바꾸지 마라.

##### 1-b-vii) `stopSession(modelContext:isLoggedIn:)` 수정 — 기존 L112~156 의 `elapsedTimer = nil` 다음 줄에 1줄 추가:

```swift
        diagnosticHint = nil
```

- evaluator.reset() 은 여기서 호출하지 않는다. stopSession 이후 재진입은 새 `startSession()` 이 담당.

##### 1-b-viii) 세트 경계(`completeSet()` L265~275) 는 **수정 금지**. evaluator.reset() 이나 startTracking(at:) 호출 추가 금지. "세션 = TrackingView lifecycle" 해석 고정.

#### 1-c) `Mofit/Views/Tracking/TrackingView.swift` — 확장

##### 1-c-i) ZStack(L21~40) 내부, **jointOverlay 바로 뒤** 에 아래 overlay 추가:

```swift
                if let hint = viewModel.diagnosticHint {
                    hintBanner(hint: hint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 120)
                }
```

- `padding(.top, 120)` 은 기존 info bar(top 60 + 세트/시간 콘텐츠) 아래에 배치하기 위한 수치. 상향 조정 금지.
- hintBanner 는 stopButton(하단) 과 overlap 없음 (alignment: .top + padding .top).

##### 1-c-ii) `TrackingView` struct **하단**, `formatTime(_:)` private 함수 **바로 앞** 에 아래 private func 추가:

```swift
    private func hintBanner(hint: DiagnosticHint) -> some View {
        HStack(spacing: 10) {
            Image(systemName: hint.iconName)
                .font(.subheadline)
                .foregroundColor(.white)
            Text(hint.message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
```

- `hint.iconName`, `hint.message` 는 DiagnosticHint enum 의 computed 프로퍼티 (1-b-i).
- 카피 리터럴은 **이 View 파일에 직접 쓰지 마라.** 단일 소스는 TVM `Diagnostic` enum.
- HintBanner 전용 신규 파일 생성 금지. TrackingView 내부 private func 로만.

#### 1-d) xcodegen generate

```bash
xcodegen generate
```

- 글롭 기반이라 `PoseDetectionService.swift` 재작성만으로 pbxproj 가 자동 반영.
- `project.yml` 수정 금지.

### 구현 후 코드 트레이스 검증 (MofitTests 대체)

DiagnosticHintEvaluator 는 pure struct 이므로 AC 이후 아래 6개 시나리오를 **에이전트가 직접 코드 흐름을 따라가며 수학적으로 검증**하라(단위 테스트 파일 생성 금지). 각 시나리오의 예상 결과와 실제 Evaluator update 결과가 일치해야 한다. 불일치 시 구현 수정.

각 시나리오는 `var ev = DiagnosticHintEvaluator(); ev.reset(); ev.startTracking(at: t0)` 를 시작점으로 한다.

1. **(grace)** `t0=0`, `t=1` 시점 `update(now: t, hasComplete: false, avgConf: nil, currentReps: 0)` → `nil`. (시작 후 5초 미만)
2. **(outOfFrame sustain 만족)** `t0=0`, 각 `t ∈ {5.1, 6.0, 7.0, 8.1}` 에서 `update(now: t, hasComplete: false, avgConf: nil, currentReps: 0)` → t=5.1/6.0/7.0 `nil`, t=8.1 `.outOfFrame`. (outStreak 시작 5.1, 지속 3.0 → 8.1 만족)
3. **(sustain 중간 회복)** `t0=0`, `update(5.1, false, nil, 0)→nil`, `update(7.0, true, 0.8, 0)→nil` (outStreak 리셋), `update(8.0, false, nil, 0)→nil` (outStreak 재시작), `update(11.1, false, nil, 0)→.outOfFrame`.
4. **(rep 카운트 후 숨김)** `t0=0`, `update(6.0, false, nil, 0)→nil`, `update(7.0, false, nil, 1)→nil (hintHidden=true)`, `update(10.0, false, nil, 1)→nil`, `update(20.0, false, nil, 0)→nil (hintHidden 유지)`.
5. **(lowLight sustain 만족)** `t0=0`, `update(5.1, true, 0.35, 0)→nil`, `update(8.1, true, 0.35, 0)→.lowLight`.
6. **(우선순위 — outOfFrame 우선)** `t0=0`, `update(5.1, false, 0.35, 0)→nil (outStreak 시작, lowStreak=nil 강제)`, `update(8.1, false, 0.35, 0)→.outOfFrame`.
6c. **(outOfFrame → lowLight 전환)** `t0=0`, `update(5.1, false, nil, 0)→nil`, `update(7.0, false, nil, 0)→nil`, `update(7.1, true, 0.35, 0)→nil (outStreak=nil, lowStreak 시작)`, `update(10.1, true, 0.35, 0)→.lowLight`.

검증 실패 시 Evaluator update 의 6단계를 재검토. 각 단계의 streak nil 강제가 누락되면 시나리오 3/6/6c 가 깨진다.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다.

```bash
# 1) PoseDetectionService — 재작성 가드
! grep -F 'func detectPose(in' Mofit/Services/PoseDetectionService.swift
! grep -F 'extractJoints' Mofit/Services/PoseDetectionService.swift
grep -F 'struct PoseFrameResult' Mofit/Services/PoseDetectionService.swift
grep -F 'func detectPoseDetailed' Mofit/Services/PoseDetectionService.swift
grep -F 'let joints:' Mofit/Services/PoseDetectionService.swift
grep -F 'let lowerBodyAvgConfidence:' Mofit/Services/PoseDetectionService.swift
grep -F 'let hasCompleteSideForSquat:' Mofit/Services/PoseDetectionService.swift
grep -F 'convertToScreenCoordinates' Mofit/Services/PoseDetectionService.swift

# 2) TrackingViewModel — DiagnosticHint enum 정확히 2 case
grep -F 'enum DiagnosticHint' Mofit/ViewModels/TrackingViewModel.swift
test "$(grep -cE '^\s+case (outOfFrame|lowLight)' Mofit/ViewModels/TrackingViewModel.swift)" -eq 2
! grep -E '^\s+case (lowBattery|cameraBlocked|occluded|partialFrame)' Mofit/ViewModels/TrackingViewModel.swift

# 3) TrackingViewModel — private enum Diagnostic 상수 집중
grep -F 'enum Diagnostic' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'graceSeconds' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'sustainSeconds' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'lowLightConfidenceThreshold' Mofit/ViewModels/TrackingViewModel.swift
grep -F '전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)' Mofit/ViewModels/TrackingViewModel.swift
grep -F '조명이 어두울 수 있어요 · 실내 조명을 밝혀주세요' Mofit/ViewModels/TrackingViewModel.swift

# 4) TrackingViewModel — DiagnosticHintEvaluator pure struct + 단일 callsite 가드
grep -F 'struct DiagnosticHintEvaluator' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'func update(now: Date, hasCompleteSideForSquat: Bool, lowerBodyAvgConfidence: Double?, currentReps: Int)' Mofit/ViewModels/TrackingViewModel.swift
test "$(grep -cF 'poseDetectionService.detectPoseDetailed(' Mofit/ViewModels/TrackingViewModel.swift)" -eq 1
! grep -F 'poseDetectionService.detectPose(' Mofit/ViewModels/TrackingViewModel.swift

# 5) TrackingViewModel — processFrame 호출 순서 리터럴 가드
grep -F 'result?.hasCompleteSideForSquat ?? false' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'result?.lowerBodyAvgConfidence' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'currentReps: currentReps' Mofit/ViewModels/TrackingViewModel.swift
! grep -F 'squatCounter?.currentReps' Mofit/ViewModels/TrackingViewModel.swift

# 6) TrackingViewModel — evaluator 호출 지점 가드
test "$(grep -cF 'evaluator.reset()' Mofit/ViewModels/TrackingViewModel.swift)" -eq 1
test "$(grep -cF 'evaluator.startTracking(at:' Mofit/ViewModels/TrackingViewModel.swift)" -eq 1
grep -F '@Published var diagnosticHint: DiagnosticHint?' Mofit/ViewModels/TrackingViewModel.swift

# 7) TrackingView — hintBanner 추가
grep -F 'hintBanner(hint:' Mofit/Views/Tracking/TrackingView.swift
grep -F 'viewModel.diagnosticHint' Mofit/Views/Tracking/TrackingView.swift
grep -F '.padding(.top, 120)' Mofit/Views/Tracking/TrackingView.swift
# View 파일에 카피 리터럴 중복 금지 (단일 소스는 TVM Diagnostic)
! grep -F '전신이 프레임에 들어오는지 확인하세요' Mofit/Views/Tracking/TrackingView.swift
! grep -F '조명이 어두울 수 있어요' Mofit/Views/Tracking/TrackingView.swift

# 8) 신규 파일 금지
test ! -d MofitTests
test ! -f Mofit/Views/Tracking/HintBanner.swift
test ! -f Mofit/ViewModels/DiagnosticHintEvaluator.swift
test ! -f Mofit/Services/PoseFrameResult.swift

# 9) CTO 조건부 #1 — View 레이어 외 Counter/HandDetection 무변경
git diff --quiet HEAD -- Mofit/Services/SquatCounter.swift
git diff --quiet HEAD -- Mofit/Services/PushUpCounter.swift
git diff --quiet HEAD -- Mofit/Services/SitUpCounter.swift
git diff --quiet HEAD -- Mofit/Services/ExerciseCounter.swift
git diff --quiet HEAD -- Mofit/Services/HandDetectionService.swift
git diff --quiet HEAD -- Mofit/Camera/CameraManager.swift
git diff --quiet HEAD -- Mofit/Camera/CameraPreviewView.swift
git diff --quiet HEAD -- Mofit/Views/Home/HomeView.swift

# 10) 변경 범위 — Mofit/ 하위 정확히 3개 파일
CHANGED_MOFIT=$(git diff --name-only HEAD -- Mofit/ | sort)
EXPECTED_MOFIT=$(printf 'Mofit/Services/PoseDetectionService.swift\nMofit/ViewModels/TrackingViewModel.swift\nMofit/Views/Tracking/TrackingView.swift\n' | sort)
test "$CHANGED_MOFIT" = "$EXPECTED_MOFIT"

# 11) 미래 약속 문구 금지
! grep -F "곧 지원" Mofit/ViewModels/TrackingViewModel.swift
! grep -F "로드맵" Mofit/ViewModels/TrackingViewModel.swift
! grep -F "준비중" Mofit/ViewModels/TrackingViewModel.swift
! grep -F "곧 지원" Mofit/Views/Tracking/TrackingView.swift
! grep -F "로드맵" Mofit/Views/Tracking/TrackingView.swift

# 12) xcodegen 재생성 + xcodebuild 빌드 성공
xcodegen generate
xcodebuild \
  -scheme Mofit \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -80

# 13) 외부 디렉토리 미변경
git diff --quiet HEAD -- docs/ README.md project.yml server/ scripts/ iterations/ persuasion-data/ tasks/0-exercise-coming-soon/ tasks/1-coaching-samples/ tasks/2-tap-fallback/ tasks/3-squat-only-pivot/
```

xcodebuild 출력 말미에 `** BUILD SUCCEEDED **` 가 찍혀야 한다.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/4-diagnostic-hint/index.json` 의 phase 1 status 를 `"completed"` 로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"` 로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

xcodebuild 가 디스크/시뮬레이터 런타임 부재 등으로 실패하면, `xcodebuild -showsdks | grep iphonesimulator` 로 SDK 확인 후 `-sdk` 값을 조정하라. 그래도 해결이 안 되면 `-destination 'generic/platform=iOS'` 로 전환 시도. 실패 시 로그 전체를 `error_message` 에 기록.

## 주의사항

- **"세션" 정의 고정**: 세션 = `TrackingView` lifecycle = `startSession()` 최초 호출 ~ `stopSession(...)` 종료. 세트 경계(completeSet → 다음 countdown → tracking) 에서 evaluator.reset() 호출 금지. hintHidden 플래그는 세션 범위로 유지되어야 한다. 새 세트에서 rep 이 0 이 되어도 힌트 재표시 금지(ADR-018 원칙).
- **Evaluator update 6단계 구조 고정**: 상호배타 streak nil 강제(4/5 단계) 누락 시 "outOfFrame → lowLight 전환" 시나리오(6c) 가 깨진다. pseudo-code 의 주석을 그대로 코드에 반영하라.
- **processFrame 호출 순서 5단계 고정**: `processJointsForExercise` → `updateJointPoints` → `evaluator.update` 순서를 바꾸면 같은 frame 에서 rep 증가 직후 힌트가 한 프레임 남는다.
- **`currentReps` 소스 통일**: evaluator 에 `self.currentReps` 만 전달. `squatCounter?.currentReps` 직접 읽기 금지(pushup/situp 경로에서 누락 발생).
- **상수 위치 분리**: UX 정책 상수(grace/sustain/lowLight threshold/카피 2종) 는 TVM `private enum Diagnostic` 에만. Vision raw 필터(0.3) 는 PoseDetectionService 에만. 두 파일 간 cross-ref 주석 유지.
- **DiagnosticHintEvaluator 순수성**: struct 내부에서 `VNHumanBodyPoseObservation`, `CGPoint`, `Combine`, `SwiftUI` 등 타입 참조 금지. 파라미터는 `Bool`, `Double?`, `Int`, `Date` 만.
- **DiagnosticHint 2 case 고정**: `.outOfFrame`, `.lowLight` 만. third case / protocol / 전략 패턴 금지(ADR-018 범위).
- **ConfigService 금지**: 상수 레이어 신규 추가 금지. 이번 스프린트 scope 외.
- **신규 `.swift` 파일 금지**: `HintBanner.swift`, `DiagnosticHintEvaluator.swift`, `PoseFrameResult.swift` 등 분리 금지.
- **MofitTests 타겟 신설 금지**: project.yml 수정 금지. 단위 테스트는 § 구현 후 코드 트레이스 검증 6개 시나리오로 갈음.
- **ADR-013, ADR-014, ADR-017 위반 금지**: 서버 API 호출 추가, 로그인 분기 변경, 스쿼트 외 운동 UI 노출 금지.
- **미래 약속 문구 금지**: 주석·리터럴·카피 어디에도 "곧 지원", "로드맵", "출시 예정", "차기 버전", "준비중" 금지.
- **Analytics 이벤트 추가 금지**: `AnalyticsService.swift` 불변. 힌트 노출 이벤트 추가 금지.
- **git status 클린 상태 시작**: dirty 면 error 기록 후 중단.
- **hintBanner padding.top=120 고정**: 그 이하로 내리지 마라(info bar 와 겹침). 그 이상은 허용이나 기본값 유지.
- **카피 리터럴 복제 금지**: TrackingView.swift 에 "전신이 프레임에 들어오는지..." / "조명이 어두울 수 있어요..." 리터럴을 추가하지 마라. 단일 소스는 TVM `Diagnostic` enum + DiagnosticHint.message computed 경유.
- **기존 테스트를 깨뜨리지 마라**: (현재 `MofitTests` 없음. 서버 쪽 Node 테스트는 서버 미변경이라 무관.)
- **실기기 QA 는 AC 범위 밖**: docs/user-intervention.md 절차대로 사람이 merge 전 수행. phase 1 완료 조건은 xcodebuild 성공 + grep 가드 통과.
- **컴파일러 경고 발생 시 즉시 해결**: 미사용 import, 미사용 변수 등. AC 빌드는 경고가 있어도 성공 표기되지만, 이번 phase 변경 scope 안에서 cleanup 포함.
