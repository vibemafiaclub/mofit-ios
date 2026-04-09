# docs-diff: auth

Baseline: `b25578f`

## `docs/adr.md`

```diff
diff --git a/docs/adr.md b/docs/adr.md
index 43a0378..db695d1 100644
--- a/docs/adr.md
+++ b/docs/adr.md
@@ -47,3 +47,27 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 - 세트 완료 진동 → 촉각 피드백은 후순위
 - 앱 종료 시 운동 데이터 복구 → 복잡도 대비 발생 빈도 낮음
 - SwiftData 마이그레이션 → 출시 전 스키마 확정으로 회피
+
+### ADR-010: 커스텀 JWT 인증 (Supabase Auth 미사용)
+**결정**: Supabase는 순수 DB로만 사용. bcrypt + JWT를 서버에서 직접 구현.
+**이유**: Supabase Auth의 이메일 기반 로그인이 제공하는 기능 대비, 직접 구현이 더 간단하고 제어 가능. 의존성 최소화.
+**트레이드오프**: 세션 관리, 토큰 갱신을 직접 구현해야 하지만, scope이 작아 부담 없음.
+
+### ADR-011: 서버 아키텍처 (Node.js + Express + Railway)
+**결정**: Node.js + Express로 REST API 서버 구축, Railway에 배포.
+**이유**: 단순한 CRUD + 인증 서버에 적합. Railway의 Node.js 지원이 안정적.
+**범위**: 인증 (signup/login), 데이터 CRUD (profile/sessions/feedbacks), Claude API 프록시.
+
+### ADR-012: Claude API 서버 프록시
+**결정**: 기존 앱 내 직접 Claude API 호출을 서버 경유로 전환.
+**이유**: API 키가 앱 바이너리에 포함되는 보안 위험 제거. 서버에서 사용량 제어 가능.
+**변경**: ClaudeAPIService는 더 이상 Anthropic API를 직접 호출하지 않음. 서버의 `/coaching/request` 엔드포인트를 호출.
+
+### ADR-013: 로그인/비로그인 데이터 분기
+**결정**: 로그인 유저는 서버 API, 비로그인 유저는 SwiftData. 로컬→서버 마이그레이션 없음.
+**이유**: 동기화 복잡도 회피. MVP 단계에서 사용자 데이터가 적음.
+**트레이드오프**: 비로그인 상태에서 쌓은 데이터는 로그인해도 서버로 이전되지 않음.
+
+### ADR-014: 네트워크 실패 시 에러 알림만 (로컬 임시 저장 없음)
+**결정**: 운동 완료 후 서버 저장 실패 시 에러 알림만 표시. 로컬 임시 저장 + 재시도 없음.
+**이유**: 오프라인 동기화는 MVP scope 초과. 운동 자체는 로컬에서 완료되므로 치명적이지 않음.
```

## `docs/code-architecture.md`

```diff
diff --git a/docs/code-architecture.md b/docs/code-architecture.md
index 5d1bed0..e743c7f 100644
--- a/docs/code-architecture.md
+++ b/docs/code-architecture.md
@@ -84,3 +84,43 @@ any state → (stop btn) → saveRecord → home
 
 ## 화면 자동 잠금
 트래킹 화면 진입 시 `UIApplication.shared.isIdleTimerDisabled = true`, 퇴장 시 복원.
+
+---
+
+## 서버 아키텍처
+
+로그인 유저 데이터 저장 및 Claude API 프록시를 위한 백엔드 서버.
+
+```
+server/
+├── src/
+│   ├── index.js          # Express 앱 엔트리포인트
+│   ├── config/
+│   │   └── db.js         # Supabase 클라이언트 초기화
+│   ├── middleware/
+│   │   └── auth.js       # JWT 검증 미들웨어
+│   ├── routes/
+│   │   ├── auth.js       # POST /auth/signup, POST /auth/login
+│   │   ├── profile.js    # GET/PUT /profile
+│   │   ├── sessions.js   # GET/POST/DELETE /sessions
+│   │   └── coaching.js   # GET/POST /coaching, POST /coaching/request
+│   └── tests/
+│       ├── setup.js      # 테스트 DB 연결 + cleanup
+│       ├── auth.test.js
+│       └── crud.test.js
+├── package.json
+├── .env.example
+└── Dockerfile
+```
+
+## iOS 네트워킹 레이어
+
+로그인 유저를 위한 서버 통신 레이어.
+
+```
+Mofit/Services/
+├── APIService.swift      # 서버 HTTP 통신 (JWT 첨부)
+├── AuthManager.swift     # 로그인 상태 관리 (@Published isLoggedIn)
+├── KeychainService.swift # JWT 토큰 Keychain 저장/조회/삭제
+└── ClaudeAPIService.swift # (기존) → 로그인 시 서버 프록시 경유로 변경
+```
```

