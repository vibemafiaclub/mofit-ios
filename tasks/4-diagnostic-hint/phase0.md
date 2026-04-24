# Phase 0: docs

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다.

```bash
git status --porcelain -- docs/ Mofit/ project.yml README.md
```

출력되는 파일이 있으면 이전 작업의 잔여 변경이 남아 있다는 뜻이다. 진행하지 말고 `tasks/4-diagnostic-hint/index.json`의 phase 0 status 를 `"error"`로 변경, `error_message` 필드에 `dirty working tree (docs/ | Mofit/ | project.yml | README.md)` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/mission.md`
- `docs/prd.md`
- `docs/spec.md` (§2 핵심 상태머신 — 신규 §2.5 추가 대상)
- `docs/flow.md`
- `docs/code-architecture.md` (§디렉토리 구조 Services·ViewModels 블록 주석 갱신 대상)
- `docs/adr.md` (ADR-017 직후에 ADR-018 append 대상)
- `docs/testing.md`
- `docs/user-intervention.md` (실기기 QA 절차 신규 추가 대상)
- `docs/data-schema.md` (이번 phase 수정 금지)
- `iterations/5-20260424_210420/requirement.md` (iteration 원문 읽기 전용 — 특히 §구현 스케치 UX 규칙, §CTO 승인 조건부 1~5)
- `tasks/3-squat-only-pivot/phase0.md` (바로 직전 task 의 docs phase 스타일 참고, 수정 금지)

## 작업 내용

이번 iteration(run_id: `home-workout-newbie-20s_20260424_210609`)은 "트래킹 중 rep 카운트가 안 올라갈 때 왜 안 되는지 1줄 진단 힌트 배너 제공"을 내용으로 한다. 본 phase 는 **docs 레이어에 먼저** 설계 결정을 반영한다. **실코드는 Phase 1 에서 수정한다.** 본 phase 에서는 `docs/` 하위 4개 파일만 건드리고, 다른 디렉토리는 절대 변경하지 않는다.

변경 대상 파일은 정확히 4개: `docs/adr.md`, `docs/spec.md`, `docs/code-architecture.md`, `docs/user-intervention.md`.

### 1. `docs/adr.md` — ADR-018 신규 append

파일 맨 끝(ADR-017 본문 뒤 빈 줄 포함)에 아래 블록을 **append**. ADR-018 이 `docs/adr.md` 의 최종 ADR 이 되도록 한다. ADR-001~ADR-017 본문은 **한 글자도 바꾸지 마라.**

```
### ADR-018: 트래킹 미검출 진단 힌트 (2종 고정)
**결정**: 트래킹 상태에서 최근 3초간 **양쪽(left/right) hip/knee/ankle 어느 쪽도 3조인트 모두 검출되지 않고** 현재 세션 rep 카운트가 0 이면 상단 반투명 힌트 배너를 1줄로 노출(.outOfFrame). 그 외 조건에서 하체 조인트 평균 confidence < 0.5 가 3초 지속되면 .lowLight. 우선순위 outOfFrame. 트래킹 시작 후 5초 grace. 한 세션(= TrackingView lifecycle) 내 rep 한 번이라도 카운트되면 힌트 숨김 + 이후 재표시 금지. 세트 경계에서 리셋 금지. `DiagnosticHint` enum 은 `.outOfFrame` / `.lowLight` 2종 고정.
**이유**: iter 5 설득력 시뮬(run_id: `home-workout-newbie-20s_20260424_210609`, keyman `decision: drop`, `confidence: 55`) 에서 `tech_literacy: medium` 페르소나가 `personality_notes`("3일 써보고 아니면 삭제") 조건에서 "왜 안 세어지나요?" 를 혼자 추정해야 하는 부담이 reject 사유. 가치제안 §5.2 "실패 가이드 UI 얕음" 자체 고지를 인앱에서 증명.
**트레이드오프**: 힌트 노출 레이턴시 최소 5+3=8초. 1초 슬롯마다 판정하면 false positive 과다 + 배터리 낭비. 3초 sustain 으로 프레임 튐 흡수. lowLight 임계치 0.5 는 v1 경계값, 튜닝은 실사용 데이터 누적 후 v2.
**범위**: `Mofit/Services/PoseDetectionService.swift` 에 `PoseFrameResult` struct + `detectPoseDetailed(in:)` 메서드 신규, 기존 `detectPose(in:)` + `extractJoints` 삭제. `Mofit/ViewModels/TrackingViewModel.swift` 에 `DiagnosticHint` enum(2 case), `@Published var diagnosticHint`, `private enum Diagnostic`(카피·임계치 상수), `private struct DiagnosticHintEvaluator`(Foundation 만 사용하는 pure struct) 추가. `Mofit/Views/Tracking/TrackingView.swift` 에 `hintBanner(hint:)` private subview + ZStack 오버레이 추가. 상수·카피는 TVM `private enum Diagnostic` 한 곳에만 두며 `ConfigService` 신규 레이어 금지. `DiagnosticHint` 에 third case / 프로토콜 / 전략 패턴 도입 금지.
**연계**: ADR-017 로 스쿼트 전용 포지셔닝이 확정됐으나, 진단 로직은 exercise-agnostic(`TrackingViewModel.currentReps` 및 `hasCompleteSideForSquat` 네이밍은 squat 기준 발화이나 pushup/situp 에서도 동일 임계치로 동작). 튜닝은 v2.
**테스트**: `DiagnosticHintEvaluator` 를 Foundation 외 import 없는 pure struct 로 추출, phase1 에이전트가 구현 직후 6개 시나리오(grace / sustain / 중간 회복 / rep 후 숨김 / lowLight / 우선순위) 를 코드 트레이스로 검증. `MofitTests` 타겟 신설 금지(task 0~3 전례 유지). 실기기 QA 는 merge 전 1회: (a) 정상 환경 3rep 카운트, (b) 프레임 이탈 시 3~5초 내 .outOfFrame 배너 출현. 조도 케이스 실기기 생략 가능.
```

- ADR-018 텍스트 내 `run_id`, `keyman`, `decision`, `confidence`, `personality_notes`, `tech_literacy` 는 backtick/인용부호 그대로 유지.
- "곧 지원됩니다" 같은 미래 약속 문구 금지.

### 2. `docs/spec.md` — §2.5 신규 추가

현재 §2 의 구조:

- §2.1 트래킹 상태머신
- §2.2 스쿼트 판정
- §2.3 손바닥 판정
- §2.4 카메라 파이프라인

§2.4 블록 바로 뒤(§3 데이터 모델 시작 전 `---` 구분선 앞) 에 아래 섹션을 **신규 append**. 기존 §2.1~§2.4 는 **한 글자도 바꾸지 마라.**

```
### 2.5 트래킹 진단 힌트

