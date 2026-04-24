# Spec — Mofit

`plan-and-build` skill 이 구현 계획 수립 시 참고하는 주 문서. iOS 앱 화면 구성·상태머신·데이터 모델·서버 API 계약을 한 곳에 모은다. 상세 배경은 `docs/prd.md` · `docs/flow.md` · `docs/code-architecture.md` · `docs/data-schema.md` · `docs/adr.md` 참조.

---

## 1. 앱 구조

### 1.1 탭 구성

TabView 3개. 다크모드 고정. 포인트 컬러 형광초록.

| 탭        | 루트 뷰            | 접근 제어          |
| --------- | ------------------ | ------------------ |
| 홈        | `HomeView`         | 온보딩 완료 필수   |
| 기록      | `RecordsView`      | 온보딩 완료 필수   |
| AI 코칭   | `CoachingView`     | **로그인 필수**    |

### 1.2 진입 분기

```
MofitApp
  → UserProfile.onboardingCompleted?
       false → OnboardingView
       true  → ContentView(TabView)
```

### 1.3 화면 목록

- `OnboardingView` — 단계별(성별→키→몸무게→체형→목표)
- `HomeView` — 오늘 요약 + "스쿼트 시작" 버튼 (운동 종류 선택 UI 없음, ADR-017)
- `TrackingView` — 카메라 프리뷰 + 오버레이 + 상태머신
- `RecordsView` — 날짜바 + 세션 리스트
- `CoachingView` — AI 피드백 카드 + 운동 전/후 버튼
- `ProfileEditView` — 온보딩 5개 값 수정 + (로그인 시) 로그아웃
- `AuthGateView` — 비로그인 시 코칭 탭에 표시되는 로그인/회원가입 안내 + `CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 세션 기반으로 동적 생성한 AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단에 노출. 프로필 nil 시 카드 숨김 + "온보딩 먼저 완료해주세요" CTA. 상세 §2.7.
- `SignupView`, `LoginView`

---

## 2. 핵심 상태머신

### 2.1 트래킹 상태머신

```
idle
  ── 손바닥 1초 OR 화면 탭 ──▶ countdown(5s)
                      └─ 완료 ──▶ tracking
tracking
  ── 손바닥 1초 OR 화면 탭(rep > 0) ──▶ setComplete
                      └─ 표시 후 ──▶ countdown(5s) ──▶ tracking (다음 세트)
any
  ── stop 버튼 ──▶ saveRecord ──▶ home (폭죽 연출)
```

운동 시간 = 첫 카운트다운 시작 ~ 종료 버튼. 화면 자동 잠금 off (`isIdleTimerDisabled = true`).

### 2.2 스쿼트 판정

`hip-knee-ankle` 세 관절 각도:

- 서있음: 각도 > 160°
- 앉음: 각도 < 100°
- 서있음 → 앉음 → 서있음 = 1 rep

### 2.3 손바닥 판정

5개 손가락 끝(tip)과 손목(wrist) 사이 관절 전부 펴짐 + 1초 연속 유지 → 트리거.

### 2.4 카메라 파이프라인

```
AVCaptureSession (전면)
  → CMSampleBuffer
      ├─ AVCaptureVideoPreviewLayer (30fps, 항상 부드러움)
      └─ Vision (15fps 샘플링)
           ├─ VNDetectHumanBodyPoseRequest → SquatCounter
           └─ VNDetectHumanHandPoseRequest → 손바닥 판정
