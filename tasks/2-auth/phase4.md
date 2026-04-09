# Phase 4: server-deploy

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/code-architecture.md`
- `/tasks/2-auth/docs-diff.md` (이번 task의 문서 변경 기록)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `/server/src/index.js`
- `/server/package.json`
- `/server/Dockerfile`
- `/server/.env.example`

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

Railway CLI를 사용하여 서버를 배포한다.

### 1. Railway 프로젝트 설정

```bash
cd server
railway login  # 이미 로그인되어 있을 수 있음
railway init    # 또는 기존 프로젝트에 link
```

- Railway 프로젝트명: `mofit-server` (또는 기존 프로젝트가 있으면 link)

### 2. 환경 변수 설정

Railway에 필요한 환경 변수를 설정하라:

```bash
railway variables set SUPABASE_URL=<실제 Supabase URL>
railway variables set SUPABASE_SERVICE_ROLE_KEY=<실제 service role key>
railway variables set JWT_SECRET=<생성한 시크릿>
railway variables set CLAUDE_API_KEY=<실제 Claude API key>
railway variables set PORT=3000
```

- JWT_SECRET은 충분히 긴 랜덤 문자열을 생성하여 사용하라 (예: `openssl rand -hex 32`).
- 실제 값은 Supabase 대시보드와 기존 `/Mofit/Config/Secrets.swift`에서 확인 가능.

### 3. 배포

```bash
railway up
```

Railway가 Dockerfile을 감지하여 자동 빌드 및 배포한다.

### 4. 배포 확인

배포된 서버의 공개 URL을 확인하라:

```bash
railway domain
```

공개 URL이 없으면 Railway 대시보드에서 도메인을 생성하라. 또는:

```bash
railway domain add
```

### 5. 배포 후 검증

배포된 서버에 대해 기본 API 호출 테스트:

```bash
# 서버 상태 확인 (health check가 없다면 signup으로 테스트)
DEPLOY_URL=$(railway domain | head -1)

# 회원가입 테스트
curl -X POST "https://${DEPLOY_URL}/auth/signup" \
  -H "Content-Type: application/json" \
  -d '{"email":"deploy-test@test.com","password":"test123456"}' \
  -w "\nHTTP Status: %{http_code}\n"

# 로그인 테스트
curl -X POST "https://${DEPLOY_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"deploy-test@test.com","password":"test123456"}' \
  -w "\nHTTP Status: %{http_code}\n"
```

### 6. 배포 URL 기록

배포된 서버 URL을 `/server/.env.example`에 주석으로 기록하라:

```
# Railway 배포 URL: https://mofit-server-xxx.up.railway.app
```

그리고 `/docs/code-architecture.md`에도 배포 URL 섹션을 추가하라.

### 7. 테스트 데이터 정리

배포 테스트에 사용한 `deploy-test@test.com` 유저를 삭제하라 (Supabase MCP 또는 서버 API 사용).

## Acceptance Criteria

```bash
# 배포된 서버 URL로 로그인 API가 정상 응답하는지 확인
# railway domain 또는 수동으로 배포 URL을 사용하여 curl 테스트
cd server && railway status
```

Railway에 서버가 정상 배포되어 있고, API 호출이 성공해야 한다.

## AC 검증 방법

배포된 서버에 curl로 signup/login API를 호출하여 정상 응답(201/200)을 확인하라. 성공하면 `/tasks/2-auth/index.json`의 phase 4 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- Railway CLI가 설치되어 있어야 한다. 없으면 `npm install -g @railway/cli`로 설치.
- 환경 변수에 실제 시크릿을 설정한다. 이 값들은 Railway 대시보드에서만 관리되며 코드에 커밋되지 않는다.
- 배포 후 테스트 유저 데이터는 반드시 정리하라.
- 서버 로그를 확인하여 에러가 없는지 검증하라: `railway logs`.
