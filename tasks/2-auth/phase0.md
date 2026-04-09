# Phase 0: docs-update

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/data-schema.md`
- `/docs/adr.md`
- `/docs/code-architecture.md`
- `/docs/flow.md`
- `/docs/testing.md`

현재 프로젝트의 기존 SwiftData 모델도 확인하라:

- `/Mofit/Models/UserProfile.swift`
- `/Mofit/Models/WorkoutSession.swift`
- `/Mofit/Models/CoachingFeedback.swift`

## 작업 내용

이번 task는 mofit-ios 앱에 로그인/회원가입 기능을 추가하는 작업이다. 아래 내용을 반영하여 기존 문서들을 업데이트하라.

### 1. `/docs/prd.md` 업데이트

다음 요구사항을 PRD에 추가:

- **인증**: 이메일+비밀번호 기반 로그인/회원가입. Apple 연동, 비밀번호 찾기 없음.
- **AI 코칭 탭 접근 제어**: 비로그인 시 "로그인 후 사용할 수 있습니다" 안내 화면 표시. 로그인/회원가입 버튼 제공.
- **데이터 저장 분기**: 로그인 유저는 서버 API를 통해 Supabase DB에 데이터 저장. 비로그인 유저는 기존 SwiftData에 로컬 저장.
- **회원가입 후 자동 로그인**: 회원가입 완료 시 해당 정보로 즉시 로그인 상태 전환.
- **로그아웃**: ProfileEditView 하단에 로그아웃 버튼 배치 (로그인 상태에서만 표시).
- **Claude API 프록시**: 기존 앱 내 직접 Claude API 호출을 서버 경유로 전환. 로그인 유저만 사용 가능.

### 2. `/docs/data-schema.md` 업데이트

서버 측 Supabase 테이블 스키마를 추가:

**`users` 테이블:**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK, default gen_random_uuid()) | 유저 고유 ID |
| email | text (UNIQUE, NOT NULL) | 이메일 (로그인 ID) |
| password_hash | text (NOT NULL) | bcrypt 해싱된 비밀번호 |
| created_at | timestamptz (default now()) | 가입 시각 |

**`user_profiles` 테이블:**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK, default gen_random_uuid()) | |
| user_id | uuid (FK → users.id, UNIQUE, NOT NULL) | |
| gender | text (NOT NULL) | male / female |
| height | double precision (NOT NULL) | cm |
| weight | double precision (NOT NULL) | kg |
| body_type | text (NOT NULL) | slim / normal / muscular / chubby |
| goal | text (NOT NULL) | weightLoss / strength / bodyShape |
| coach_style | text (NOT NULL, default 'warm') | tough / warm / analytical |
| created_at | timestamptz (default now()) | |
| updated_at | timestamptz (default now()) | |

**`workout_sessions` 테이블:**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK, default gen_random_uuid()) | |
| user_id | uuid (FK → users.id, NOT NULL) | |
| exercise_type | text (NOT NULL) | squat / pushup / situp |
| started_at | timestamptz (NOT NULL) | |
| ended_at | timestamptz (NOT NULL) | |
| total_duration | integer (NOT NULL) | 초 단위 |
| rep_counts | integer[] (NOT NULL) | 세트별 반복 수 배열 |
| created_at | timestamptz (default now()) | |

**`coaching_feedbacks` 테이블:**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK, default gen_random_uuid()) | |
| user_id | uuid (FK → users.id, NOT NULL) | |
| date | date (NOT NULL) | 피드백 날짜 |
| type | text (NOT NULL) | pre / post |
| content | text (NOT NULL) | Claude 응답 본문 |
| created_at | timestamptz (default now()) | |

인덱스:
- `workout_sessions(user_id, started_at)` — 날짜별 조회 최적화
- `coaching_feedbacks(user_id, date)` — 일일 사용량 체크 최적화

### 3. `/docs/adr.md` 업데이트

다음 ADR을 추가:

**ADR-010: 커스텀 JWT 인증 (Supabase Auth 미사용)**
- 결정: Supabase는 순수 DB로만 사용. bcrypt + JWT를 서버에서 직접 구현.
- 이유: Supabase Auth의 이메일 기반 로그인이 제공하는 기능 대비, 직접 구현이 더 간단하고 제어 가능. 의존성 최소화.
- 트레이드오프: 세션 관리, 토큰 갱신을 직접 구현해야 하지만, scope이 작아 부담 없음.

**ADR-011: 서버 아키텍처 (Node.js + Express + Railway)**
- 결정: Node.js + Express로 REST API 서버 구축, Railway에 배포.
- 이유: 단순한 CRUD + 인증 서버에 적합. Railway의 Node.js 지원이 안정적.
- 범위: 인증 (signup/login), 데이터 CRUD (profile/sessions/feedbacks), Claude API 프록시.

**ADR-012: Claude API 서버 프록시**
- 결정: 기존 앱 내 직접 Claude API 호출을 서버 경유로 전환.
- 이유: API 키가 앱 바이너리에 포함되는 보안 위험 제거. 서버에서 사용량 제어 가능.
- 변경: ClaudeAPIService는 더 이상 Anthropic API를 직접 호출하지 않음. 서버의 `/coaching/request` 엔드포인트를 호출.

**ADR-013: 로그인/비로그인 데이터 분기**
- 결정: 로그인 유저는 서버 API, 비로그인 유저는 SwiftData. 로컬→서버 마이그레이션 없음.
- 이유: 동기화 복잡도 회피. MVP 단계에서 사용자 데이터가 적음.
- 트레이드오프: 비로그인 상태에서 쌓은 데이터는 로그인해도 서버로 이전되지 않음.

**ADR-014: 네트워크 실패 시 에러 알림만 (로컬 임시 저장 없음)**
- 결정: 운동 완료 후 서버 저장 실패 시 에러 알림만 표시. 로컬 임시 저장 + 재시도 없음.
- 이유: 오프라인 동기화는 MVP scope 초과. 운동 자체는 로컬에서 완료되므로 치명적이지 않음.

### 4. `/docs/code-architecture.md` 업데이트

서버 아키텍처 섹션을 추가:

```
server/
├── src/
│   ├── index.js          # Express 앱 엔트리포인트
│   ├── config/
│   │   └── db.js         # Supabase 클라이언트 초기화
│   ├── middleware/
│   │   └── auth.js       # JWT 검증 미들웨어
│   ├── routes/
│   │   ├── auth.js       # POST /auth/signup, POST /auth/login
│   │   ├── profile.js    # GET/PUT /profile
│   │   ├── sessions.js   # GET/POST/DELETE /sessions
│   │   └── coaching.js   # GET/POST /coaching, POST /coaching/request
│   └── tests/
│       ├── setup.js      # 테스트 DB 연결 + cleanup
│       ├── auth.test.js
│       └── crud.test.js
├── package.json
├── .env.example
└── Dockerfile
```

iOS 네트워킹 레이어 섹션 추가:

```
Mofit/Services/
├── APIService.swift      # 서버 HTTP 통신 (JWT 첨부)
├── AuthManager.swift     # 로그인 상태 관리 (@Published isLoggedIn)
├── KeychainService.swift # JWT 토큰 Keychain 저장/조회/삭제
└── ClaudeAPIService.swift # (기존) → 로그인 시 서버 프록시 경유로 변경
```

### 5. `/docs/flow.md` 업데이트

다음 플로우를 추가:

**회원가입 플로우:**
1. AI 코칭 탭 → 안내 화면 → "회원가입" 버튼
2. 회원가입 화면: 이메일 + 비밀번호 + 비밀번호 확인 입력
3. "가입하기" → 서버 `POST /auth/signup` 호출
4. 성공 → JWT 토큰 저장 → 자동 로그인 → AI 코칭 화면 표시

**로그인 플로우:**
1. AI 코칭 탭 → 안내 화면 → "로그인" 버튼
2. 로그인 화면: 이메일 + 비밀번호 입력
3. "로그인" → 서버 `POST /auth/login` 호출
4. 성공 → JWT 토큰 저장 → AI 코칭 화면 표시

**로그아웃 플로우:**
1. 홈 탭 → 프로필 편집 → 하단 "로그아웃" 버튼
2. Keychain에서 토큰 삭제 → AuthManager.isLoggedIn = false
3. AI 코칭 탭 접근 시 다시 안내 화면 표시

**데이터 저장 분기 (로그인 시):**
- 운동 완료 → `POST /sessions` (서버 저장)
- AI 코칭 요청 → `POST /coaching/request` (서버 경유 Claude 호출)
- 프로필 수정 → `PUT /profile` (서버 저장)
- 기록 조회 → `GET /sessions` (서버에서 fetch)

## Acceptance Criteria

```bash
# 문서 파일들이 모두 존재하고 업데이트되었는지 확인
test -f docs/prd.md && test -f docs/data-schema.md && test -f docs/adr.md && test -f docs/code-architecture.md && test -f docs/flow.md && echo "All docs exist"
```

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/2-auth/index.json`의 phase 0 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 기존 문서 내용을 삭제하지 마라. 기존 내용은 유지하고 새 섹션을 추가하라.
- 테이블 스키마의 컬럼명은 snake_case를 사용하라 (PostgreSQL 관례).
- 이 phase에서는 코드를 수정하지 마라. 문서만 업데이트하라.
