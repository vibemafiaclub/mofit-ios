# docs-diff: camera-permission-recovery

Baseline: `34628c9`

## `docs/adr.md`

```diff
diff --git a/docs/adr.md b/docs/adr.md
index 7fb9ec6..8b6e5c4 100644
--- a/docs/adr.md
+++ b/docs/adr.md
@@ -114,3 +114,11 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 **범위**: `Mofit/Services/PoseDetectionService.swift` 에 `PoseFrameResult` struct + `detectPoseDetailed(in:)` 메서드 신규, 기존 `detectPose(in:)` + `extractJoints` 삭제. `Mofit/ViewModels/TrackingViewModel.swift` 에 `DiagnosticHint` enum(2 case), `@Published var diagnosticHint`, `private enum Diagnostic`(카피·임계치 상수), `private struct DiagnosticHintEvaluator`(Foundation 만 사용하는 pure struct) 추가. `Mofit/Views/Tracking/TrackingView.swift` 에 `hintBanner(hint:)` private subview + ZStack 오버레이 추가. 상수·카피는 TVM `private enum Diagnostic` 한 곳에만 두며 `ConfigService` 신규 레이어 금지. `DiagnosticHint` 에 third case / 프로토콜 / 전략 패턴 도입 금지.
 **연계**: ADR-017 로 스쿼트 전용 포지셔닝이 확정됐으나, 진단 로직은 exercise-agnostic(`TrackingViewModel.currentReps` 및 `hasCompleteSideForSquat` 네이밍은 squat 기준 발화이나 pushup/situp 에서도 동일 임계치로 동작). 튜닝은 v2.
 **테스트**: `DiagnosticHintEvaluator` 를 Foundation 외 import 없는 pure struct 로 추출, phase1 에이전트가 구현 직후 6개 시나리오(grace / sustain / 중간 회복 / rep 후 숨김 / lowLight / 우선순위) 를 코드 트레이스로 검증. `MofitTests` 타겟 신설 금지(task 0~3 전례 유지). 실기기 QA 는 merge 전 1회: (a) 정상 환경 3rep 카운트, (b) 프레임 이탈 시 3~5초 내 .outOfFrame 배너 출현. 조도 케이스 실기기 생략 가능.
+
+### ADR-019: 카메라 권한 거부 복구 플로우 (설정 딥링크 + 상태별 폴백 UI)
+**결정**: `TrackingView` 진입 시 `AVCaptureDevice.authorizationStatus(for: .video)` 를 3분기한다. `.notDetermined` → `AVCaptureDevice.requestAccess(for: .video)` 인라인 요청 + completion 에서 상태 재계산 + `.active` scenePhase 전이 시 재조회. `.denied` / `.restricted` → 풀스크린 폴백 카드 (타이틀 "카메라 권한이 필요해요" + 프라이버시 서브카피 + Primary "설정에서 권한 켜기" → `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)` + Secondary "홈으로 돌아가기" → dismiss). `.authorized` → 기존 트래킹 뷰. `HomeView` "스쿼트 시작" 버튼 아래에 `.denied` / `.restricted` **에 한해** "카메라 권한 필요" 작은 배지 노출(CTO 조건 2 — `.notDetermined` 에서 배지 금지, reject_trigger "'카메라 권한 없으면 아무것도 못함' 으로 시작" 재트리거 방지). 권한 상태 → 분기 enum 매핑은 Foundation-only pure struct `CameraPermissionResolver.decide(status:)` 로 추출해 `MofitTests/CameraPermissionResolverTests.swift` 에서 4 케이스(authorized/denied/restricted/notDetermined) assert (iter 7 선례와 동일 패턴).
+**이유**: iter 8 설득력 시뮬(run_id: `home-workout-newbie-20s_20260424_234401`, keyman `decision: drop`, `confidence: 55`) 에서 `risk_preference: conservative` + `personality_notes: "3일 써보고 아니면 삭제"` 페르소나가 설치 직후 카메라 권한 거부 시점에 회복 경로 없이 즉시 이탈하는 경로가 최종 판정 실패의 독립 사유. 현 `CameraManager.swift 는 `AVCaptureDevice.default(..., position: .front)` 직접 호출 전에 `AVCaptureDevice.authorizationStatus` / `requestAccess` 체크가 전무해, `.denied` 상태 유저는 빈 검은 preview + 무의미한 stopButton 만 본 채로 고립. TestFlight/앱스토어 출시 전 시점에 복구 플로우를 넣어야 초기 별점·리뷰 피해를 차단.
+**범위**: `TrackingView` 진입 플로우 한정. ADR-017 스쿼트 전용 스코프와 일치. 본문에서 "카메라 권한을 요구하는 모든 진입점에 동일 폴백" 수준으로만 서술. 파일 변경 매트릭스: (a) `Mofit/Views/Tracking/TrackingView.swift` 최상단 3분기 + 기존 tracking body 를 `.ready` 브랜치에 한정 + `viewModel.startSession` 호출을 `.ready` 가드 안으로 이동, (b) `Mofit/Views/Home/HomeView.swift` "스쿼트 시작" 버튼 아래 배지 1개 + `@State var cameraStatus` + `.onAppear` + `.onChange(of: scenePhase)` 재조회, (c) `Mofit/Views/Tracking/CameraPermissionResolver.swift`(신규) pure struct + `CameraPermissionDecision` enum(3 case) + `@unknown default` fail-closed fallback, (d) `MofitTests/CameraPermissionResolverTests.swift`(신규) 4 assert, (e) `project.yml` `INFOPLIST_KEY_NSCameraUsageDescription` 카피를 프라이버시 문구("Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다.") 로 갱신해 system prompt ↔ 폴백 카드 카피 일관성 확보. `Camera/CameraManager.swift` 본체는 불변(permission 체크를 Manager 에 두면 책임 번짐 + 회귀 위험).
+**트레이드오프**: (a) 권한 요청 시점이 `TrackingView` 진입 시점으로 고정되어 `HomeView` 에서 선제 요청 불가. 첫 설치 유저는 "스쿼트 시작" 탭 직전까지 카메라 권한 질문을 받지 않는다. 이는 설계 의도(reject_trigger 재트리거 방지) 이며 미래 기여자가 "선제 요청이 UX 상 낫다" 며 되돌리는 것을 방지하기 위함. (b) `TrackingView` body 가 권한 분기 만큼 커지지만 `@StateObject TrackingViewModel` 을 권한 분기 외부로 유지해 `CameraPermissionView` 래퍼 뷰 분리 안 함 — `StateObject` pass-through 지옥 및 VM lifecycle 결합을 회피(옵션 X "TrackingContent 자식 뷰 추출 + VM 을 그 안에 둠" 도 기각: 230 lines 이동 회귀 위험 대비 실익 미검증, 실제 AVFoundation console warning 이 crash/hang 으로 이어지는 증거 확인 후 마이그레이션). (c) `CameraManager.init` 은 `.denied` 상태에서도 background queue 에서 `configureSession` 을 돌리지만, `startRunning()` 가드가 `.ready` 브랜치 `.onAppear` 에 국한되어 실제 capture 는 호출되지 않음. 콘솔 warning 유무는 phase 1 구현 직후 1회 육안 확인, 실제 UX 영향 관측 시 별건 재검토.
+**연계**: ADR-017(스쿼트 전용) 범위 유지. ADR-015(외부 의존성 최소화) — SPM 신규 도입 없음, AVFoundation 는 SDK 내장. ADR-018(진단 힌트 2종) 과 무충돌(진단 힌트는 `.authorized` + tracking 상태에서만 평가, 권한 분기가 앞단에서 이미 컷). iter 7 `MofitTests` 타겟(task 6) 를 그대로 재사용, 신규 target 추가 없음.
+**테스트**: `CameraPermissionResolver.decide(status:)` 에 `.authorized` → `.ready`, `.denied` → `.showSettingsFallback`, `.restricted` → `.showSettingsFallback`, `.notDetermined` → `.requestInline` 4 케이스 XCTest. `@unknown default` 케이스 별도 테스트는 미작성(Apple SDK 향후 enum 추가 방어는 구현 내부 fail-closed fallback 으로 충족). SwiftUI rendering / scenePhase 전이 / `UIApplication.shared.open` / `AVCaptureDevice.requestAccess` completion 은 SDK/UIKit 의존이라 테스트 대상 아님(코드 트레이스로 대체). 실기기 QA 없음(CTO 조건 5). `xcodebuild test` 한 줄로 CI 통과.
```

## `docs/spec.md`

```diff
diff --git a/docs/spec.md b/docs/spec.md
index 5ff18e7..c103e5f 100644
--- a/docs/spec.md
+++ b/docs/spec.md
@@ -123,6 +123,35 @@ AVCaptureSession (전면)
 - **로그인 유저 경로 불변**: `CoachingView.loggedInContent` 와 `POST /coaching/request` 서버 프록시(ADR-012) 경로는 이번 범위와 무관. generator 는 호출되지 않는다.
 - **테스트**: `CoachingSampleGenerator` 는 Foundation-only pure struct 로 추출. iter 7 CTO 조건 1 에 따라 `MofitTests/CoachingSampleGeneratorTests.swift` 2 케이스(프로필 인터폴레이션 포함 / rep 숫자 포함) 가 CI 통과 조건. 실기기 QA 는 **없음** (자동 검증으로 완결).
 
