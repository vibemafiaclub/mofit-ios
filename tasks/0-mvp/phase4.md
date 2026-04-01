# Phase 4: 카메라 + Vision 서비스

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/code-architecture.md` (카메라 파이프라인, 스쿼트 판정, 손바닥 판정 섹션)
- `/docs/adr.md` (ADR-001: Apple Vision, ADR-004: 15fps 샘플링)
- `/docs/prd.md` (트래킹 화면 섹션)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Mofit/App/MofitApp.swift`
- `Mofit/Models/WorkoutSession.swift`
- `Mofit/Utils/Theme.swift`
- `project.yml` (카메라 권한 설정 확인)

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

### 1. CameraManager.swift

`Mofit/Camera/CameraManager.swift`:

AVCaptureSession을 관리하는 클래스. `ObservableObject` 프로토콜 채택.

**핵심 기능:**
- 전면 카메라(`.front`) 설정
- `AVCaptureVideoDataOutput` 추가, delegate로 CMSampleBuffer 수신
- 세션 시작/정지 메서드
- 15fps 샘플링: 매 프레임이 아닌 약 15fps로만 delegate에 전달 (마지막 처리 시간 기록 → 66ms 미만이면 skip)
- `AVCaptureVideoPreviewLayer`를 외부에 노출 (CameraPreviewView에서 사용)

**인터페이스 (참고용):**
```swift
class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    var onFrameCaptured: ((CMSampleBuffer) -> Void)?
    
    func startSession()
    func stopSession()
}
```

- `onFrameCaptured` 클로저를 통해 Vision 분석으로 프레임 전달.
- 카메라 세션 설정은 백그라운드 큐에서 수행하라.

### 2. CameraPreviewView.swift

`Mofit/Camera/CameraPreviewView.swift`:

`UIViewRepresentable`로 `AVCaptureVideoPreviewLayer`를 SwiftUI에서 표시.

- `CameraManager`의 `captureSession`을 받아 preview layer 생성
- `videoGravity`: `.resizeAspectFill` (전체화면)
- 전면 카메라이므로 미러링 자동 적용됨

### 3. PoseDetectionService.swift

`Mofit/Services/PoseDetectionService.swift`:

Apple Vision의 `VNDetectHumanBodyPoseRequest`를 래핑.

**핵심 기능:**
- `CMSampleBuffer`를 받아 body pose 감지 수행
- 감지된 관절 포인트들을 반환 (특히 hip, knee, ankle)
- 관절 포인트를 화면 좌표로 변환하는 유틸리티

**인터페이스 (참고용):**
```swift
class PoseDetectionService {
    func detectPose(in sampleBuffer: CMSampleBuffer) -> [VNHumanBodyPoseObservation.JointName: CGPoint]?
}
```

- 반환 좌표는 Vision의 정규화 좌표(0~1). 화면 좌표 변환은 호출 측에서 수행.
- 전면 카메라의 좌우 반전을 고려하라.

### 4. HandDetectionService.swift

`Mofit/Services/HandDetectionService.swift`:

Apple Vision의 `VNDetectHumanHandPoseRequest`를 래핑.

**핵심 기능:**
- `CMSampleBuffer`를 받아 hand pose 감지 수행
- **손바닥 판정 로직**: 5개 손가락의 tip 관절이 모두 펴져 있으면 `true`
  - 각 손가락의 tip과 pip(또는 mcp) 사이의 거리/각도로 "펴짐" 판정
  - 모든 5개 손가락이 펴져있으면 = 손바닥

**인터페이스 (참고용):**
```swift
class HandDetectionService {
    func detectOpenPalm(in sampleBuffer: CMSampleBuffer) -> Bool
}
```

### 5. SquatCounter.swift

`Mofit/Services/SquatCounter.swift`:

관절 각도를 계산하여 스쿼트 rep을 카운팅.

**핵심 로직:**
- hip, knee, ankle 세 관절의 각도 계산 (양쪽 다리 중 감지되는 쪽 사용)
- 상태 머신:
  - `standing`: 각도 > 160°
  - `squatting`: 각도 < 100°
  - `standing → squatting → standing` = 1 rep
- 현재 rep 수를 외부에 노출

**인터페이스 (참고용):**
```swift
class SquatCounter: ObservableObject {
    @Published var currentReps: Int = 0
    
    func processJoints(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint])
    func reset()
}
```

**각도 계산:**
세 점 A(hip), B(knee), C(ankle)에서 B를 꼭짓점으로 하는 각도:
```
angle = atan2(C.y - B.y, C.x - B.x) - atan2(A.y - B.y, A.x - B.x)
```
결과를 degree로 변환하고 0~360 범위로 정규화.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

**BUILD SUCCEEDED** 출력 확인.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 4 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 이 phase에서는 서비스 레이어만 구현한다. TrackingView나 TrackingViewModel을 작성하지 마라.
- `import AVFoundation`, `import Vision`을 사용하라.
- 카메라/Vision 코드는 시뮬레이터에서 런타임 테스트가 불가능하다. 컴파일 통과만 검증한다. 런타임 오류는 실기기에서 확인.
- CameraManager에서 15fps 샘플링은 타이머가 아닌 프레임 간 시간 차이 기반으로 구현하라. `CACurrentMediaTime()` 사용.
- 전면 카메라의 좌우 반전을 고려하되, `AVCaptureVideoPreviewLayer`는 자동 미러링하므로 관절 오버레이 좌표만 반전 처리하면 된다.
- 손바닥 판정에서 "모든 5개 손가락이 펴짐"의 기준을 너무 엄격하게 잡지 마라. confidence threshold를 적절히 설정하여 자연스러운 손바닥 제스처를 인식하도록.
