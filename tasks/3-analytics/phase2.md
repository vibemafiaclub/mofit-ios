# Phase 2: event-instrumentation

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/adr.md` (특히 ADR-015: Mixpanel 채택)
- `/docs/code-architecture.md`
- `/docs/flow.md` (유저 플로우 이해)
- `/tasks/3-analytics/docs-diff.md` (이번 task의 문서 변경 기록)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `/Mofit/Services/AnalyticsService.swift` — Phase 1에서 생성한 서비스. `AnalyticsEvent` enum과 `track()` 메서드 시그니처를 확인하라.
- `/Mofit/App/MofitApp.swift` — initialize() 호출 위치 확인.
- `/Mofit/Services/AuthManager.swift` — identify/reset 호출 위치 확인.

그리고 이벤트를 삽입할 기존 파일들을 반드시 읽어라:

- `/Mofit/Views/Onboarding/OnboardingView.swift`
- `/Mofit/Views/Auth/LoginView.swift`
- `/Mofit/Views/Auth/SignUpView.swift`
- `/Mofit/ViewModels/TrackingViewModel.swift`
- `/Mofit/Views/Tracking/TrackingView.swift`
- `/Mofit/ViewModels/CoachingViewModel.swift`
- `/Mofit/Views/Home/HomeView.swift`
- `/Mofit/Views/Records/RecordsView.swift`
- `/Mofit/Views/Coaching/CoachingView.swift`
- `/Mofit/Views/Profile/ProfileEditView.swift`

## 작업 내용

Phase 1에서 구축한 AnalyticsService를 사용하여, 기존 View와 ViewModel에 이벤트 추적 호출을 삽입한다. 총 10개 이벤트를 삽입한다.

### 이벤트 삽입 상세

#### 1. `onboarding_started`
- **위치**: `OnboardingView`의 `.onAppear` 수정자 추가 (최상위 body에)
- **코드**: `AnalyticsService.shared.track(.onboardingStarted)`
- **properties**: 없음

#### 2. `onboarding_completed`
- **위치**: `OnboardingView`에서 온보딩이 완료되는 시점. `onboardingCompleted = true`가 설정되는 곳을 찾아서 그 직전에 삽입.
- **코드**: `AnalyticsService.shared.track(.onboardingCompleted)`
- **properties**: 없음

#### 3. `sign_up`
- **위치**: `SignUpView`에서 `authManager.signup()` 호출이 성공한 직후 (do 블록 안, try await 성공 후).
- **코드**: `AnalyticsService.shared.track(.signUp)`
- **properties**: 없음
- **주의**: AuthManager에서 이미 identify()를 호출하므로 여기서는 track만 한다.

#### 4. `login`
- **위치**: `LoginView`에서 `authManager.login()` 호출이 성공한 직후 (do 블록 안, try await 성공 후).
- **코드**: `AnalyticsService.shared.track(.login)`
- **properties**: 없음

#### 5. `workout_started`
- **위치**: `TrackingViewModel`의 `startCountdown()` 메서드에서, 최초 호출 시에만 (elapsed timer가 시작되는 분기, `hasStartedElapsedTimer` 체크 부분). 이미 `hasStartedElapsedTimer`로 최초 1회만 실행되는 블록이 있을 것이다. 그 안에 삽입.
- **코드**: `AnalyticsService.shared.track(.workoutStarted, properties: ["exercise_type": exerciseType])`
- **properties**: `exercise_type` (String)

#### 6. `workout_completed`
- **위치**: `TrackingViewModel`의 `stopSession()` 메서드에서, 세션 저장 로직 직전. 단, `repCounts`의 합계가 1 이상일 때만.
- **코드**:
```swift
let totalReps = repCounts.reduce(0, +)
if totalReps > 0 {
    AnalyticsService.shared.track(.workoutCompleted, properties: [
        "exercise_type": exerciseType,
        "total_reps": totalReps,
        "duration_seconds": elapsedTime,
        "set_count": repCounts.count
    ])
}
```
- **핵심 규칙**: `totalReps > 0`일 때만 completed. 0이면 cancelled.

#### 7. `workout_cancelled`
- **위치**: `TrackingViewModel`의 `stopSession()` 메서드에서, `repCounts`의 합계가 0일 때.
- **코드**:
```swift
let totalReps = repCounts.reduce(0, +)
if totalReps == 0 {
    AnalyticsService.shared.track(.workoutCancelled, properties: [
        "exercise_type": exerciseType,
        "elapsed_seconds": elapsedTime
    ])
}
```
- **핵심 규칙**: completed와 cancelled는 상호 배타적이다. 하나의 stopSession 호출에서 둘 중 하나만 발생해야 한다.

#### 8. `coaching_requested`
- **위치**: `CoachingViewModel`에서 코칭 요청을 시작하는 메서드들 (`requestFeedback` 및 `requestFeedbackFromServer`). 각 메서드의 시작 부분에 삽입.
- **코드**: `AnalyticsService.shared.track(.coachingRequested, properties: ["type": type])`
- **properties**: `type` (String, "pre" 또는 "post")

#### 9. `coaching_received`
- **위치**: `CoachingViewModel`에서 코칭 응답을 성공적으로 받은 직후 (Claude 응답 파싱 완료 후, SwiftData/서버 저장 직전).
- **코드**: `AnalyticsService.shared.track(.coachingReceived, properties: ["type": type])`
- **properties**: `type` (String)

#### 10. `screen_viewed`
- **위치**: 아래 7개 View의 최상위 body에 `.onAppear` 수정자를 추가 (이미 .onAppear가 있다면 기존 클로저 안에 추가):
  - `HomeView` → `"home"`
  - `RecordsView` → `"records"`
  - `CoachingView` → `"coaching"`
  - `TrackingView` → `"tracking"`
  - `OnboardingView` → `"onboarding"` (onboarding_started와 같은 .onAppear에 함께)
  - `LoginView` → `"login"`
  - `SignUpView` → `"sign_up"`
  - `ProfileEditView` → `"profile_edit"`
- **코드**: `AnalyticsService.shared.track(.screenViewed, properties: ["screen_name": "<화면이름>"])`

### 삽입 원칙

1. 각 이벤트 호출은 1~3줄이다. 기존 로직을 변경하지 말고, 적절한 위치에 한 줄 추가만 하라.
2. `import` 문은 필요 없다. AnalyticsService는 같은 모듈 내 클래스이므로 별도 import 불필요.
3. 이벤트 호출이 실패해도 앱 기능에 영향을 주면 안 된다. Mixpanel SDK는 내부적으로 에러를 흡수하므로 try/catch 불필요.
4. properties의 값은 Mixpanel의 `MixpanelType` 프로토콜을 준수해야 한다. String, Int, Double 등 기본 타입은 자동 준수.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Xcode 빌드가 에러 없이 성공해야 한다. (`** BUILD SUCCEEDED **` 출력)

추가 검증:

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && grep -r "AnalyticsService.shared.track" Mofit/ | wc -l
```

최소 12개 이상의 track 호출이 존재해야 한다 (10개 이벤트 + coaching의 2경로 분기 + screen_viewed 8개 = 약 20개).

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/3-analytics/index.json`의 phase 2 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 기존 로직을 변경하지 마라. 이벤트 추적 호출을 추가하는 것만 한다.
- workout_completed와 workout_cancelled는 상호 배타적이다. stopSession 내에서 totalReps로 분기하여 둘 중 하나만 발생해야 한다.
- `.onAppear`가 이미 있는 View에는 기존 클로저 안에 track 호출을 추가하라. 새로운 `.onAppear`를 중복으로 달지 마라 (SwiftUI에서 같은 View에 여러 .onAppear는 동작하지만, 가독성을 위해 하나로 합쳐라).
- AnalyticsService.swift의 코드를 수정하지 마라. Phase 1에서 만든 인터페이스를 그대로 사용하라.
- 기존 테스트를 깨뜨리지 마라.
