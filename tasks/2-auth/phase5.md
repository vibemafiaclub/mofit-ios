# Phase 5: ios-networking

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/code-architecture.md`
- `/docs/adr.md`
- `/tasks/2-auth/docs-diff.md` (이번 task의 문서 변경 기록)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `/server/src/routes/auth.js` — 인증 API 스펙
- `/server/src/routes/profile.js` — 프로필 API 스펙
- `/server/src/routes/sessions.js` — 세션 API 스펙
- `/server/src/routes/coaching.js` — 코칭 API 스펙

현재 iOS 프로젝트의 관련 파일도 확인하라:

- `/Mofit/Services/ClaudeAPIService.swift` — 기존 Claude API 서비스
- `/Mofit/App/MofitApp.swift` — 앱 엔트리포인트
- `/Mofit/App/ContentView.swift` — 탭 뷰
- `/project.yml` — Xcode 프로젝트 설정

## 작업 내용

iOS 앱의 서버 통신 레이어를 구축한다.

### 1. APIConfig

`/Mofit/Config/APIConfig.swift`:
- 서버 base URL을 관리하는 enum
- `static let baseURL = "https://<Railway 배포 URL>"`
- 이전 phase에서 배포한 서버 URL을 사용하라. `/docs/code-architecture.md` 또는 `/server/.env.example`에서 확인.

### 2. KeychainService

`/Mofit/Services/KeychainService.swift`:
- JWT 토큰을 iOS Keychain에 저장/조회/삭제하는 유틸리티
- 인터페이스:
  - `static func save(token: String)` — kSecClassGenericPassword로 저장
  - `static func getToken() -> String?` — 저장된 토큰 조회
  - `static func deleteToken()` — 토큰 삭제
- 서비스명(kSecAttrService): `"com.mofit.app.auth"`
- 계정명(kSecAttrAccount): `"jwt_token"`

### 3. AuthManager

`/Mofit/Services/AuthManager.swift`:
- `@MainActor final class AuthManager: ObservableObject`
- `@Published var isLoggedIn: Bool`
- `@Published var currentUser: AuthUser?` (AuthUser: id, email)
- `init()`: Keychain에서 토큰 확인 → 있으면 `isLoggedIn = true`
- `func signup(email: String, password: String) async throws`
  - `POST /auth/signup` 호출
  - 성공 시 JWT를 Keychain에 저장, isLoggedIn = true, currentUser 설정
- `func login(email: String, password: String) async throws`
  - `POST /auth/login` 호출
  - 성공 시 JWT를 Keychain에 저장, isLoggedIn = true, currentUser 설정
- `func logout()`
  - Keychain에서 토큰 삭제, isLoggedIn = false, currentUser = nil

### 4. APIService

`/Mofit/Services/APIService.swift`:
- 서버 HTTP 통신을 담당하는 클래스
- 인터페이스:

```swift
class APIService {
    static let shared = APIService()

    // 프로필
    func getProfile() async throws -> ServerProfile
    func updateProfile(_ profile: ServerProfile) async throws -> ServerProfile

    // 세션
    func getSessions(date: Date?) async throws -> [ServerSession]
    func createSession(_ session: ServerSession) async throws -> ServerSession
    func deleteSession(id: String) async throws

    // 코칭
    func getFeedbacks(date: Date?) async throws -> [ServerFeedback]
    func requestCoaching(prompt: String, type: String) async throws -> ServerFeedback
}
```

- 모든 요청에 `Authorization: Bearer <token>` 헤더를 자동 첨부 (KeychainService에서 토큰 조회)
- 서버 응답의 camelCase JSON을 Swift 구조체로 디코딩
- 에러 처리: 401 응답 시 AuthManager를 통해 자동 로그아웃 (토큰 만료 대응)

**서버 응답 모델 (Codable 구조체):**

```swift
struct ServerProfile: Codable {
    let gender: String
    let height: Double
    let weight: Double
    let bodyType: String
    let goal: String
    let coachStyle: String
}

struct ServerSession: Codable {
    let id: String?  // POST 시 nil, GET 응답에 포함
    let exerciseType: String
    let startedAt: String  // ISO 8601
    let endedAt: String
    let totalDuration: Int
    let repCounts: [Int]
}

struct ServerFeedback: Codable {
    let id: String?
    let date: String
    let type: String
    let content: String
    let createdAt: String?
}
```

### 5. MofitApp.swift 수정

- `AuthManager`를 `@StateObject`로 생성하여 환경에 주입:

```swift
@main
struct MofitApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
        .modelContainer(for: [UserProfile.self, WorkoutSession.self, CoachingFeedback.self])
    }
}
```

### 6. project.yml 수정

`Security.framework` 의존성을 추가하라 (Keychain API 사용):

```yaml
dependencies:
  - sdk: SwiftUI.framework
  - sdk: SwiftData.framework
  - sdk: AVFoundation.framework
  - sdk: Vision.framework
  - sdk: Security.framework
```

그리고 `xcodegen generate`를 실행하여 프로젝트를 재생성하라.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Xcode 빌드가 에러 없이 성공해야 한다.

## AC 검증 방법

위 AC 커맨드를 실행하라. 빌드가 성공하면 `/tasks/2-auth/index.json`의 phase 5 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 이 phase에서는 기존 뷰를 수정하지 마라. 네트워킹 레이어와 AuthManager만 추가한다.
- AuthManager는 `@EnvironmentObject`로 주입하므로, 기존 뷰에서 아직 사용하지 않아도 빌드는 성공해야 한다.
- Keychain API는 시뮬레이터에서도 동작한다. 별도 Keychain sharing 설정은 불필요.
- APIService의 baseURL은 Phase 4에서 배포한 Railway URL을 하드코딩한다. 환경 분기는 MVP scope 밖.
- `Secrets.swift`의 Claude API 키는 아직 삭제하지 마라. Phase 7에서 기존 뷰 수정 시 함께 처리한다.
- 기존 테스트를 깨뜨리지 마라.