트래킹 상태에서 rep 카운트가 안 올라가는 원인을 1줄 배너로 안내. 2종 고정(.outOfFrame / .lowLight), ADR-018.

- **판정 조건**
  - `.outOfFrame`: **양쪽 hip/knee/ankle 중 어느 쪽도 3조인트 모두 검출되지 않은 상태** (= `SquatCounter` 가 angle 을 계산할 수 없는 조건) 가 3초 연속 지속.
  - `.lowLight`: 하체 조인트(6개 중 검출분) 평균 confidence < 0.5 가 3초 연속 지속. outOfFrame 이 아닐 때만 평가.
  - 우선순위: outOfFrame > lowLight.
- **표시 규칙**
  - 트래킹 시작 후 최소 5초 grace (카메라 안정화).
  - 한 세션(TrackingView lifecycle) 내 rep 한 번이라도 카운트되면 힌트 숨김 + 재표시 금지.
  - 세트 경계(setComplete → 다음 countdown → tracking) 에서 evaluator 상태 리셋 금지.
  - 상단 반투명 배너 형태, 하단 종료 버튼 시야 가리지 않음.
- **카피 (고정 2종)**
  - `.outOfFrame`: "전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)"
  - `.lowLight`: "조명이 어두울 수 있어요 · 실내 조명을 밝혀주세요"
