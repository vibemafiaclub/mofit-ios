# Phase 2: server-auth

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/data-schema.md`
- `/docs/adr.md`
- `/docs/code-architecture.md`
- `/tasks/2-auth/docs-diff.md` (이번 task의 문서 변경 기록)

## 작업 내용

Node.js + Express 서버를 구축하고 인증 API를 구현한다.

### 1. 프로젝트 초기화

`/server/` 디렉토리에 Node.js 프로젝트를 생성하라.

```bash
cd server
npm init -y
npm install express @supabase/supabase-js bcryptjs jsonwebtoken cors dotenv
npm install --save-dev jest supertest
```

### 2. 환경 변수

`/server/.env.example` 파일을 생성:

```
PORT=3000
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
JWT_SECRET=your-jwt-secret-here
CLAUDE_API_KEY=sk-ant-...
```

`.gitignore`에 `/server/.env`를 추가하라. `.env.example`은 커밋한다.

### 3. Supabase 클라이언트 초기화

`/server/src/config/db.js`:
- `@supabase/supabase-js`의 `createClient`를 사용.
- `SUPABASE_URL`과 `SUPABASE_SERVICE_ROLE_KEY` 환경변수 사용.
- service_role key를 사용하므로 RLS를 bypass한다.

### 4. Express 앱 설정

`/server/src/index.js`:
- dotenv 로드
- cors 미들웨어 (모든 origin 허용 — MVP)
- JSON body parser
- 라우트 마운트: `/auth`, `/profile`, `/sessions`, `/coaching`
- 에러 핸들러 미들웨어
- `PORT` 환경변수 또는 기본 3000번 포트에서 listen
- `module.exports = app` (테스트에서 import 할 수 있도록)

### 5. JWT 미들웨어

`/server/src/middleware/auth.js`:
- `Authorization: Bearer <token>` 헤더에서 토큰 추출
- `jsonwebtoken.verify(token, JWT_SECRET)`로 검증
- 검증 성공 시 `req.user = { id, email }` 설정 후 `next()`
- 실패 시 `401 Unauthorized` 응답

### 6. 인증 라우트

`/server/src/routes/auth.js`:

**`POST /auth/signup`**
- Body: `{ email, password }`
- 이메일 형식 검증 (간단한 regex)
- 비밀번호 최소 6자 검증
- 이메일 중복 체크 (users 테이블 조회)
- `bcryptjs.hash(password, 10)`으로 해싱
- users 테이블에 INSERT
- JWT 토큰 생성: `jwt.sign({ id: user.id, email }, JWT_SECRET, { expiresIn: '30d' })`
- 응답: `201 { token, user: { id, email } }`
- 에러: `409 { error: "이미 사용 중인 이메일입니다" }`, `400 { error: "..." }`

**`POST /auth/login`**
- Body: `{ email, password }`
- users 테이블에서 email로 조회
- 존재하지 않으면 `401 { error: "이메일 또는 비밀번호가 올바르지 않습니다" }`
- `bcryptjs.compare(password, user.password_hash)`로 검증
- 실패 시 동일한 401 메시지 (보안상 이메일 존재 여부를 구분하지 않음)
- 성공 시 JWT 발급, 응답: `200 { token, user: { id, email } }`

### 7. 테스트

`/server/src/tests/setup.js`:
- 테스트 전 cleanup: users 테이블의 email이 `@test.com`으로 끝나는 행 삭제
- 테스트용 Supabase 클라이언트 export

`/server/src/tests/auth.test.js`:
- 회원가입 성공 (유효한 이메일+비밀번호 → 201 + JWT)
- 회원가입 실패: 중복 이메일 → 409
- 회원가입 실패: 비밀번호 6자 미만 → 400
- 로그인 성공: 올바른 이메일+비밀번호 → 200 + JWT
- 로그인 실패: 잘못된 비밀번호 → 401
- 로그인 실패: 존재하지 않는 이메일 → 401
- JWT 검증: 유효한 토큰으로 보호된 라우트 접근 → 성공
- JWT 검증: 잘못된 토큰 → 401

`/server/package.json`의 scripts에 추가:
```json
{
  "scripts": {
    "start": "node src/index.js",
    "test": "jest --detectOpenHandles --forceExit"
  }
}
```

### 8. Dockerfile

`/server/Dockerfile`:
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "src/index.js"]
```

## Acceptance Criteria

```bash
cd server && npm install && npm test
```

모든 테스트가 통과해야 한다.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/2-auth/index.json`의 phase 2 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 테스트에서 실제 Supabase DB를 사용한다. 프로덕션 데이터를 오염시키지 않도록, 테스트 이메일은 반드시 `@test.com` 도메인을 사용하고 cleanup을 철저히 하라.
- `.env` 파일은 커밋하지 마라. `.env.example`만 커밋.
- 로그인 실패 시 "이메일이 존재하지 않음" vs "비밀번호 틀림"을 구분하지 마라. 보안상 동일한 메시지를 반환해야 한다.
- `server/` 디렉토리에 `.gitignore`를 추가하여 `node_modules/`, `.env`를 제외하라.
- bcrypt 라운드는 10으로 설정하라 (속도와 보안의 균형).
- JWT 만료는 30일로 설정하라 (MVP에서 토큰 갱신 로직은 구현하지 않음).