+### 2.8 카메라 권한 분기
+
+`TrackingView` 진입 시 `AVCaptureDevice.authorizationStatus(for: .video)` 를 3분기한다 (ADR-019).
+
+- **판정 매핑** (`CameraPermissionResolver.decide(status:) -> CameraPermissionDecision`)
+  - `.authorized` → `.ready` (기존 트래킹 뷰 + `viewModel.startSession(...)` 호출)
+  - `.notDetermined` → `.requestInline` (`AVCaptureDevice.requestAccess(for: .video)` 인라인 요청 + completion 에서 decision 재계산)
+  - `.denied` / `.restricted` → `.showSettingsFallback` (풀스크린 폴백 카드)
+  - `@unknown default` → `.showSettingsFallback` (fail-closed, Apple SDK 향후 enum 추가 방어)
+- **풀스크린 폴백 카드 카피 (고정)**
+  - 타이틀: "카메라 권한이 필요해요"
+  - 서브: "Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다."
+  - Primary CTA: "설정에서 권한 켜기" → `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`
+  - Secondary CTA: "홈으로 돌아가기" → `dismiss()` (기존 closeButton 과 동일 경로)
+- **재조회 hook**
+  - `.onAppear` 에서 decision 초기 계산.
+  - `.onChange(of: scenePhase)` — `.active` 전이 시 재계산 (사용자가 설정 앱에서 권한 켜고 돌아오면 자동으로 `.ready` 로 진입).
+  - `AVCaptureDevice.requestAccess(for: .video)` completion 에서도 `@MainActor` 컨텍스트로 decision 재계산 (`.notDetermined` → `.authorized` 전이는 scenePhase 가 안 바뀌므로 completion hook 이 유일 경로).
+- **startSession 가드**
+  - `viewModel.startSession(modelContext:isLoggedIn:)` 는 `decision == .ready` 브랜치 `.onAppear` 안에서만 호출. `.showSettingsFallback` / `.requestInline` 상태에서는 호출하지 않음 → AVCaptureSession.startRunning() 미호출 → 빈 검은 preview 회피.
+  - `@StateObject TrackingViewModel` 는 View init 시 생성되므로 `CameraManager.init()` 의 background configureSession 는 돌지만, capture 시작이 가드되어 실제 프레임 발생 0.
+- **HomeView 배지 규칙**
+  - "스쿼트 시작" 버튼 아래에 `.denied` / `.restricted` 일 때만 "카메라 권한 필요" 배지 노출.
+  - `.notDetermined` / `.authorized` 에서는 **배지 비노출** (CTO 조건 2 — `.notDetermined` 재트리거 방지).
+  - `HomeView` 도 `.onAppear` + `.onChange(of: scenePhase)` 에서 `AVCaptureDevice.authorizationStatus(for: .video)` 재조회 → `@State var cameraStatus` 갱신.
+- **프라이버시 카피 일관성**: `project.yml` `INFOPLIST_KEY_NSCameraUsageDescription` 을 "Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다." 로 갱신해 system prompt ↔ 폴백 카드 ↔ prd §4 프라이버시 섹션 3곳 문구 동기화. 사실 정합: `grep -rn 'sampleBuffer|CVPixelBuffer|CMSampleBuffer' Mofit/` 는 `Camera/CameraManager.swift`, `ViewModels/TrackingViewModel.swift`, `Services/PoseDetectionService.swift`, `Services/HandDetectionService.swift` 4-hit 전부 온디바이스 Vision 경로로만 흐름 (URLSession 호출부와 교차 0).
+- **추상화 금지 원칙**: `PermissionService` / `CameraPermissionManager` / `NotificationCenter.default.addObserver(UIApplication.didBecomeActiveNotification)` 등 신규 싱글톤/추상화 금지(CTO 조건 4). 단일 뷰 `@State` + SwiftUI environment(`@Environment(\.scenePhase)`, `@Environment(\.dismiss)`) 로만 처리.
+- **테스트**: `CameraPermissionResolver` 를 Foundation-only pure struct 로 추출. `MofitTests/CameraPermissionResolverTests.swift` 4 케이스(authorized/denied/restricted/notDetermined) 가 CI 통과 조건. 실기기 QA 없음(CTO 조건 5, 자동 검증 완결).
+
 ---
 
 ## 3. 데이터 모델