- **튜닝 대상**: grace 5s, sustain 3s, lowLight confidence 0.5. 전부 `TrackingViewModel` 내 `private enum Diagnostic` 에 상수화. 운영 중 튜닝은 이 enum 만 수정.
```

### 3. `docs/code-architecture.md` — 디렉토리 트리 주석 갱신

현재 Services 블록(L36~41)에서 `PoseDetectionService.swift` 주석 한 줄:

**기존**:

```
│   ├── PoseDetectionService.swift  # VNDetectHumanBodyPoseRequest 래퍼
```

**신규** (주석만 교체):

```
│   ├── PoseDetectionService.swift  # VNDetectHumanBodyPoseRequest 래퍼. detectPoseDetailed → PoseFrameResult(joints + 하체 avg confidence + 양쪽 완전성)
```

그리고 ViewModels 블록(L32~34) 에서 `TrackingViewModel.swift` 주석 한 줄:

**기존**:

```
│   ├── TrackingViewModel.swift     # 핵심. 상태 머신 + 카메라 + 포즈 + 카운팅
```

**신규** (주석만 교체):

```
│   ├── TrackingViewModel.swift     # 핵심. 상태 머신 + 카메라 + 포즈 + 카운팅 + DiagnosticHintEvaluator(2종 힌트)
```

- 다른 줄 / 다른 블록 / §카메라 파이프라인 이하 절 / §서버 아키텍처 이하 절 전부 불변.

### 4. `docs/user-intervention.md` — 실기기 QA 절차 추가

현재 `## 현재 등록된 절차` 섹션 본문:

```
_(없음 — 하네스가 실행되며 필요한 개입이 발견될 때마다 plan-and-build skill 이 이 파일에 항목을 추가한다.)_
```

이 문단을 **삭제** 하고 그 자리에 아래 항목 하나를 삽입:

```
### 트래킹 진단 힌트 실기기 QA (ADR-018)

- **트리거**: task `4-diagnostic-hint` 의 PR merge 직전 1회.
- **이유**: Vision 기반 포즈 검출은 시뮬레이터에서 카메라 입력을 재현할 수 없어 실기기에서만 검증 가능. CTO 승인 조건부 #5.
- **절차**:
  1. 실기기(iPhone, iOS 17+) 에서 앱 실행 → 홈 → "스쿼트 시작" 탭 → 5초 카운트다운 → 트래킹 진입.
  2. 정상 환경(밝은 실내, 2~3m 거리, 전신이 프레임에 들어옴) 에서 스쿼트 3회 수행. **3회가 그대로 카운트되어야 한다**.
  3. 이어서 일부러 프레임 밖으로 나가 3~5초 정지. **상단에 "전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)" 배너가 출현해야 한다**.
  4. 프레임으로 돌아와 세트 종료(탭 또는 손바닥 1초). 결과 화면에 세트/rep 기록이 정상 저장되는지 확인.
  5. 조도(lowLight) 케이스는 실기기 검증 생략 가능(임계치 로직은 phase 1 에이전트의 코드 트레이스 시나리오로 커버).
- **재개 신호**: 사용자가 에이전트에게 "QA OK" 라고 알려주면 merge 승인. 실패 시 재현 조건과 화면을 공유하고 phase 1 재실행.
- **기록 위치**: PR 설명에 QA 수행 일시와 결과(a/b 각각 pass/fail) 기록.
```

- 템플릿(§0) 과 주의(§Secrets / App Store / Supabase) 블록은 전부 유지. 다른 문단 건드리지 마라.

### 5. 무변경 강제 — 전체 목록

- `docs/mission.md`, `docs/prd.md`, `docs/flow.md`, `docs/data-schema.md`, `docs/testing.md` — 불변.
- `iterations/5-20260424_210420/**` — iteration 산출물. 읽기 전용.
- `persuasion-data/**` — 설득력 검토 산출물. 읽기 전용.
- `Mofit/**`, `project.yml`, `scripts/**`, `server/**`, `README.md`, `tasks/0-exercise-coming-soon/**`, `tasks/1-coaching-samples/**`, `tasks/2-tap-fallback/**`, `tasks/3-squat-only-pivot/**` — Phase 0 에서 변경 절대 금지.
- 신규 docs 파일 생성 금지. 새 마크다운 생성 금지.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다. 각 커맨드는 문자열이 정확히 일치하지 않으면 실패한다.