## `docs/data-schema.md`

```diff
diff --git a/docs/data-schema.md b/docs/data-schema.md
index 533eed5..0afc870 100644
--- a/docs/data-schema.md
+++ b/docs/data-schema.md
@@ -49,3 +49,57 @@ Claude API 호출 시 넘기는 데이터:
 추이 (일별): { rep[], 세트수[], 세트당평균rep[] }
 ```
 토큰 절약을 위해 7일로 제한. 추이 데이터로 AI가 경향성 기반 조언 가능.
+
+---
+
+## 서버 측 스키마 (Supabase PostgreSQL)
+
+로그인 유저의 데이터는 Supabase DB에 저장된다. 비로그인 유저는 기존 SwiftData(로컬) 사용.
+
+### `users` 테이블
+| 컬럼 | 타입 | 설명 |
+|------|------|------|
+| id | uuid (PK, default gen_random_uuid()) | 유저 고유 ID |
+| email | text (UNIQUE, NOT NULL) | 이메일 (로그인 ID) |
+| password_hash | text (NOT NULL) | bcrypt 해싱된 비밀번호 |
+| created_at | timestamptz (default now()) | 가입 시각 |
+
+### `user_profiles` 테이블
+| 컬럼 | 타입 | 설명 |
+|------|------|------|
+| id | uuid (PK, default gen_random_uuid()) | |
+| user_id | uuid (FK → users.id, UNIQUE, NOT NULL) | |
+| gender | text (NOT NULL) | male / female |
+| height | double precision (NOT NULL) | cm |
+| weight | double precision (NOT NULL) | kg |
+| body_type | text (NOT NULL) | slim / normal / muscular / chubby |
+| goal | text (NOT NULL) | weightLoss / strength / bodyShape |
+| coach_style | text (NOT NULL, default 'warm') | tough / warm / analytical |
+| created_at | timestamptz (default now()) | |
+| updated_at | timestamptz (default now()) | |
+
+### `workout_sessions` 테이블
+| 컬럼 | 타입 | 설명 |
+|------|------|------|
+| id | uuid (PK, default gen_random_uuid()) | |
+| user_id | uuid (FK → users.id, NOT NULL) | |
+| exercise_type | text (NOT NULL) | squat / pushup / situp |
+| started_at | timestamptz (NOT NULL) | |
+| ended_at | timestamptz (NOT NULL) | |
+| total_duration | integer (NOT NULL) | 초 단위 |
+| rep_counts | integer[] (NOT NULL) | 세트별 반복 수 배열 |
+| created_at | timestamptz (default now()) | |
+
+### `coaching_feedbacks` 테이블
+| 컬럼 | 타입 | 설명 |
+|------|------|------|
+| id | uuid (PK, default gen_random_uuid()) | |
+| user_id | uuid (FK → users.id, NOT NULL) | |
+| date | date (NOT NULL) | 피드백 날짜 |
+| type | text (NOT NULL) | pre / post |
+| content | text (NOT NULL) | Claude 응답 본문 |
+| created_at | timestamptz (default now()) | |
+
+### 인덱스
+- `workout_sessions(user_id, started_at)` — 날짜별 조회 최적화
+- `coaching_feedbacks(user_id, date)` — 일일 사용량 체크 최적화
```

## `docs/flow.md`

```diff
diff --git a/docs/flow.md b/docs/flow.md
index 6fa6438..5726bd0 100644
--- a/docs/flow.md
+++ b/docs/flow.md
@@ -65,3 +65,52 @@ AI코칭탭
   → true: 홈탭
   → false: 온보딩
 ```
+
+---
+
+## 7. 회원가입 플로우
+```
+AI 코칭 탭 → 안내 화면 ("로그인 후 사용할 수 있습니다")
+  → "회원가입" 버튼 탭
+  → 회원가입 화면: 이메일 + 비밀번호 + 비밀번호 확인 입력
+  → "가입하기" 탭
+  → 서버 POST /auth/signup 호출
+  → 성공: JWT 토큰 Keychain 저장 → 자동 로그인 → AI 코칭 화면 표시
+  → 실패: 에러 메시지 표시 (이메일 중복 등)
+```
+
+## 8. 로그인 플로우
+```
+AI 코칭 탭 → 안내 화면 ("로그인 후 사용할 수 있습니다")
+  → "로그인" 버튼 탭
+  → 로그인 화면: 이메일 + 비밀번호 입력
+  → "로그인" 탭
+  → 서버 POST /auth/login 호출
+  → 성공: JWT 토큰 Keychain 저장 → AI 코칭 화면 표시
+  → 실패: 에러 메시지 표시 (이메일/비밀번호 불일치)
+```
+
+## 9. 로그아웃 플로우
+```
+홈탭 → 우상단 프로필 버튼
+  → 프로필 편집 화면
+  → 하단 "로그아웃" 버튼 탭 (로그인 상태에서만 표시)
+  → Keychain에서 JWT 토큰 삭제
+  → AuthManager.isLoggedIn = false
+  → AI 코칭 탭 접근 시 다시 안내 화면 표시
+```
+
+## 10. 데이터 저장 분기 (로그인 시)
+```
+로그인 상태 체크 (AuthManager.isLoggedIn)
+  → true (로그인):
+      운동 완료 → POST /sessions (서버 저장)
+      AI 코칭 요청 → POST /coaching/request (서버 경유 Claude 호출)
+      프로필 수정 → PUT /profile (서버 저장)
+      기록 조회 → GET /sessions (서버에서 fetch)
+  → false (비로그인):
+      운동 완료 → SwiftData 로컬 저장
+      AI 코칭 → 사용 불가 (안내 화면)
+      프로필 수정 → SwiftData 로컬 저장
+      기록 조회 → SwiftData에서 fetch
+```
```

