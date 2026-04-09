# Phase 7: ios-integration

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/data-schema.md`
- `/docs/adr.md`
- `/docs/code-architecture.md`
- `/docs/flow.md`
- `/tasks/2-auth/docs-diff.md` (이번 task의 문서 변경 기록)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `/Mofit/Services/AuthManager.swift` — 로그인 상태 관리
- `/Mofit/Services/APIService.swift` — 서버 통신
- `/Mofit/Views/Auth/LoginView.swift` — 로그인 화면
- `/Mofit/Views/Auth/SignUpView.swift` — 회원가입 화면
- `/Mofit/Views/Coaching/CoachingView.swift` — 비로그인 안내 추가된 코칭 뷰
- `/Mofit/Views/Profile/ProfileEditView.swift` — 로그아웃 추가된 프로필 편집 뷰

현재 iOS 프로젝트의 모든 뷰와 뷰모델을 읽어라:

- `/Mofit/Views/Home/HomeView.swift`
- `/Mofit/Views/Records/RecordsView.swift`
- `/Mofit/Views/Tracking/TrackingView.swift`
- `/Mofit/ViewModels/TrackingViewModel.swift`
- `/Mofit/ViewModels/CoachingViewModel.swift`
- `/Mofit/Services/ClaudeAPIService.swift`

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

기존 뷰들을 수정하여 로그인 상태에 따라 데이터 소스를 분기한다.

핵심 원칙:
- **비로그인**: 기존 SwiftData 사용 (변경 없음)
- **로그인**: 서버 API 사용 (APIService 호출)

### 1. HomeView 수정

`/Mofit/Views/Home/HomeView.swift`:

- `@EnvironmentObject var authManager: AuthManager`를 추가
- 오늘의 기록 (todaySessions) 데이터 소스 분기:
  - **비로그인**: 기존 `@Query private var sessions: [WorkoutSession]` 사용
  - **로그인**: `APIService.shared.getSessions(date: Date())` 호출하여 서버에서 조회
- 로그인 시 서버 데이터를 `@State`로 관리:
  - `@State private var serverSessions: [ServerSession] = []`
  - `.onAppear`와 `.task`에서 로그인 상태이면 서버 데이터 fetch
- `todaySessions` computed property를 분기:
  - 비로그인: 기존 SwiftData Query 결과 사용
  - 로그인: `serverSessions`를 사용하여 동일한 계산 수행

### 2. RecordsView 수정

`/Mofit/Views/Records/RecordsView.swift`:

- `@EnvironmentObject var authManager: AuthManager`를 추가
- 날짜별 세션 조회 분기:
  - **비로그인**: 기존 `@Query` + 필터링
  - **로그인**: `APIService.shared.getSessions(date: selectedDate)` 호출
- 날짜 변경 시 (`selectedDate` 변경) 서버 데이터 재조회
- 스와이프 삭제도 분기:
  - **비로그인**: `modelContext.delete(session)`
  - **로그인**: `APIService.shared.deleteSession(id: session.id)` 후 로컬 상태에서 제거

### 3. CoachingView 수정

`/Mofit/Views/Coaching/CoachingView.swift`:

Phase 6에서 비로그인 안내 화면은 이미 추가됨. 이 phase에서는 로그인 시 데이터 소스를 서버로 전환:

- 피드백 목록 조회:
  - **비로그인**: 이 화면에 접근 불가 (Phase 6에서 안내 화면 표시)
  - **로그인**: `APIService.shared.getFeedbacks()` 호출하여 서버에서 조회
- 기존 `@Query` 어노테이션은 유지하되, 로그인 시에는 사용하지 않음
- 서버 피드백을 `@State private var serverFeedbacks: [ServerFeedback] = []`로 관리

### 4. CoachingViewModel 수정

`/Mofit/ViewModels/CoachingViewModel.swift`:

- `requestFeedback()` 메서드 분기:
  - **비로그인**: 이 경우 호출되지 않음 (CoachingView가 안내 화면 표시)
  - **로그인**: `APIService.shared.requestCoaching(prompt: prompt, type: type)` 호출
- 기존 `ClaudeAPIService` 직접 호출 코드는 로그인 시 사용하지 않음
- 프롬프트 빌드 로직(`buildPrompt`)은 그대로 유지. 프롬프트는 앱에서 구성하고 서버로 전달.

### 5. TrackingViewModel 수정

`/Mofit/ViewModels/TrackingViewModel.swift`:

- `stopSession()` 메서드에 로그인 상태 분기 추가:
  - **비로그인**: 기존 `modelContext.insert(session)` (SwiftData 로컬 저장)
  - **로그인**: `APIService.shared.createSession(session)` 호출 (서버 저장)
- AuthManager를 주입받아야 함. init 파라미터로 받거나, stopSession에 isLoggedIn 파라미터 추가.
- 서버 저장 실패 시: 에러 알림만 표시 (alert). 로컬 임시 저장 없음 (ADR-014).

### 6. TrackingView 수정

`/Mofit/Views/Tracking/TrackingView.swift`:

- `@EnvironmentObject var authManager: AuthManager`를 추가
- TrackingViewModel 생성 시 또는 stopSession 호출 시 authManager 상태를 전달

### 7. ProfileEditView 수정

`/Mofit/Views/Profile/ProfileEditView.swift`:

- 프로필 저장 분기:
  - **비로그인**: 기존 SwiftData 저장 (변경 없음)
  - **로그인**: `APIService.shared.updateProfile(profile)` 호출 + 기존 SwiftData도 함께 업데이트 (로컬 프로필은 온보딩에서 사용하므로 유지)
- 프로필 로드 분기:
  - **비로그인**: 기존 SwiftData에서 로드
  - **로그인**: `.onAppear`에서 `APIService.shared.getProfile()` 호출하여 서버 프로필로 초기화

### 8. ClaudeAPIService 정리

`/Mofit/Services/ClaudeAPIService.swift`:

- 이 파일은 비로그인 상태에서도 AI 코칭이 불가하므로 (Phase 6에서 접근 차단), 더 이상 직접 호출되지 않음.
- 하지만 이 파일을 삭제하면 다른 곳에서 참조 에러가 발생할 수 있으므로, 아직 삭제하지 말고 그대로 두라.
- CoachingViewModel에서 `ClaudeAPIService` 인스턴스를 생성하는 코드가 남아있어도, 로그인 시에는 APIService를 사용하므로 문제없음.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Xcode 빌드가 에러 없이 성공해야 한다.

## AC 검증 방법

위 AC 커맨드를 실행하라. 빌드가 성공하면 `/tasks/2-auth/index.json`의 phase 7 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- **비로그인 동작을 깨뜨리지 마라.** 로그인하지 않은 사용자는 기존과 동일하게 앱을 사용할 수 있어야 한다. SwiftData 로직을 제거하지 말고, 분기만 추가하라.
- 서버 API 호출은 모두 `async/await`로 처리하라. `Task { }` 블록 안에서 호출.
- 네트워크 에러 발생 시 사용자에게 에러 메시지를 표시하라. 앱이 크래시되면 안 된다.
- `@Query`는 빌드 타임에 해석되므로 조건부로 제거할 수 없다. 로그인 시에도 `@Query`가 존재하되 사용하지 않을 뿐이다.
- `@EnvironmentObject`가 모든 뷰 계층에서 접근 가능한지 확인하라. fullScreenCover에서는 자동 전달되지 않을 수 있으므로 명시적으로 `.environmentObject(authManager)`를 추가해야 할 수 있다.
- 서버에서 받은 날짜 문자열(ISO 8601)을 Date로 파싱할 때 `ISO8601DateFormatter`를 사용하라.
