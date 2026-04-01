# Phase 5: 트래킹 화면

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md` (트래킹 화면 섹션)
- `/docs/flow.md` (운동 흐름 — 트래킹 상태 머신)
- `/docs/code-architecture.md` (트래킹 상태 머신, 화면 자동 잠금)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Mofit/Camera/CameraManager.swift`
- `Mofit/Camera/CameraPreviewView.swift`
- `Mofit/Services/PoseDetectionService.swift`
- `Mofit/Services/HandDetectionService.swift`
- `Mofit/Services/SquatCounter.swift`
- `Mofit/Models/WorkoutSession.swift`
- `Mofit/Views/Home/HomeView.swift` (트래킹 화면으로의 네비게이션 연결 확인)
- `Mofit/Utils/Theme.swift`

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라. 특히 CameraManager, PoseDetectionService, HandDetectionService, SquatCounter의 인터페이스를 정확히 파악하라.

## 작업 내용

### 1. TrackingViewModel.swift

`Mofit/ViewModels/TrackingViewModel.swift`:

트래킹 화면의 모든 비즈니스 로직을 관리하는 ViewModel. `ObservableObject` 채택.

**상태 머신:**
```
enum TrackingState {
    case idle           // "손바닥을 보여주세요" 대기
    case countdown(Int) // 카운트다운 (5, 4, 3, 2, 1)
    case tracking       // 운동 추적 중 (관절 표시 + rep 카운팅)
    case setComplete    // "세트 N 완료!" 잠깐 표시 후 → countdown
}
```

**Published 프로퍼티:**
- `state: TrackingState` — 현재 상태
- `currentSet: Int` — 현재 세트 번호 (1부터 시작)
- `currentReps: Int` — 현재 세트의 rep 수
- `elapsedTime: Int` — 경과 시간 (초)
- `jointPoints: [CGPoint]` — 화면에 표시할 관절 좌표들
- `repCounts: [Int]` — 완료된 세트별 rep 배열

**핵심 로직:**

1. `startSession()`: CameraManager 시작 + 상태를 `.idle`로 설정
2. CameraManager의 `onFrameCaptured`에서:
   - HandDetectionService로 손바닥 감지. 1초간 연속 감지 시:
     - `.idle` → `.countdown(5)` 시작
     - `.tracking` → 현재 세트 rep을 `repCounts`에 추가 → `.setComplete` → 1초 후 `.countdown(5)`
   - `.tracking` 상태에서만: PoseDetectionService로 관절 감지 → SquatCounter에 전달 → rep 업데이트 + 관절 좌표 업데이트
3. 카운트다운: Timer로 매초 감소, 0 도달 시 `.tracking`으로 전환
4. 경과 시간: 첫 카운트다운 시작 시점부터 Timer로 매초 증가
5. `stopSession()`: 카메라 정지. 현재 세트의 rep이 0보다 크면 `repCounts`에 추가. WorkoutSession 생성 + SwiftData 저장. 경과 시간을 `totalDuration`으로 기록.

**손바닥 1초 연속 감지 로직:**
- 손바닥이 감지된 첫 시점 기록
- 이후 프레임에서도 계속 감지되면 시간 누적
- 1초 이상 누적 시 트리거
- 감지 끊기면 리셋

### 2. TrackingView.swift

`Mofit/Views/Tracking/TrackingView.swift`:

전체화면 카메라 프리뷰 위에 상태별 오버레이를 표시.

**레이아웃:**
- 전체 화면: `CameraPreviewView` (배경)
- 오버레이 (ZStack):

**상태별 오버레이:**

**`.idle`:**
- 화면 중앙: "손바닥을 보여주세요" 텍스트 (크게, 반투명 배경)
- 하단 중앙: 빨간 원형 종료 버튼

**`.countdown(let seconds)`:**
- 화면 중앙: 카운트다운 숫자 (매우 크게, 형광초록)
- 하단 중앙: 빨간 원형 종료 버튼

**`.tracking`:**
- 좌상단: "세트 {N}" 텍스트
- 우상단: 경과 시간 (MM:SS 형식)
- 중앙: 현재 rep 수 (매우 크게, 형광초록, 볼드)
- 관절 포인트: `jointPoints`를 화면 좌표로 변환하여 작은 원으로 표시 (형광초록)
- 하단 중앙: 빨간 원형 종료 버튼

**`.setComplete`:**
- 화면 중앙: "세트 {N} 완료!" 텍스트 (크게)
- 잠시 후 자동으로 카운트다운으로 전환 (ViewModel이 처리)

**종료 버튼:**
- 빨간색 원형 버튼 (SF Symbol: `stop.fill`)
- 탭 시: ViewModel의 `stopSession()` 호출 → dismiss (홈으로 복귀)
- 홈으로 복귀 시 폭죽 효과 트리거 (HomeView의 `showConfetti` 바인딩 또는 환경값)

**화면 자동 잠금 방지:**
- `.onAppear`: `UIApplication.shared.isIdleTimerDisabled = true`
- `.onDisappear`: `UIApplication.shared.isIdleTimerDisabled = false`

### 3. HomeView 연결 업데이트

Phase 3에서 만든 HomeView의 placeholder 트래킹 화면을 실제 `TrackingView`로 교체하라. `fullScreenCover`로 표시. 운동 종료 후 홈 복귀 시 `showConfetti = true`가 되도록 연결.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

**BUILD SUCCEEDED** 출력 확인.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 5 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- TrackingViewModel은 Phase 4에서 만든 서비스들(CameraManager, PoseDetectionService, HandDetectionService, SquatCounter)을 조합한다. 서비스의 인터페이스를 변경하지 마라. 필요시 최소한의 수정만 허용.
- 관절 좌표 변환: Vision의 정규화 좌표(0~1, 원점 좌하단)를 SwiftUI 화면 좌표(원점 좌상단)로 변환해야 한다. y좌표 반전 + 화면 크기 곱셈.
- 전면 카메라의 미러링: CameraPreviewView가 자동 미러링하므로, 관절 오버레이 좌표도 x좌표를 반전(1-x)해야 프리뷰와 일치한다.
- 종료 버튼을 누르면 바로 종료한다. 확인 다이얼로그 없음.
- 카운트다운 타이머와 경과 시간 타이머가 동시에 돌 수 있다. Timer 관리에 주의.
- SwiftData의 modelContext는 @Environment로 주입받아 ViewModel에 전달하라.
