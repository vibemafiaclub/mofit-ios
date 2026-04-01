# Phase 8: 통합 + 다듬기

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md` (전체)
- `/docs/flow.md` (전체)
- `/docs/code-architecture.md` (전체)

그리고 이전 모든 phase의 작업물을 반드시 확인하라:

- `Mofit/App/MofitApp.swift`
- `Mofit/App/ContentView.swift`
- `Mofit/Views/Onboarding/OnboardingView.swift`
- `Mofit/Views/Home/HomeView.swift`
- `Mofit/Views/Home/ExercisePickerView.swift`
- `Mofit/Views/Tracking/TrackingView.swift`
- `Mofit/Views/Records/RecordsView.swift`
- `Mofit/Views/Coaching/CoachingView.swift`
- `Mofit/Views/Profile/ProfileEditView.swift`
- `Mofit/ViewModels/TrackingViewModel.swift`
- `Mofit/ViewModels/CoachingViewModel.swift`
- `Mofit/Services/` 전체
- `Mofit/Camera/` 전체
- `Mofit/Utils/Theme.swift`

모든 파일을 꼼꼼히 읽고, 전체 앱의 흐름이 문서와 일치하는지 점검하라.

## 작업 내용

이 phase는 전체 앱을 통합 점검하고 누락/불일치를 수정하는 단계다. 새로운 기능을 추가하지 않는다.

### 1. 네비게이션 흐름 점검

아래 흐름이 코드에서 올바르게 연결되어 있는지 확인하고, 안 되어 있으면 수정:

- **최초 실행**: MofitApp → onboardingCompleted 체크 → OnboardingView 또는 ContentView
- **온보딩 완료**: OnboardingView → UserProfile 저장 → ContentView로 전환
- **운동 시작**: HomeView → 운동 시작 버튼 → TrackingView (fullScreenCover)
- **운동 종료**: TrackingView → 종료 버튼 → WorkoutSession 저장 → dismiss → HomeView (폭죽 효과)
- **프로필 수정**: HomeView → 프로필 버튼 → ProfileEditView (fullScreenCover) → 저장 → dismiss
- **운동 선택**: HomeView → 운동 영역 탭 → ExercisePickerView (sheet) → 선택 → dismiss
- **탭 전환**: ContentView TabView → 홈/기록/AI코칭

### 2. 다크모드 고정 점검

- Info.plist (project.yml)에서 `UIUserInterfaceStyle: Dark` 설정 확인
- 모든 View에서 다크 배경이 올바르게 적용되는지 확인
- 텍스트 색상이 흰색/회색 계열인지 확인

### 3. Theme 일관성 점검

- `Theme.neonGreen`이 올바르게 사용되는 곳:
  - 운동 시작 버튼 배경
  - 탭바 선택 색상
  - 날짜바 선택 날짜
  - 카운트다운 숫자
  - rep 수 표시
  - 관절 포인트
- 무채색이 올바르게 사용되는 곳: 그 외 모든 UI

### 4. 데이터 플로우 점검

- SwiftData modelContainer가 MofitApp에서 올바르게 설정되어 있는지
- 각 View에서 `@Environment(\.modelContext)` 또는 `@Query`가 올바르게 사용되는지
- UserProfile, WorkoutSession, CoachingFeedback의 CRUD가 올바르게 동작하는 코드인지

### 5. 폭죽 효과 연결 점검

- TrackingView 종료 → HomeView 복귀 시 폭죽 효과가 트리거되는지 확인
- 폭죽 효과가 일정 시간 후 자동으로 사라지는지 확인

### 6. 컴파일 오류 수정

- 전체 빌드를 실행하고, 발견되는 모든 컴파일 오류를 수정

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

**BUILD SUCCEEDED** 출력 확인.

추가로 아래 확인:
```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && grep -r "Secrets.claudeAPIKey" Mofit/ --include="*.swift" | grep -v "Secrets.swift" | grep -v "Secrets.example.swift" | head -5
```
ClaudeAPIService.swift에서만 Secrets를 참조하는지 확인 (다른 파일에서 API key를 하드코딩하지 않았는지).

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 8 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- **새로운 기능을 추가하지 마라.** 이 phase는 통합 점검과 버그 수정만 한다.
- 기존 코드의 로직이 문서와 일치하면 수정하지 마라. 불일치하는 경우에만 수정.
- 코드 스타일 통일, 불필요한 import 제거 등 사소한 정리는 해도 된다.
- 대규모 리팩토링을 하지 마라.