```

### 2.5 트래킹 진단 힌트

트래킹 상태에서 rep 카운트가 안 올라가는 원인을 1줄 배너로 안내. 2종 고정(.outOfFrame / .lowLight), ADR-018.

- **판정 조건**
  - `.outOfFrame`: **양쪽 hip/knee/ankle 중 어느 쪽도 3조인트 모두 검출되지 않은 상태** (= `SquatCounter` 가 angle 을 계산할 수 없는 조건) 가 3초 연속 지속.
  - `.lowLight`: 하체 조인트(6개 중 검출분) 평균 confidence < 0.5 가 3초 연속 지속. outOfFrame 이 아닐 때만 평가.
  - 우선순위: outOfFrame > lowLight.
- **표시 규칙**
  - 트래킹 시작 후 최소 5초 grace (카메라 안정화).
  - 한 세션(TrackingView lifecycle) 내 rep 한 번이라도 카운트되면 힌트 숨김 + 재표시 금지.
  - 세트 경계(setComplete → 다음 countdown → tracking) 에서 evaluator 상태 리셋 금지.
  - 상단 반투명 배너 형태, 하단 종료 버튼 시야 가리지 않음.
- **카피 (고정 2종)**
  - `.outOfFrame`: "전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)"
  - `.lowLight`: "조명이 어두울 수 있어요 · 실내 조명을 밝혀주세요"
- **튜닝 대상**: grace 5s, sustain 3s, lowLight confidence 0.5. 전부 `TrackingViewModel` 내 `private enum Diagnostic` 에 상수화. 운영 중 튜닝은 이 enum 만 수정.

### 2.6 트래킹 autosave (비로그인 한정)

비로그인 유저의 `TrackingView` 세션은 SwiftData 에 rep 단위로 자동 저장된다. pain 대응: 트래킹 중 전화/앱 전환/크래시가 발생해도 기록 탭에 현재까지의 rep 수가 남는다(ADR-009 업데이트).

- **insert 시점**: 세션 생애 첫 `startCountdown()` 호출(= `hasStartedElapsedTimer` 가 false → true 로 전이하는 순간) 에서 `WorkoutSession(startedAt: sessionStartTime, repCounts: [])` 을 1회 insert. 2번째 이후 세트 시작에서는 재 insert 없음.
- **snapshot update 시점**: Counter 의 `@Published currentReps` 가 갱신될 때마다 `session.repCounts = self.repCounts + (currentReps > 0 ? [currentReps] : [])` 로 배열 교체 + `session.endedAt = Date()` + `session.totalDuration = elapsedTime` + `try? modelContext.save()`. `lastSavedReps` no-op 가드로 동일 값 재방출 시 save 스킵.
- **completeSet 시점**: `self.repCounts.append(currentReps)` 직후 같은 session 에 `session.repCounts = self.repCounts` 로 확정 값 덮어쓰기 + save. tail 재삽입 없음.
- **stopSession 시점**: (비로그인) `session.repCounts = self.repCounts` + `endedAt` / `totalDuration` 최종 반영 + save. `currentSession = nil` 로 해제. `modelContext.insert` 는 호출하지 않음 (이미 insert 완료).
- **로그인 유저**: 전부 스킵. 기존 `POST /sessions` 서버 저장 경로 유지(ADR-013, ADR-014).
- **에러 정책**: save 실패는 `print("autosave failed: \(error)")` 만 남기고 `saveError` / alert 건드리지 않음. 트래킹 중 UI 방해 절대 금지.
- **0rep 세션**: insert 됐지만 rep 한 번도 안 들어오고 stopSession 호출된 세션은 `repCounts=[]` 로 남음. `RecordsView` 가 `$0.totalReps > 0` 필터로 숨김. SwiftData 에는 소량 남지만 UX 영향 0.

### 2.7 비로그인 코칭 샘플 생성

비로그인 유저가 코칭 탭(`CoachingView.notLoggedInContent`) 진입 시 노출되는 "운동 전/후" 샘플 카드 2장은 정적 하드코딩 카피가 아니라 `CoachingSampleGenerator` 가 **온보딩 값 + 최근 7일 로컬 `WorkoutSession`** 기반으로 결정론적 생성한다 (ADR-006 2026-04-24 업데이트).

- **generator 시그니처**: `CoachingSampleGenerator.generate(input: CoachingGenInput, now: Date) -> [CoachingSample]`. 항상 `pre` 1개 + `post` 1개 (총 2개) 반환. Foundation-only pure struct. async 없음, 네트워크 없음, 랜덤 없음.
- **입력 타입**: `CoachingGenInput` 은 Foundation-only struct. 필드 = `gender: String, height: Double, weight: Double, bodyType: String, goal: String, recentSessions: [CoachingGenSession]`. `@Model` 타입(`UserProfile` / `WorkoutSession`) 을 generator 가 직접 참조하지 않는다 — SwiftData 의존 격리 + 테스트 결정론.
- **adapter 위치**: `CoachingView` 의 `@Query profiles` / `@Query sessions` 결과를 view 내부 helper 에서 `CoachingGenInput` 으로 변환해 generator 호출. adapter 자체는 SwiftData 의존이라 테스트 대상 아님.
- **템플릿 차원**: `goal(3) × kind(2) = 6개 base`. 기록유무(최근 7일 내 `totalReps > 0` 세션 존재 여부) 와 `bodyType`(slim/normal/muscular/chubby) 은 같은 템플릿 내부 인터폴레이션 분기로 처리 (템플릿 개수 증분 없음). **10개 한도 엄수** — 초과 시 ADR-006 Update 블록 재승인 필요.
- **최근 7일 정의**: `Calendar.current.startOfDay(for: now) - 6*86400` 부터 `now` 까지 (오늘 포함). `totalReps > 0` 필터 후 집계. `totalReps == 0` autosave 세션(ADR-009 task 5 delta) 은 제외.
- **인터폴레이션 슬롯 (최대 3개)**: (a) 최근 7일 총 rep 합, (b) 최근 7일 세션 수, (c) post 한정 최신 세션의 `repCounts` 배열. "최다 요일" / "일 평균 증감" / 기타 고급 집계는 **이번 범위 밖** (Phase 2 재승인 대상). 요일 계산은 지역화 이슈로 테스트 결정론 훼손.
- **프로필 nil 폴백**: `@Query profiles.first == nil` 일 때 `CoachingSampleGenerator` 호출 자체를 하지 않고 카드 자리를 "온보딩을 먼저 완료해주세요" CTA 로 대체. 정적 하드코딩 카피 재사용 **금지**. (`onboardingCompleted` 은 `@AppStorage` 키로 관리되며 `UserProfile` 의 필드가 아님 — `CoachingView` 도달 시점엔 `true` 가 보장되므로 nil 체크만으로 충분.)
- **금지 문구**: "로그인하면 Claude AI 기반 더 정교한 분석 가능" / "가입하면 …" 등 **로그인 유도 카피 추가 금지**. 현행 disclaimer "※ 예시 피드백 (실제 데이터 기반으로 매번 다름)" 유지. 미래 출시 일정·개발 계획 약속 문구 금지(ADR-017 준수).
- **로그인 유저 경로 불변**: `CoachingView.loggedInContent` 와 `POST /coaching/request` 서버 프록시(ADR-012) 경로는 이번 범위와 무관. generator 는 호출되지 않는다.
- **테스트**: `CoachingSampleGenerator` 는 Foundation-only pure struct 로 추출. iter 7 CTO 조건 1 에 따라 `MofitTests/CoachingSampleGeneratorTests.swift` 2 케이스(프로필 인터폴레이션 포함 / rep 숫자 포함) 가 CI 통과 조건. 실기기 QA 는 **없음** (자동 검증으로 완결).

---

## 3. 데이터 모델

### 3.1 로컬 (SwiftData)

비로그인 유저 + 로그인 여부 무관한 공통 엔티티.

- `UserProfile` (싱글톤): `gender`, `height`, `weight`, `bodyType`, `goal`, `onboardingCompleted`
- `WorkoutSession`: `id`, `exerciseType`, `startedAt`, `endedAt`, `totalDuration`, `repCounts: [Int]`
  - **주의**: tracking 중에는 `repCounts` 의 마지막 요소가 "진행 중 세트의 임시 snapshot" 이며, `completeSet` / `stopSession` 이후에는 "확정된 세트 합계" 로 상태가 전환된다 (§2.6 autosave).
- `CoachingFeedback`: `id`, `date`, `type` (pre/post), `content`, `createdAt`

**핵심 결정 (ADR-003)**: 세트는 별도 모델 없음. `repCounts: [Int]` 배열로 표현. `세트 수 = repCounts.count`, `총 rep = repCounts.sum()`.

### 3.2 서버 (Supabase PostgreSQL)

로그인 유저 전용. 전체 스키마는 `docs/data-schema.md` 서버 섹션.

| 테이블                | 핵심 컬럼                                                                                                        |
| --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `users`               | `id`, `email` (UNIQUE), `password_hash`, `created_at`                                                            |
| `user_profiles`       | `user_id` (UNIQUE FK), `gender`, `height`, `weight`, `body_type`, `goal`, `coach_style` (default `warm`)         |
| `workout_sessions`    | `user_id` (FK), `exercise_type`, `started_at`, `ended_at`, `total_duration`, `rep_counts int[]`                  |
| `coaching_feedbacks`  | `user_id` (FK), `date`, `type` (pre/post), `content`                                                             |

인덱스: `workout_sessions(user_id, started_at)`, `coaching_feedbacks(user_id, date)`.

---

## 4. 서버 API 계약

Node.js + Express. Railway 배포. JWT(bcrypt 해시). 모든 보호된 라우트는 `Authorization: Bearer <jwt>`.

### 4.1 인증

| 메서드 | 경로           | 바디                                      | 응답 요약                         |
| ------ | -------------- | ----------------------------------------- | --------------------------------- |
| POST   | `/auth/signup` | `{ email, password }`                     | `{ token, userId }` — 자동 로그인 |
| POST   | `/auth/login`  | `{ email, password }`                     | `{ token, userId }`               |

### 4.2 프로필

| 메서드 | 경로       | 바디                                                                 | 응답         |
| ------ | ---------- | -------------------------------------------------------------------- | ------------ |
| GET    | `/profile` | —                                                                    | `UserProfile`|
| PUT    | `/profile` | `{ gender, height, weight, bodyType, goal, coachStyle? }`            | `UserProfile`|

### 4.3 세션 (운동 기록)

| 메서드 | 경로              | 바디                                                                | 응답                |
| ------ | ----------------- | ------------------------------------------------------------------- | ------------------- |
| GET    | `/sessions`       | (query `from`, `to` ISO date)                                       | `WorkoutSession[]`  |
| POST   | `/sessions`       | `{ exerciseType, startedAt, endedAt, totalDuration, repCounts }`    | `WorkoutSession`    |
| DELETE | `/sessions/:id`   | —                                                                   | `204`               |

### 4.4 코칭

| 메서드 | 경로                 | 바디                                         | 응답                       |
| ------ | -------------------- | -------------------------------------------- | -------------------------- |
| GET    | `/coaching`          | (query `date` YYYY-MM-DD)                    | `CoachingFeedback[]`       |
| POST   | `/coaching/request`  | `{ type: "pre"\|"post" }`                    | `{ feedback: string }` — 서버가 Claude 호출, DB에 저장 후 응답 |

**일일 한도**: 유저당 `pre` 1회 + `post` 1회 (자정 리셋, 서버 측에서 `coaching_feedbacks(user_id, date, type)` 유일성 체크).

**API 실패 시 정책**: 횟수 차감하지 않음. 클라이언트는 에러 알림만 표시. 재시도는 사용자 수동.

### 4.5 Claude 프록시 컨텍스트

`/coaching/request` 처리 시 서버가 Claude에 넘기는 컨텍스트:

```
사용자: { gender, height, weight, bodyType, goal, coachStyle }
최근 7일 요약: { 운동일수, 총세션, 총rep, 일평균rep }
추이 (일별):   { rep[], 세트수[], 세트당평균rep[] }
```

---

## 5. 네트워킹 / 분기 규칙

클라이언트는 `AuthManager.isLoggedIn` 으로 저장소를 분기한다.

| 액션           | 로그인 유저                          | 비로그인 유저                   |
| -------------- | ------------------------------------ | ------------------------------- |
| 운동 완료 저장 | `POST /sessions` (세트 종료 시 1회)    | SwiftData autosave — 세션 첫 세트 시작 insert + 매 rep snapshot save (§2.6) |
| 프로필 수정    | `PUT /profile`                       | SwiftData 로컬 저장             |
| 기록 조회      | `GET /sessions`                      | SwiftData fetch                 |
| AI 코칭        | `POST /coaching/request`             | **사용 불가** (AuthGateView)    |

- **마이그레이션 없음** (ADR-013). 비로그인으로 쌓은 로컬 데이터는 로그인해도 서버로 이전되지 않는다.
- **네트워크 실패**: 에러 알림만 (ADR-014). 로컬 임시 저장 + 재시도 없음.

---

## 6. 분석

Mixpanel iOS SDK (SPM). 이 프로젝트의 **유일한 외부 의존성**(ADR-015).

- `AnalyticsService` 싱글톤이 Mixpanel 래핑.
- 이벤트명은 `AnalyticsEvent` enum 으로 타입 안전.
- `MofitApp.init()` 에서 초기화.
- 로그인/로그아웃 시 `identify(userId:)` / `reset()` 호출.

---

## 7. 배포

- **iOS**: Xcode 15+, iOS 17+. 빌드 시 `xcodegen generate` → `Mofit.xcodeproj` 재생성.
- **서버**: Railway (`https://server-production-45a4.up.railway.app`).
- **DB**: Supabase (`https://xenxstjnwkchwlxvardj.supabase.co`).

Secrets 관리: `Mofit/Config/Secrets.swift` 는 `.gitignore`. 템플릿은 `Secrets.example.swift`.

---

## 8. 구현 계획 작성 시 유의사항

- 새 기능은 **작은 phase로 쪼개** `prompts/task-create.md` 규격에 맞춰 `tasks/<id>/phaseN.md` 로 생성한다.
- iOS 변경은 대부분 `Mofit.xcodeproj` 재생성이 동반 — 빌드 성공 여부는 `xcodegen` + `xcodebuild` 로 검증.
- 서버 변경은 `server/` 하위에서 독립 빌드. Railway 배포는 자동(git push) 또는 수동 트리거. 수동 개입이 필요한 지점은 `docs/user-intervention.md` 에 기록.
- 테스트 정책은 `docs/testing.md` 참조 — 구현 직후 해당 테스트 작성, 커버리지 숫자 목표 없음.
