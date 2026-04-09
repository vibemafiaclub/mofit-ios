# Phase 3: server-crud

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/data-schema.md`
- `/docs/adr.md`
- `/docs/code-architecture.md`
- `/tasks/2-auth/docs-diff.md` (이번 task의 문서 변경 기록)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `/server/src/index.js` — Express 앱 설정
- `/server/src/config/db.js` — Supabase 클라이언트
- `/server/src/middleware/auth.js` — JWT 미들웨어
- `/server/src/routes/auth.js` — 인증 라우트
- `/server/src/tests/auth.test.js` — 인증 테스트

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

데이터 CRUD API와 Claude API 프록시를 구현한다. 모든 라우트는 JWT 인증 미들웨어를 적용한다.

### 1. 프로필 라우트

`/server/src/routes/profile.js`:

**`GET /profile`** (JWT 필수)
- `req.user.id`로 `user_profiles` 테이블에서 조회
- 프로필이 없으면 `404 { error: "프로필을 찾을 수 없습니다" }`
- 응답: `200 { profile: { gender, height, weight, body_type, goal, coach_style } }`

**`PUT /profile`** (JWT 필수)
- Body: `{ gender, height, weight, bodyType, goal, coachStyle }`
- camelCase → snake_case 변환하여 DB에 저장
- UPSERT: 프로필이 없으면 INSERT, 있으면 UPDATE
- `updated_at`을 현재 시간으로 갱신
- 응답: `200 { profile: { ... } }`

### 2. 세션 라우트

`/server/src/routes/sessions.js`:

**`GET /sessions`** (JWT 필수)
- Query params: `date` (optional, YYYY-MM-DD 형식)
- `date` 있으면 해당 날짜의 세션만 조회 (started_at 기준, 해당 일 00:00 ~ 다음 일 00:00)
- `date` 없으면 최근 30일 세션 조회
- `started_at` 내림차순 정렬
- 응답: `200 { sessions: [{ id, exerciseType, startedAt, endedAt, totalDuration, repCounts, createdAt }] }`
- DB의 snake_case를 camelCase로 변환하여 응답

**`POST /sessions`** (JWT 필수)
- Body: `{ exerciseType, startedAt, endedAt, totalDuration, repCounts }`
- camelCase → snake_case 변환하여 `workout_sessions` 테이블에 INSERT
- `user_id`는 `req.user.id`에서 가져옴
- 응답: `201 { session: { id, ... } }`

**`DELETE /sessions/:id`** (JWT 필수)
- `workout_sessions`에서 `id`와 `user_id` 모두 매칭하는 행 DELETE
- 다른 유저의 세션을 삭제할 수 없도록 `user_id` 조건 필수
- 삭제 대상이 없으면 `404`
- 응답: `204 No Content`

### 3. 코칭 라우트

`/server/src/routes/coaching.js`:

**`GET /coaching`** (JWT 필수)
- Query params: `date` (optional, YYYY-MM-DD)
- `date` 있으면 해당 날짜의 피드백만 조회
- `date` 없으면 최근 30일 피드백 조회
- `created_at` 내림차순 정렬
- 응답: `200 { feedbacks: [{ id, date, type, content, createdAt }] }`

**`POST /coaching/request`** (JWT 필수)
- Body: `{ prompt }` — iOS 앱에서 구성한 프롬프트 문자열
- 서버에서 Claude API 호출:
  - Endpoint: `https://api.anthropic.com/v1/messages`
  - Model: `claude-sonnet-4-6`
  - Max tokens: 1024
  - Headers: `x-api-key: CLAUDE_API_KEY`, `anthropic-version: 2023-06-01`
- 일일 사용 제한 체크: 해당 유저의 오늘 coaching_feedbacks 카운트가 2 이상이면 `429 { error: "오늘 피드백 사용 횟수를 초과했습니다" }`
- Claude 응답 성공 시:
  - `coaching_feedbacks` 테이블에 INSERT (user_id, date=오늘, type=body에서 받은 type, content=Claude 응답)
  - 응답: `201 { feedback: { id, date, type, content, createdAt } }`
- Body에 `type` 필드도 포함: `{ prompt, type }` (pre / post)

### 4. 테스트

`/server/src/tests/crud.test.js`:

각 테스트 전 테스트 유저를 signup하고 JWT를 획득하라.

**프로필 테스트:**
- PUT /profile → 200 (프로필 생성/수정)
- GET /profile → 200 (조회 성공)
- GET /profile (인증 없이) → 401

**세션 테스트:**
- POST /sessions → 201 (세션 생성)
- GET /sessions → 200 (조회, 생성한 세션 포함)
- DELETE /sessions/:id → 204 (삭제 성공)
- DELETE /sessions/:id (다른 유저의 세션) → 404

**코칭 테스트:**
- POST /coaching/request → 201 (Claude 프록시 호출 + 피드백 저장)
  - 주의: 이 테스트는 실제 Claude API를 호출한다. CLAUDE_API_KEY가 설정되어 있어야 함.
- GET /coaching → 200 (조회, 생성한 피드백 포함)

테스트 후 cleanup: 테스트에서 생성한 유저 및 관련 데이터 삭제 (CASCADE로 자동 처리).

### 5. index.js에 라우트 마운트

Phase 2에서 생성한 `/server/src/index.js`에 새 라우트를 마운트하라:

```javascript
app.use('/profile', authMiddleware, profileRouter);
app.use('/sessions', authMiddleware, sessionsRouter);
app.use('/coaching', authMiddleware, coachingRouter);
```

## Acceptance Criteria

```bash
cd server && npm test
```

기존 auth 테스트 + 새 crud 테스트 모두 통과해야 한다.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/2-auth/index.json`의 phase 3 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 응답 JSON의 키는 camelCase, DB 컬럼은 snake_case. 변환 로직을 일관되게 적용하라.
- 다른 유저의 데이터에 접근할 수 없도록 모든 쿼리에 `user_id = req.user.id` 조건을 포함하라.
- Claude API 프록시 테스트는 실제 API를 호출한다. 비용이 발생하므로 프롬프트는 최대한 짧게 사용하라.
- 일일 사용 제한 체크에서 날짜는 UTC가 아닌 요청 시점의 date(로컬 날짜)를 기준으로 하라. `coaching_feedbacks.date` 컬럼을 사용.
- Phase 2의 기존 테스트를 깨뜨리지 마라.
