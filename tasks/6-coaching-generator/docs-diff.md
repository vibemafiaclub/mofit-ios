# docs-diff: coaching-generator

Baseline: `b7c5d9e`

## `docs/adr.md`

```diff
diff --git a/docs/adr.md b/docs/adr.md
index cf5000f..7fb9ec6 100644
--- a/docs/adr.md
+++ b/docs/adr.md
@@ -34,6 +34,15 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 **결정**: 최근 7일 기록 + 요약 통계 + 일별 추이를 context로 전달.
 **이유**: 토큰 절약. 최근 패턴이 장기 이력보다 코칭에 유의미. 추이 데이터(일별 rep, 세트, 세트당 평균)로 경향성 기반 조언 가능.
 
+**2026-04-24 업데이트 (task 6-coaching-generator)**: 비로그인 분기 AI 코칭 샘플은 `CoachingSamples.swift` 내 정적 카피 2종 하드코딩을 제거하고, Foundation-only pure struct `CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 `WorkoutSession` 기반으로 결정론적 생성.
+- 템플릿 수: **6개 base** (goal 3종(weightLoss/strength/bodyShape) × kind 2종(pre/post)). 기록유무(최근 7일 내 `totalReps > 0` 세션 존재 여부) 와 `bodyType` 은 같은 템플릿 내부의 **문자열 인터폴레이션 분기** 로 처리 (템플릿 개수 증분 없음). 10개 한도 엄수 — 초과 시 재승인 티켓.
+- 생성 경로: `CoachingView.notLoggedInContent` 가 `@Query UserProfile` + `@Query WorkoutSession` 결과를 Foundation-only intermediate struct(`CoachingGenInput`, `CoachingGenSession`) 로 변환 → `CoachingSampleGenerator.generate(input:now:)` 호출 → `[CoachingSample]`(pre 1 + post 1) 반환. `@Model` 타입을 generator 가 직접 참조하지 않음(테스트 결정론 + SwiftData 의존 격리).
+- **프로필 nil(온보딩 미완) 폴백**: 하드코딩 샘플 재사용 **금지**. 카드 자체를 숨기고 "온보딩을 먼저 완료해주세요" CTA 만 노출. 이 폴백이 generic 복귀 경로가 되면 이번 delta 의 목적이 무력화됨.
+- 카드 하단 disclaimer 현행 유지 ("※ 예시 피드백 (실제 데이터 기반으로 매번 다름)"). "로그인하면 Claude AI 기반 더 정교한 분석 가능" 유도 문구 **삽입 금지** (비로그인 단계에서 "이거 가짜구나" 역효과).
+- 로그인 유저 경로(`POST /coaching/request` → 서버 → Claude API) 및 7일 context 계약은 **완전 불변** (ADR-006 원문 + ADR-012 유지). 이번 update 는 **비로그인 분기 한정**.
+- 트레이드오프: (a) 템플릿 결정론 = 동일 입력 → 동일 출력이라 "다양성" 이 없음. 대신 입력(프로필/기록)이 바뀌면 출력이 바뀌므로 "내 상황 반영" 이 ChatGPT 대비 증거가 됨. (b) 7일 외 세션은 집계에서 제외 (ADR-006 원칙 준수). (c) `totalReps == 0` autosave 세션(ADR-009 task 5 delta) 은 기록유무 판정에서도 제외.
+- 측정: phase 1 배포 후 차기 iter 시뮬(`ideation` → `persuasion-review`) 에서 keyman 의 "그거면 ChatGPT 쓰지" / "하드코딩 정적 카피" 언급이 report 개선 포인트에서 제거되는지 확인.
+
 ### ADR-007: 다크모드 고정
 **결정**: 시스템 설정 무시, 다크모드만 지원.
 **이유**: 무채색 기반 디자인이 다크모드에서 가장 자연스러움. 라이트/다크 두 벌 디자인 불필요 → 개발 속도 향상.
