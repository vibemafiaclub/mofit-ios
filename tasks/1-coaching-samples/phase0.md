# Phase 0: docs

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/mission.md`
- `docs/prd.md`
- `docs/spec.md` (특히 §1.3 화면 목록)
- `docs/adr.md` (특히 ADR-005, ADR-012, ADR-013, ADR-015 — AI 코칭/인증/Analytics 관련)
- `docs/code-architecture.md` (`Views/Coaching/` 폴더 규칙)
- `docs/flow.md`
- `docs/testing.md`
- `docs/user-intervention.md`
- `iterations/2-20260424_155909/requirement.md` (이번 iteration 원문 — 수정 금지)

## 작업 내용

이번 iteration의 UI 변경을 문서 레이어에 먼저 반영한다. **실코드는 Phase 1에서 수정한다.**
본 phase에서는 `docs/`만 건드리고, 다른 디렉토리는 절대 변경하지 않는다.

### 1. `docs/spec.md` — §1.3 화면 목록의 `AuthGateView` 라인 (현재 L37)

**기존**:
```markdown
- `AuthGateView` — 비로그인 시 코칭 탭에 표시되는 로그인/회원가입 안내
```

**신규** (아래 한 줄로 정확히 교체):
```markdown
- `AuthGateView` — 비로그인 시 코칭 탭에 표시되는 로그인/회원가입 안내 + AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단 노출.
```

수정 범위는 **L37 한 줄**로 한정한다. 다른 줄은 어절 한 개도 바꾸지 마라.

### 2. ADR 신규 작성 여부

**ADR 신규 작성 금지.** 이번 변경(정적 UI 카피 2종 하드코딩)은 "번복 비용 거의 0"인 결정이라 ADR 표면적에 올리지 않는다(CTO 결재 반영). `docs/adr.md`는 건드리지 마라.

### 3. 건드리지 말 것 — 전체 목록

- `docs/prd.md` — 랜딩/미팅 용도 문서. 출시 전 랜딩 카피 추가 금지.
- `docs/code-architecture.md` — 폴더 트리 문서. `Views/Coaching/` 하위 신규 파일 추가는 트리 자체를 바꾸지 않으므로 무변경.
- `docs/adr.md` — ADR 신규 작성 금지(CTO 결재).
- `docs/user-intervention.md` — 이번 변경으로 새로 발생한 인간 개입 지점 없음. 무변경.
- `docs/data-schema.md`, `docs/flow.md`, `docs/mission.md`, `docs/testing.md` — 무변경.
- `iterations/2-20260424_155909/requirement.md` — iteration 산출물. 수정 금지.
- `Mofit/**`, `project.yml`, `scripts/`, `server/`, `tasks/0-exercise-coming-soon/**` — Phase 0에서 코드/설정/타 task 변경 절대 금지.

### 4. 문구 일관성 (Phase 1 구현과 1:1 일치)

Phase 1이 Swift 리터럴로 박을 문구는 아래와 같다. 본 phase에서 작성하는 spec.md의 해당 문구가 Phase 1 리터럴과 **의미 동등**해야 한다("AI 코칭 샘플 피드백 카드 2장" 표현이 spec.md에 존재).

| 항목             | 리터럴 값                                                  |
| ---------------- | ---------------------------------------------------------- |
| 섹션 제목        | `이런 피드백을 받게 됩니다`                                |
| 고지 문구        | `※ 예시 피드백 (실제 데이터 기반으로 매번 다름)`            |
| 샘플 A (pre)     | `지난 주 3일 운동 · 총 78회 스쿼트 · 일평균 26회. 수요일엔 38회 최다였고 금요일 0회였네요. 오늘은 수요일 페이스 회복해서 30회 이상 도전해보세요.` |
| 샘플 B (post)    | `오늘 3세트 총 32회. 1세트 14회 → 2세트 10회 → 3세트 8회. 세트별 감소폭 4회로 피로도 자연스러운 곡선. 내일은 2세트째에서 쉬는 시간 20초 늘려보세요.` |
| 샘플 개수        | 정확히 2종. 3종 이상 금지.                                  |

(Phase 1은 이 표를 원본으로 삼아 Swift 리터럴을 작성한다. 본 phase는 spec.md 한 줄만 갱신.)

## Acceptance Criteria

아래 커맨드를 모두 실행하고 지정된 결과가 나와야 한다. Bash에서 실행.

```bash
# 1) spec.md에 신규 문구 존재
grep -F "AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단 노출." docs/spec.md

# 2) 변경 범위가 docs/spec.md 단일 파일
test "$(git diff --name-only HEAD -- docs/)" = "docs/spec.md"

# 3) docs 외부 미변경
git diff --name-only HEAD -- Mofit/ project.yml scripts/ server/ iterations/ tasks/0-exercise-coming-soon/ ; test -z "$(git diff --name-only HEAD -- Mofit/ project.yml scripts/ server/ iterations/ tasks/0-exercise-coming-soon/)"

# 4) adr.md 미변경 (ADR 신규 작성 금지 확인)
git diff --quiet HEAD -- docs/adr.md

# 5) spec.md 다른 라인 보존 — AuthGateView 줄이 단 한 번만 존재
test "$(grep -c '^- \`AuthGateView\`' docs/spec.md)" -eq 1
```

(테스트 target 없음. 이 phase는 docs only이므로 xcodebuild는 Phase 1에서만 수행.)

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/1-coaching-samples/index.json`의 phase 0 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

## 주의사항

- **ADR 신규 작성 금지.** CTO가 "번복 비용 0인 UI 카피 하드코딩은 ADR에 올리지 않는다"고 결재. `docs/adr.md` 절대 수정 금지.
- **spec.md 수정 범위는 L37 한 줄로 한정.** 다른 화면 목록 엔트리, 다른 섹션 제목, 공백/줄바꿈도 바꾸지 마라.
- **requirement.md 읽기 전용.** iteration 디렉토리 하위 수정 금지.
- **Mofit/ 디렉토리 및 project.yml 수정 금지.** 이 phase는 docs-only 변경.
- **새 docs 파일 생성 금지.** `docs/` 내 기존 `spec.md` 1개만 편집.
- **user-intervention.md 항목 추가 금지.** 본 iteration에서 새로 발생한 인간 개입 지점이 없음.
- **tasks/0-exercise-coming-soon/ 건드리지 마라.** 완료된 이전 task.
