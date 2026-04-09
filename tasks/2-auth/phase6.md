# Phase 6: ios-auth-ui

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/flow.md`
- `/docs/code-architecture.md`
- `/tasks/2-auth/docs-diff.md` (이번 task의 문서 변경 기록)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `/Mofit/Services/AuthManager.swift` — 로그인 상태 관리
- `/Mofit/Services/APIService.swift` — 서버 통신
- `/Mofit/Services/KeychainService.swift` — 토큰 저장

현재 iOS 프로젝트의 관련 파일도 확인하라:

- `/Mofit/Views/Coaching/CoachingView.swift` — 기존 AI 코칭 뷰
- `/Mofit/Views/Profile/ProfileEditView.swift` — 기존 프로필 편집 뷰
- `/Mofit/Utils/Theme.swift` — 디자인 시스템 (neonGreen, darkBackground 등)
- `/Mofit/Views/Onboarding/OnboardingView.swift` — 기존 온보딩 뷰 (디자인 참고)

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

로그인/회원가입 화면을 만들고, AI 코칭 탭에 비로그인 안내 화면을 추가하고, 프로필 편집에 로그아웃 버튼을 추가한다.

### 1. 로그인 화면

`/Mofit/Views/Auth/LoginView.swift`:

- 디자인: 기존 앱의 다크 테마 + neon green 색상을 따른다.
- 상단: "로그인" 타이틀
- 이메일 입력 필드: TextField, 키보드 타입 emailAddress, autocapitalization none
- 비밀번호 입력 필드: SecureField
- "로그인" 버튼: neon green 배경, 전체 너비, 높이 56px, 라운드 16
- 로딩 중에는 ProgressView 표시, 버튼 disabled
- 에러 시 빨간 텍스트로 에러 메시지 표시
- 하단: "아직 계정이 없으신가요? 회원가입" 텍스트 + 버튼 → SignUpView로 이동
- `@EnvironmentObject var authManager: AuthManager`를 사용
- 로그인 성공 시 자동으로 dismiss (authManager.isLoggedIn이 true로 변경되면 CoachingView가 반응)

### 2. 회원가입 화면

`/Mofit/Views/Auth/SignUpView.swift`:

- 디자인: LoginView와 동일한 스타일
- 상단: "회원가입" 타이틀
- 이메일 입력 필드
- 비밀번호 입력 필드 (SecureField)
- 비밀번호 확인 입력 필드 (SecureField)
- 유효성 검증:
  - 이메일: 비어있지 않고 @ 포함
  - 비밀번호: 6자 이상
  - 비밀번호 확인: 비밀번호와 일치
  - 유효하지 않으면 "가입하기" 버튼 disabled
- "가입하기" 버튼: neon green 배경
- 로딩 중 ProgressView, 에러 시 빨간 텍스트
- 하단: "이미 계정이 있으신가요? 로그인" → LoginView로 이동
- 회원가입 성공 시 authManager.signup()이 자동 로그인까지 처리하므로, 별도 로그인 호출 불필요

### 3. AI 코칭 탭 비로그인 안내

`/Mofit/Views/Coaching/CoachingView.swift` 수정:

- `@EnvironmentObject var authManager: AuthManager`를 추가
- `body`에서 `authManager.isLoggedIn`을 체크:
  - **로그인 상태**: 기존 코칭 UI 그대로 표시
  - **비로그인 상태**: 안내 화면 표시

비로그인 안내 화면 구성:
- 중앙 정렬
- 아이콘: `brain.head.profile` (SF Symbol, 크게)
- 텍스트: "AI 코칭은 로그인 후\n사용할 수 있어요"
- "로그인" 버튼: neon green 배경, 전체 너비
- "회원가입" 버튼: neon green 테두리, 전체 너비 (outlined 스타일)
- 각 버튼 탭 시 해당 화면을 sheet 또는 fullScreenCover로 표시

### 4. 프로필 편집에 로그아웃 버튼

`/Mofit/Views/Profile/ProfileEditView.swift` 수정:

- `@EnvironmentObject var authManager: AuthManager`를 추가
- 기존 "모든 정보 초기화" 버튼 위에 로그아웃 버튼을 추가:
  - `authManager.isLoggedIn`이 true일 때만 표시
  - 텍스트: "로그아웃"
  - 스타일: 빨간 텍스트 (기존 "모든 정보 초기화"와 유사하지만 구분 가능하게)
  - 탭 시: `authManager.logout()` 호출 → dismiss

### 5. ContentView 수정

`/Mofit/App/ContentView.swift`:

- `@EnvironmentObject var authManager: AuthManager`를 추가 (뷰에서 직접 사용하지 않더라도, 하위 뷰들이 사용하므로 전달 경로 확보)

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Xcode 빌드가 에러 없이 성공해야 한다.

## AC 검증 방법

위 AC 커맨드를 실행하라. 빌드가 성공하면 `/tasks/2-auth/index.json`의 phase 6 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 기존 CoachingView의 로그인 상태 UI(피드백 버튼, 피드백 목록 등)는 그대로 유지하라. 비로그인 안내 화면만 추가.
- LoginView와 SignUpView 사이의 네비게이션은 NavigationStack 또는 sheet로 구현하라.
- 디자인은 기존 앱과 일관되게 유지하라: Theme.darkBackground, Theme.neonGreen, Theme.cardBackground 등을 사용.
- 이 phase에서는 데이터 소스 분기(SwiftData vs API)를 구현하지 마라. UI와 인증 흐름만 구현한다.
- HomeView에서 ProfileEditView를 .fullScreenCover로 표시할 때, `.environmentObject(authManager)`가 자동 전달되는지 확인하라. 전달되지 않으면 명시적으로 추가.