@@ -90,10 +99,10 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 **SUPERSEDED by ADR-017** — "준비중" UI 자체가 제거됨. 스쿼트 전용 포지셔닝으로 전환.
 **결정**: ExercisePicker에서 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4의 비활성화 톤으로 표시. tap 자체는 차단하지 않되, selected 전환/화면 dismiss 대신 토스트 "현재는 스쿼트만 지원합니다"만 1.5초 노출하고 트래킹 진입은 차단.
 **이유**: ADR-008("UI는 있되 내부 전부 스쿼트 통일")은 3일 체험 페르소나가 푸쉬업을 한 번만 눌러봐도 기대 불일치가 드러나 즉시 삭제 트리거가 됨 (시뮬 run_id: home-workout-newbie-20s_20260424_153242). 기능 다양성 과시보다 신뢰도 우선.
-**트레이드오프**: 운동별 판정 로직이 추가될 때까지 선택지 다양성 축소. 셀 tap 자체는 남겨둬 향후 재활성화 시 회귀 테스트 누락 리스크를 줄임. 토스트 카피에는 "곧 지원됩니다" 같은 미래 약속 문구 금지.
+**트레이드오프**: 운동별 판정 로직이 추가될 때까지 선택지 다양성 축소. 셀 tap 자체는 남겨둬 향후 재활성화 시 회귀 테스트 누락 리스크를 줄임. 토스트 카피에는 출시 일정·확장 계획 등 미래 약속 문구 금지.
 
 ### ADR-017: 스쿼트 전용 포지셔닝 확정 (ADR-008, ADR-016 대체)
