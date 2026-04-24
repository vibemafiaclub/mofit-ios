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
- `AuthGateView` — 비로그인 시 코칭 탭에 표시되는 로그인/회원가입 안내 + AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단 노출.
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

---

## 3. 데이터 모델

### 3.1 로컬 (SwiftData)

비로그인 유저 + 로그인 여부 무관한 공통 엔티티.

- `UserProfile` (싱글톤): `gender`, `height`, `weight`, `bodyType`, `goal`, `onboardingCompleted`
- `WorkoutSession`: `id`, `exerciseType`, `startedAt`, `endedAt`, `totalDuration`, `repCounts: [Int]`
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
| 운동 완료 저장 | `POST /sessions`                     | SwiftData 로컬 저장             |
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
