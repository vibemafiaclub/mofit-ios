# Phase 0: docs-update

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/adr.md`
- `/docs/code-architecture.md`
- `/docs/data-schema.md`
- `/docs/flow.md`
- `/docs/testing.md`

## 작업 내용

이번 task는 mofit-ios 앱에 Mixpanel 기반 유저 행동분석 로그를 추가하는 작업이다. 아래 내용을 반영하여 기존 문서들을 업데이트하라.

### 1. `/docs/adr.md` 업데이트

다음 ADR을 추가:

**ADR-015: Mixpanel을 유저 행동분석 도구로 채택**
- 결정: Mixpanel iOS SDK를 SPM으로 추가하여 유저 행동분석 로그를 수집한다. 이 프로젝트 최초의 외부 의존성이다.
- 이유: 행동분석에 가장 특화된 product analytics 도구. iOS SDK가 10년 이상 검증됨. 무료 20M events/month로 MVP에 충분. SPM 지원으로 project.yml에 추가하면 끝. YC 스타트업 채택률 높음.
- 트레이드오프: ADR-001의 "외부 의존성 0" 원칙에 대한 첫 예외. 행동분석은 Apple 네이티브 대안이 없으므로 불가피.
- 대안 검토: Firebase Analytics(plist 설정 복잡, CLI 완결 불가), Amplitude(행동분석 UX가 Mixpanel보다 약간 열세), PostHog(모바일 SDK 성숙도 낮음).

### 2. `/docs/code-architecture.md` 업데이트

Services 섹션에 AnalyticsService를 추가:

```
Mofit/Services/
├── AnalyticsService.swift    # Mixpanel 래퍼. 이벤트 추적, 유저 식별
```

간단한 설명:
- `AnalyticsService`는 Mixpanel SDK를 감싸는 싱글톤 서비스.
- `AnalyticsEvent` enum으로 이벤트명을 타입 안전하게 관리.
- 앱 시작 시 `MofitApp.init()`에서 초기화.
- 로그인/로그아웃 시 `identify(userId:)` / `reset()` 호출로 유저 식별.

또한 디렉토리 구조 트리에도 `AnalyticsService.swift`를 추가하라.

### 3. 다른 문서는 수정하지 않는다

- `/docs/data-schema.md` — Mixpanel은 외부 SaaS이므로 로컬/서버 스키마 변경 없음.
- `/docs/prd.md` — 유저 대면 기능이 아니므로 PRD 변경 없음.
- `/docs/flow.md` — 유저 플로우에 변화 없음.

## Acceptance Criteria

```bash
# 문서 파일들이 모두 존재하고 ADR-015가 추가되었는지 확인
grep -q "ADR-015" docs/adr.md && grep -q "AnalyticsService" docs/code-architecture.md && echo "PASS"
```

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/3-analytics/index.json`의 phase 0 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 기존 문서 내용을 삭제하지 마라. 기존 내용은 유지하고 새 섹션을 추가하라.
- 이 phase에서는 코드를 수정하지 마라. 문서만 업데이트하라.
- ADR 번호는 기존 마지막 번호(ADR-014) 다음인 015를 사용하라.
