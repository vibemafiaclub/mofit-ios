# Phase 1: db-schema

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/data-schema.md`
- `/docs/adr.md`
- `/docs/code-architecture.md`
- `/tasks/2-auth/docs-diff.md` (이번 task의 문서 변경 기록)

## 작업 내용

Supabase MCP를 사용하여 데이터베이스 테이블을 생성한다. `/docs/data-schema.md`에 정의된 스키마를 그대로 따른다.

### 1. 테이블 생성

아래 순서로 테이블을 생성하라 (FK 의존성 순서):

**Step 1: `users` 테이블**
```sql
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  created_at timestamptz DEFAULT now()
);
```

**Step 2: `user_profiles` 테이블**
```sql
CREATE TABLE user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  gender text NOT NULL,
  height double precision NOT NULL,
  weight double precision NOT NULL,
  body_type text NOT NULL,
  goal text NOT NULL,
  coach_style text NOT NULL DEFAULT 'warm',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

**Step 3: `workout_sessions` 테이블**
```sql
CREATE TABLE workout_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exercise_type text NOT NULL,
  started_at timestamptz NOT NULL,
  ended_at timestamptz NOT NULL,
  total_duration integer NOT NULL,
  rep_counts integer[] NOT NULL,
  created_at timestamptz DEFAULT now()
);
```

**Step 4: `coaching_feedbacks` 테이블**
```sql
CREATE TABLE coaching_feedbacks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date date NOT NULL,
  type text NOT NULL,
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);
```

### 2. 인덱스 생성

```sql
CREATE INDEX idx_workout_sessions_user_date ON workout_sessions(user_id, started_at);
CREATE INDEX idx_coaching_feedbacks_user_date ON coaching_feedbacks(user_id, date);
```

### 3. Supabase MCP 사용법

- `mcp__supabase__execute_sql` 또는 `mcp__supabase__apply_migration`을 사용하여 SQL을 실행하라.
- 먼저 `mcp__supabase__list_projects`로 프로젝트를 확인하고, 해당 프로젝트에 대해 SQL을 실행하라.
- 각 테이블 생성 후 `mcp__supabase__list_tables`로 테이블이 정상 생성되었는지 확인하라.

### 4. 테스트용 브랜치 DB 생성

- `mcp__supabase__create_branch`를 사용하여 `test` 브랜치를 생성하라.
- 이 브랜치는 서버 테스트(Phase 2, 3)에서 `NODE_ENV=test`일 때 사용된다.
- 브랜치 DB URL을 기록해두라 (Phase 2에서 `.env.test`에 사용).

## Acceptance Criteria

```bash
# Supabase MCP로 테이블 목록을 조회하여 4개 테이블이 모두 존재하는지 확인
# mcp__supabase__list_tables 호출 결과에 users, user_profiles, workout_sessions, coaching_feedbacks가 모두 포함되어야 함
```

MCP 도구를 사용하여 테이블 목록을 조회하고, 4개 테이블이 모두 존재하는지 확인하라.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/2-auth/index.json`의 phase 1 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- RLS(Row Level Security)는 사용하지 않는다. 서버가 service_role key로 접근하므로 RLS가 불필요하다.
- 테이블명은 복수형 snake_case를 사용하라 (users, user_profiles, workout_sessions, coaching_feedbacks).
- FK에 `ON DELETE CASCADE`를 반드시 설정하라. 유저 삭제 시 관련 데이터가 함께 삭제되어야 한다.
- `IF NOT EXISTS`를 사용하여 멱등성을 보장하라.
