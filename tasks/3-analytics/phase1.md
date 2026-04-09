# Phase 1: sdk-setup

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/adr.md` (특히 ADR-015: Mixpanel 채택)
- `/docs/code-architecture.md`
- `/tasks/3-analytics/docs-diff.md` (이번 task의 문서 변경 기록)

그리고 아래 파일들을 반드시 확인하라:

- `/project.yml` — XcodeGen 프로젝트 설정. 현재 SPM packages 섹션이 없음.
- `/Mofit/App/MofitApp.swift` — 앱 엔트리포인트. 여기서 AnalyticsService를 초기화해야 함.
- `/Mofit/Config/Secrets.swift` — API 키 관리 패턴 확인.
- `/Mofit/Config/Secrets.example.swift` — 템플릿 파일. mixpanelToken 추가 필요.
- `/Mofit/Services/AuthManager.swift` — 로그인/로그아웃 시 identify/reset 호출 위치 확인.

## 작업 내용

Mixpanel iOS SDK를 프로젝트에 통합하고, AnalyticsService를 구현한다.

### 1. `/project.yml` 수정 — SPM 패키지 추가

`packages` 섹션을 최상위에 추가하고, Mofit 타겟의 dependencies에 Mixpanel을 추가한다:

```yaml
packages:
  Mixpanel:
    url: https://github.com/mixpanel/mixpanel-swift
    from: "4.3.0"
```

그리고 targets.Mofit.dependencies에 추가:

```yaml
dependencies:
  - sdk: SwiftUI.framework
  - sdk: SwiftData.framework
  - sdk: AVFoundation.framework
  - sdk: Vision.framework
  - sdk: Security.framework
  - package: Mixpanel
```

### 2. `/Mofit/Config/Secrets.swift` 및 `/Mofit/Config/Secrets.example.swift` 수정

기존 `claudeAPIKey` 아래에 `mixpanelToken`을 추가:

```swift
enum Secrets {
    static let claudeAPIKey = "..."
    static let mixpanelToken = "YOUR_MIXPANEL_TOKEN_HERE"
}
```

실제 `Secrets.swift`의 mixpanelToken 값은 `"2c699af753e40e498e7a2c7bfff93f15"` 를 사용하라.

### 3. `/Mofit/Services/AnalyticsService.swift` 생성

Mixpanel SDK를 감싸는 싱글톤 서비스를 생성한다. 기존 서비스 패턴(APIService.shared 등)과 동일한 스타일로 작성하라.

```swift
import Foundation
import Mixpanel

enum AnalyticsEvent: String {
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case signUp = "sign_up"
    case login = "login"
    case workoutStarted = "workout_started"
    case workoutCompleted = "workout_completed"
    case workoutCancelled = "workout_cancelled"
    case coachingRequested = "coaching_requested"
    case coachingReceived = "coaching_received"
    case screenViewed = "screen_viewed"
}

final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    func initialize() {
        // Mixpanel.initialize(token:trackAutomaticEvents:) 호출
        // token은 Secrets.mixpanelToken 사용
        // trackAutomaticEvents: true
    }

    func track(_ event: AnalyticsEvent, properties: Properties? = nil) {
        // Mixpanel.mainInstance().track(event:properties:) 호출
    }

    func identify(userId: String) {
        // Mixpanel.mainInstance().identify(distinctId:) 호출
    }

    func reset() {
        // Mixpanel.mainInstance().reset() 호출
        // 로그아웃 시 anonymous ID로 복귀
    }
}
```

`Properties`는 Mixpanel SDK에서 제공하는 `[String: MixpanelType]` 타입 별칭이다.

### 4. `/Mofit/App/MofitApp.swift` 수정

`init()` 메서드에서 ModelContainer 초기화 직후 `AnalyticsService.shared.initialize()` 를 호출한다:

```swift
init() {
    let container = try! ModelContainer(for: UserProfile.self, WorkoutSession.self, CoachingFeedback.self)
    self.modelContainer = container
    AnalyticsService.shared.initialize()
}
```

### 5. `/Mofit/Services/AuthManager.swift` 수정

- `signup()` 메서드: `isLoggedIn = true` 설정 직후, `AnalyticsService.shared.identify(userId: authResponse.user.id)` 호출.
- `login()` 메서드: `isLoggedIn = true` 설정 직후, `AnalyticsService.shared.identify(userId: authResponse.user.id)` 호출.
- `logout()` 메서드: `isLoggedIn = false` 설정 직후, `AnalyticsService.shared.reset()` 호출.

이 phase에서는 identify/reset만 추가한다. 이벤트 추적(sign_up, login)은 Phase 2에서 한다.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Xcode 빌드가 에러 없이 성공해야 한다. (`** BUILD SUCCEEDED **` 출력)

## AC 검증 방법

위 AC 커맨드를 실행하라. 빌드가 성공하면 `/tasks/3-analytics/index.json`의 phase 1 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 이 phase에서는 이벤트 추적 호출(track)을 추가하지 마라. SDK 초기화와 identify/reset만 구현한다.
- 기존 View 파일들을 수정하지 마라.
- `xcodegen generate`를 반드시 실행하여 project.yml 변경을 Xcode 프로젝트에 반영하라.
- Mixpanel SPM 패키지 resolve에 시간이 걸릴 수 있다. 빌드 전에 패키지가 정상 resolve되었는지 확인하라.
- 기존 테스트를 깨뜨리지 마라.
