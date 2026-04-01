# Phase 1: SwiftData 모델

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/data-schema.md`
- `/docs/prd.md`
- `/docs/adr.md` (특히 ADR-002, ADR-003)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Mofit/App/MofitApp.swift`
- `Mofit/Utils/Theme.swift`
- `project.yml`

## 작업 내용

### 1. UserProfile.swift

`Mofit/Models/UserProfile.swift` 생성:

```swift
@Model
class UserProfile {
    var gender: String          // "male" | "female"
    var height: Double          // cm
    var weight: Double          // kg
    var bodyType: String        // "slim" | "normal" | "muscular" | "chubby"
    var goal: String            // "weightLoss" | "strength" | "bodyShape"
    var onboardingCompleted: Bool
}
```

- 싱글톤 패턴: 앱 전체에서 1개만 존재. init에 기본값을 설정하라.
- `onboardingCompleted`의 기본값은 `false`.

### 2. WorkoutSession.swift

`Mofit/Models/WorkoutSession.swift` 생성:

```swift
@Model
class WorkoutSession {
    var id: UUID
    var exerciseType: String    // "squat"
    var startedAt: Date
    var endedAt: Date
    var totalDuration: Int      // 초
    var repCounts: [Int]        // 세트별 rep. [12, 10, 8] = 3세트
}
```

- `repCounts`는 `[Int]` 배열. 별도 WorkoutSet 모델 없음 (ADR-003).
- `세트 수 = repCounts.count`, `총 rep = repCounts.reduce(0, +)`
- 편의 computed property를 추가하라: `var totalSets: Int`, `var totalReps: Int`

### 3. CoachingFeedback.swift

`Mofit/Models/CoachingFeedback.swift` 생성:

```swift
@Model
class CoachingFeedback {
    var id: UUID
    var date: Date              // 날짜 (하루 2회 제한 체크용)
    var type: String            // "pre" | "post"
    var content: String         // AI 응답 전문
    var createdAt: Date
}
```

### 4. MofitApp.swift 업데이트

`MofitApp.swift`에 SwiftData modelContainer를 추가하라:

```swift
.modelContainer(for: [UserProfile.self, WorkoutSession.self, CoachingFeedback.self])
```

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

**BUILD SUCCEEDED** 출력 확인.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 1 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- SwiftData `@Model` 매크로를 사용하라. Core Data 코드를 작성하지 마라.
- `import SwiftData`를 잊지 마라.
- `repCounts`의 타입은 `[Int]`다. SwiftData는 Codable 배열을 기본 지원한다. Transformable 등의 별도 처리 불필요.
- 이 phase에서 View나 ViewModel 코드를 작성하지 마라. 모델만 작성한다.