```

## `docs/testing.md`

```diff
diff --git a/docs/testing.md b/docs/testing.md
index f079322..70a4e5a 100644
--- a/docs/testing.md
+++ b/docs/testing.md
@@ -15,7 +15,9 @@
 `MofitTests` 타겟은 **iter 7(task 6-coaching-generator) 에서 신설**. 이전 task 0~5 의 "MofitTests 타겟 신설 금지" 선례는 **명시적으로 폐기**한다 (iter 7 CTO 조건 1: "실기기 QA 필수화 금지 + XCTest 2케이스 CI 통과 조건").
 
 - **범위**: Foundation-only pure struct 의 회귀 방지용. `@Model` / SwiftData / UIKit / AVFoundation / Vision / 네트워크 의존 코드는 여전히 테스트 대상 아님 (mock 재작성이 구현 중복).
-- **현재 유일 대상**: `CoachingSampleGenerator` (Foundation-only, 입력 결정론적). 2 케이스 — (a) 빈 세션 + 프로필 인터폴레이션 포함 확인, (b) rep 수 인터폴레이션 포함 확인.
+- **현재 대상**:
+  - `CoachingSampleGenerator` (Foundation-only, 입력 결정론적). 2 케이스 — (a) 빈 세션 + 프로필 인터폴레이션 포함 확인, (b) rep 수 인터폴레이션 포함 확인.
+  - `CameraPermissionResolver` (Foundation-only, `AVAuthorizationStatus` enum 입력 결정론적 — AVFoundation 은 SDK 내장이라 SPM 추가 없음, runtime API 호출 0). 4 케이스 — authorized → ready / denied → showSettingsFallback / restricted → showSettingsFallback / notDetermined → requestInline.
 - **파일 위치**: `MofitTests/<TypeName>Tests.swift` 1파일 1타입. 접근은 `@testable import Mofit` 로 internal 심볼 사용 (public 노출 금지).
 - **CI 실행**: `xcodebuild -scheme Mofit test -destination "platform=iOS Simulator,name=<iPhone ...>"`. destination 은 `xcrun simctl list devices available` 결과에서 동적으로 선택하거나 `iPhone 16` 폴백.
 - **외부 의존 금지**: Nimble / Quick / Sourcery / Mockingbird 등 테스트 보조 SPM 도입 금지. XCTest 내장만 사용 (ADR-015 외부 의존성 최소화 원칙 유지).
```