## `docs/prd.md`

```diff
diff --git a/docs/prd.md b/docs/prd.md
index 916857a..629bdf1 100644
--- a/docs/prd.md
+++ b/docs/prd.md
@@ -65,6 +65,30 @@ MVP를 빠르게 출시하여 시장 반응을 검증한다 (YC 지원 대상).
 - 무채색 + 포인트 색상: 형광초록
 - 탭바 3개: 홈 / 기록 / AI코칭 (SF Symbols, 선택 시 형광초록)
 
+## 인증 및 데이터 저장
+
+### 인증
+- 이메일 + 비밀번호 기반 로그인/회원가입
+- Apple 연동 없음, 비밀번호 찾기 없음
+- 회원가입 완료 시 해당 정보로 즉시 로그인 상태 전환 (자동 로그인)
+
+### AI 코칭 탭 접근 제어
+- 비로그인 시 "로그인 후 사용할 수 있습니다" 안내 화면 표시
+- 로그인/회원가입 버튼 제공
+
+### 데이터 저장 분기
+- 로그인 유저: 서버 API를 통해 Supabase DB에 데이터 저장
+- 비로그인 유저: 기존 SwiftData에 로컬 저장
+- 로컬 → 서버 데이터 마이그레이션 없음
+
+### 로그아웃
+- ProfileEditView 하단에 로그아웃 버튼 배치
+- 로그인 상태에서만 표시
+
+### Claude API 프록시
+- 기존 앱 내 직접 Claude API 호출을 서버 경유로 전환
+- 로그인 유저만 사용 가능
+
 ## MVP 제외 사항
 - 카메라 미인식 안내, 세트 완료 진동, 폰 위치 가이드
 - 앱 강제종료 시 운동 데이터 복구
```