-**결정**: ExercisePickerView 파일 삭제 + HomeView의 운동 종류 선택 드롭다운 제거. "스쿼트 시작" 고정 CTA 로 전환. 랜딩/README/docs 카피에서 "홈트/운동 종류" 언어를 "스쿼트"로 정돈. 미래 약속 문구(곧 지원됩니다, 로드맵 등) 금지.
+**결정**: ExercisePickerView 파일 삭제 + HomeView의 운동 종류 선택 드롭다운 제거. "스쿼트 시작" 고정 CTA 로 전환. 랜딩/README/docs 카피에서 "홈트/운동 종류" 언어를 "스쿼트"로 정돈. 미래 약속 문구(지원 예정·출시 예정·계획 등) 금지.
 **이유**: iter 4 설득력 검토(run_id: home-workout-newbie-20s_20260424_193756)에서 "홈트 기대 설치 → 3일 안에 스쿼트 전용임 인지 → 무료 스쿼트 카운터로 전환" 이탈 경로가 keyman 최종 판정 실패의 독립적 reject 사유. "준비중" UI 를 남겨두는 것만으로도 `personality_notes`("3일 써보고 아니면 삭제") + `switching_cost: low` 경쟁재 조건에서 기대 불일치가 드러남. 포지셔닝 자체를 스쿼트 전용으로 좁혀 기대-실제 갭을 제거.
 **트레이드오프**: 푸쉬업/싯업 확장 시 운동 종류 선택 UI/상태를 복구해야 함. 단, `TrackingViewModel.exerciseType` 분기 + `PushUpCounter.swift`/`SitUpCounter.swift` 내부 판정 자산은 보존(CTO 조건부 #1)하여 재활성화 비용 최소화. 이번 삭제는 View 레이어 한정.
 **범위**: `Mofit/Views/Home/ExercisePickerView.swift` 파일 삭제, `Mofit/Views/Home/HomeView.swift` 에서 `exerciseSelector`·`showExercisePicker`·`selectedExerciseName` 상태 제거. `TrackingView(exerciseType: "squat", ...)` 호출로 하드코딩. ADR-008/ADR-016 은 SUPERSEDED 표기 유지(역사 보존).
```

## `docs/code-architecture.md`

```diff
diff --git a/docs/code-architecture.md b/docs/code-architecture.md
index bb1539e..8b4536e 100644
--- a/docs/code-architecture.md
+++ b/docs/code-architecture.md
@@ -25,7 +25,8 @@ Mofit/
 │   ├── Records/
 │   │   └── RecordsView.swift
 │   ├── Coaching/
-│   │   └── CoachingView.swift
+│   │   ├── CoachingView.swift
+│   │   └── CoachingSamples.swift  # CoachingSample struct + CoachingSampleGenerator (Foundation-only pure, iter 7)
 │   └── Profile/
 │       └── ProfileEditView.swift
 │
```

## `docs/spec.md`

```diff
diff --git a/docs/spec.md b/docs/spec.md
index 601b75a..5ff18e7 100644
--- a/docs/spec.md
+++ b/docs/spec.md
@@ -33,7 +33,7 @@ MofitApp
 - `RecordsView` — 날짜바 + 세션 리스트
 - `CoachingView` — AI 피드백 카드 + 운동 전/후 버튼
 - `ProfileEditView` — 온보딩 5개 값 수정 + (로그인 시) 로그아웃
-- `AuthGateView` — 비로그인 시 코칭 탭에 표시되는 로그인/회원가입 안내 + AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단 노출.
+- `AuthGateView` — 비로그인 시 코칭 탭에 표시되는 로그인/회원가입 안내 + `CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 세션 기반으로 동적 생성한 AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단에 노출. 프로필 nil 시 카드 숨김 + "온보딩 먼저 완료해주세요" CTA. 상세 §2.7.
 - `SignupView`, `LoginView`
 
 ---
@@ -108,6 +108,21 @@ AVCaptureSession (전면)
 - **에러 정책**: save 실패는 `print("autosave failed: \(error)")` 만 남기고 `saveError` / alert 건드리지 않음. 트래킹 중 UI 방해 절대 금지.
 - **0rep 세션**: insert 됐지만 rep 한 번도 안 들어오고 stopSession 호출된 세션은 `repCounts=[]` 로 남음. `RecordsView` 가 `$0.totalReps > 0` 필터로 숨김. SwiftData 에는 소량 남지만 UX 영향 0.
 
+### 2.7 비로그인 코칭 샘플 생성
+
+비로그인 유저가 코칭 탭(`CoachingView.notLoggedInContent`) 진입 시 노출되는 "운동 전/후" 샘플 카드 2장은 정적 하드코딩 카피가 아니라 `CoachingSampleGenerator` 가 **온보딩 값 + 최근 7일 로컬 `WorkoutSession`** 기반으로 결정론적 생성한다 (ADR-006 2026-04-24 업데이트).
+
+- **generator 시그니처**: `CoachingSampleGenerator.generate(input: CoachingGenInput, now: Date) -> [CoachingSample]`. 항상 `pre` 1개 + `post` 1개 (총 2개) 반환. Foundation-only pure struct. async 없음, 네트워크 없음, 랜덤 없음.
+- **입력 타입**: `CoachingGenInput` 은 Foundation-only struct. 필드 = `gender: String, height: Double, weight: Double, bodyType: String, goal: String, recentSessions: [CoachingGenSession]`. `@Model` 타입(`UserProfile` / `WorkoutSession`) 을 generator 가 직접 참조하지 않는다 — SwiftData 의존 격리 + 테스트 결정론.
+- **adapter 위치**: `CoachingView` 의 `@Query profiles` / `@Query sessions` 결과를 view 내부 helper 에서 `CoachingGenInput` 으로 변환해 generator 호출. adapter 자체는 SwiftData 의존이라 테스트 대상 아님.
+- **템플릿 차원**: `goal(3) × kind(2) = 6개 base`. 기록유무(최근 7일 내 `totalReps > 0` 세션 존재 여부) 와 `bodyType`(slim/normal/muscular/chubby) 은 같은 템플릿 내부 인터폴레이션 분기로 처리 (템플릿 개수 증분 없음). **10개 한도 엄수** — 초과 시 ADR-006 Update 블록 재승인 필요.
+- **최근 7일 정의**: `Calendar.current.startOfDay(for: now) - 6*86400` 부터 `now` 까지 (오늘 포함). `totalReps > 0` 필터 후 집계. `totalReps == 0` autosave 세션(ADR-009 task 5 delta) 은 제외.
+- **인터폴레이션 슬롯 (최대 3개)**: (a) 최근 7일 총 rep 합, (b) 최근 7일 세션 수, (c) post 한정 최신 세션의 `repCounts` 배열. "최다 요일" / "일 평균 증감" / 기타 고급 집계는 **이번 범위 밖** (Phase 2 재승인 대상). 요일 계산은 지역화 이슈로 테스트 결정론 훼손.
+- **프로필 nil 폴백**: `@Query profiles.first == nil` 일 때 `CoachingSampleGenerator` 호출 자체를 하지 않고 카드 자리를 "온보딩을 먼저 완료해주세요" CTA 로 대체. 정적 하드코딩 카피 재사용 **금지**. (`onboardingCompleted` 은 `@AppStorage` 키로 관리되며 `UserProfile` 의 필드가 아님 — `CoachingView` 도달 시점엔 `true` 가 보장되므로 nil 체크만으로 충분.)
+- **금지 문구**: "로그인하면 Claude AI 기반 더 정교한 분석 가능" / "가입하면 …" 등 **로그인 유도 카피 추가 금지**. 현행 disclaimer "※ 예시 피드백 (실제 데이터 기반으로 매번 다름)" 유지. 미래 출시 일정·개발 계획 약속 문구 금지(ADR-017 준수).
+- **로그인 유저 경로 불변**: `CoachingView.loggedInContent` 와 `POST /coaching/request` 서버 프록시(ADR-012) 경로는 이번 범위와 무관. generator 는 호출되지 않는다.
+- **테스트**: `CoachingSampleGenerator` 는 Foundation-only pure struct 로 추출. iter 7 CTO 조건 1 에 따라 `MofitTests/CoachingSampleGeneratorTests.swift` 2 케이스(프로필 인터폴레이션 포함 / rep 숫자 포함) 가 CI 통과 조건. 실기기 QA 는 **없음** (자동 검증으로 완결).
+
 ---
 
 ## 3. 데이터 모델
```

## `docs/testing.md`

```diff
diff --git a/docs/testing.md b/docs/testing.md
index f7b6983..f079322 100644
--- a/docs/testing.md
+++ b/docs/testing.md
@@ -7,3 +7,16 @@
 - **구현과 테스트를 함께 작성**: 모듈 구현 직후 해당 테스트를 작성한다. 일괄 작성 금지.
 
 - 중요!: 테스트는 해당 모듈 구현 직후 바로 작성한다. 구현 계획에 테스트 작성 시점이 명시된다.
+
+---
+
+## XCTest 타겟
+
+`MofitTests` 타겟은 **iter 7(task 6-coaching-generator) 에서 신설**. 이전 task 0~5 의 "MofitTests 타겟 신설 금지" 선례는 **명시적으로 폐기**한다 (iter 7 CTO 조건 1: "실기기 QA 필수화 금지 + XCTest 2케이스 CI 통과 조건").
+
+- **범위**: Foundation-only pure struct 의 회귀 방지용. `@Model` / SwiftData / UIKit / AVFoundation / Vision / 네트워크 의존 코드는 여전히 테스트 대상 아님 (mock 재작성이 구현 중복).
+- **현재 유일 대상**: `CoachingSampleGenerator` (Foundation-only, 입력 결정론적). 2 케이스 — (a) 빈 세션 + 프로필 인터폴레이션 포함 확인, (b) rep 수 인터폴레이션 포함 확인.
+- **파일 위치**: `MofitTests/<TypeName>Tests.swift` 1파일 1타입. 접근은 `@testable import Mofit` 로 internal 심볼 사용 (public 노출 금지).
+- **CI 실행**: `xcodebuild -scheme Mofit test -destination "platform=iOS Simulator,name=<iPhone ...>"`. destination 은 `xcrun simctl list devices available` 결과에서 동적으로 선택하거나 `iPhone 16` 폴백.
+- **외부 의존 금지**: Nimble / Quick / Sourcery / Mockingbird 등 테스트 보조 SPM 도입 금지. XCTest 내장만 사용 (ADR-015 외부 의존성 최소화 원칙 유지).
+- **확장 정책**: 다른 모듈 회고 테스트는 각 모듈 변경 시점에 함께 추가(원칙 9행 유지). 이 target 을 "전 모듈 커버리지"로 부풀리지 않음.
```
