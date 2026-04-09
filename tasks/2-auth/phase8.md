# Phase 8: build-verify

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/code-architecture.md`
- `/tasks/2-auth/docs-diff.md` (이번 task의 문서 변경 기록)

그리고 이전 phase의 모든 작업물을 확인하라:

- `/server/` 디렉토리 전체 — Node.js 서버
- `/Mofit/Services/APIService.swift` — 서버 통신
- `/Mofit/Services/AuthManager.swift` — 인증 상태 관리
- `/Mofit/Services/KeychainService.swift` — 토큰 저장
- `/Mofit/Views/Auth/LoginView.swift` — 로그인 화면
- `/Mofit/Views/Auth/SignUpView.swift` — 회원가입 화면
- `/Mofit/Views/Coaching/CoachingView.swift` — 비로그인 안내 + 로그인 시 서버 연동
- `/Mofit/Views/Home/HomeView.swift` — 데이터 소스 분기
- `/Mofit/Views/Records/RecordsView.swift` — 데이터 소스 분기
- `/Mofit/Views/Profile/ProfileEditView.swift` — 로그아웃 + 프로필 서버 동기화
- `/Mofit/ViewModels/TrackingViewModel.swift` — 세션 저장 분기
- `/Mofit/ViewModels/CoachingViewModel.swift` — 피드백 요청 분기

## 작업 내용

전체 시스템의 빌드와 테스트를 검증하고, 발견된 문제를 수정한다.

### 1. 서버 테스트 실행

```bash
cd server && npm test
```

모든 테스트가 통과하는지 확인하라. 실패하는 테스트가 있으면 원인을 파악하고 수정하라.

### 2. iOS 빌드 검증

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

빌드가 성공하는지 확인하라. 실패하면 에러를 수정하라.

### 3. 서버 로컬 실행 확인

```bash
cd server && npm start &
sleep 2

# 회원가입
curl -s -X POST http://localhost:3000/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"verify-test@test.com","password":"test123456"}'

# 로그인
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"verify-test@test.com","password":"test123456"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# 프로필 저장
curl -s -X PUT http://localhost:3000/profile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"gender":"male","height":175,"weight":70,"bodyType":"normal","goal":"bodyShape","coachStyle":"warm"}'

# 프로필 조회
curl -s http://localhost:3000/profile \
  -H "Authorization: Bearer $TOKEN"

# 세션 생성
curl -s -X POST http://localhost:3000/sessions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"exerciseType":"squat","startedAt":"2026-04-09T12:00:00Z","endedAt":"2026-04-09T12:10:00Z","totalDuration":600,"repCounts":[12,10,8]}'

# 세션 조회
curl -s http://localhost:3000/sessions \
  -H "Authorization: Bearer $TOKEN"

# 인증 없이 접근 → 401
curl -s http://localhost:3000/profile -w "\nHTTP: %{http_code}\n"
```

각 API가 올바른 응답을 반환하는지 확인하라.

### 4. 배포된 서버 확인

```bash
cd server && railway status
```

Railway에 서버가 정상 실행 중인지 확인하라. 최근 Phase에서 서버 코드가 변경되었다면 재배포하라:

```bash
cd server && railway up
```

### 5. 테스트 데이터 정리

검증에 사용한 테스트 유저 데이터를 삭제하라.

### 6. 최종 점검 사항

다음을 확인하고 문제가 있으면 수정하라:

- [ ] `.gitignore`에 `server/.env`, `server/node_modules/`가 포함되어 있는가
- [ ] `server/.env.example`에 필요한 환경 변수가 모두 문서화되어 있는가
- [ ] iOS 앱의 서버 URL이 Railway 배포 URL로 설정되어 있는가
- [ ] `Secrets.swift`가 여전히 `.gitignore`에 포함되어 있는가
- [ ] xcodegen generate가 에러 없이 완료되는가

## Acceptance Criteria

```bash
# 1. 서버 테스트 통과
cd /Users/choesumin/Desktop/dev/mofit-ios/server && npm test

# 2. iOS 빌드 성공
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

두 커맨드 모두 성공해야 한다.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/2-auth/index.json`의 phase 8 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 이 phase에서 새로운 기능을 추가하지 마라. 기존 코드의 버그 수정과 빌드 에러 해결만 수행한다.
- 서버 로컬 실행 테스트 후 반드시 서버 프로세스를 종료하라 (`kill %1` 또는 해당 PID).
- 테스트 데이터를 반드시 정리하라. 프로덕션 DB에 테스트 데이터가 남으면 안 된다.
- 이전 phase들의 커밋을 수정(amend)하지 마라. 수정 사항은 새 커밋으로 추가한다.