```bash
# 1) adr.md — ADR-018 신규, ADR-017 이후 맨 끝에 위치
grep -F "### ADR-018: 트래킹 미검출 진단 힌트 (2종 고정)" docs/adr.md
grep -F "home-workout-newbie-20s_20260424_210609" docs/adr.md
grep -F "DiagnosticHintEvaluator" docs/adr.md
grep -F "MofitTests" docs/adr.md
! grep -F "### ADR-019" docs/adr.md

# 2) spec.md — §2.5 신규 섹션 + 카피 2종 존재
grep -F "### 2.5 트래킹 진단 힌트" docs/spec.md
grep -F "전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)" docs/spec.md
grep -F "조명이 어두울 수 있어요 · 실내 조명을 밝혀주세요" docs/spec.md
grep -F "양쪽 hip/knee/ankle 중 어느 쪽도 3조인트 모두 검출되지 않은" docs/spec.md

# 3) code-architecture.md — 주석 갱신
grep -F "PoseFrameResult" docs/code-architecture.md
grep -F "DiagnosticHintEvaluator" docs/code-architecture.md

# 4) user-intervention.md — 실기기 QA 절차 추가 + "없음" 문단 제거
grep -F "### 트래킹 진단 힌트 실기기 QA (ADR-018)" docs/user-intervention.md
grep -F "전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)" docs/user-intervention.md
! grep -F "_(없음 — 하네스가 실행되며" docs/user-intervention.md

# 5) 변경 범위 — docs/ 하위 정확히 4개 파일
CHANGED=$(git diff --name-only HEAD -- docs/ | sort)
EXPECTED=$(printf 'docs/adr.md\ndocs/code-architecture.md\ndocs/spec.md\ndocs/user-intervention.md\n' | sort)
test "$CHANGED" = "$EXPECTED"

# 6) docs/ 외부 미변경
test -z "$(git diff --name-only HEAD -- Mofit/ project.yml README.md server/ scripts/ iterations/ persuasion-data/ tasks/0-exercise-coming-soon/ tasks/1-coaching-samples/ tasks/2-tap-fallback/ tasks/3-squat-only-pivot/)"

# 7) docs/mission.md, docs/prd.md, docs/flow.md, docs/data-schema.md, docs/testing.md 미변경
git diff --quiet HEAD -- docs/mission.md docs/prd.md docs/flow.md docs/data-schema.md docs/testing.md
```

(테스트 target 없음. 이 phase 는 docs only 이므로 xcodebuild 는 Phase 1 에서만 수행.)

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/4-diagnostic-hint/index.json` 의 phase 0 status 를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

## 주의사항

- **수정 대상은 정확히 4개 파일** (`docs/adr.md`, `docs/spec.md`, `docs/code-architecture.md`, `docs/user-intervention.md`). 이 외 파일 변경 금지. AC #5 가 엄격히 검증한다.
- **ADR-017 본문은 수정 금지.** ADR-018 은 append 만. ADR-008/016 의 SUPERSEDED 헤더도 그대로 유지.
- **미래 약속 문구 금지** ("곧 지원", "로드맵", "출시 예정", "차기 버전", "준비중" 등). docs/ 어디에도 새로 삽입하지 마라.
- **Mofit/ 디렉토리 및 project.yml 수정 금지.** 실코드 변경은 Phase 1.
- **xcodeproj 재생성 금지.** `xcodegen generate` 는 Phase 1 에서만 실행.
- **신규 docs 파일 생성 금지.** 기존 4개 파일만 편집.
- **testing.md, data-schema.md 수정 금지.** 이번 티켓과 별개.
- **user-intervention.md 의 템플릿(§0) + 주의(§Secrets / App Store / Supabase) 블록 불변.** "현재 등록된 절차" 안의 "없음" 문단만 교체.
- **AC grep 은 정확 문자열 기준.** 공백·따옴표·괄호 유니코드 변형 금지. 특히 큰따옴표(`"`) vs 한글 따옴표(`"` `"`) 혼동 주의. 배너 카피의 `·` 는 `U+00B7 MIDDLE DOT` 가 아니라 한글 문장부호 가운뎃점(`·`) 을 그대로 복사해 붙일 것(이 파일 본문의 문자를 그대로 사용).
- **spec.md §2.5 의 `·` 와 user-intervention.md 의 카피 `·` 는 동일 문자로 통일.** 양쪽을 이 phase 파일 본문에서 복사-붙여넣기 하라. 정확히 일치해야 Phase 1 의 TVM 상수 리터럴과도 일치한다.
