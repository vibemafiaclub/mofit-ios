# docs-diff: diagnostic-hint

Baseline: `32437e7`

## `docs/adr.md`

```diff
diff --git a/docs/adr.md b/docs/adr.md
index 1471358..9bdc6f5 100644
--- a/docs/adr.md
+++ b/docs/adr.md
@@ -90,3 +90,11 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 **이유**: iter 4 설득력 검토(run_id: home-workout-newbie-20s_20260424_193756)에서 "홈트 기대 설치 → 3일 안에 스쿼트 전용임 인지 → 무료 스쿼트 카운터로 전환" 이탈 경로가 keyman 최종 판정 실패의 독립적 reject 사유. "준비중" UI 를 남겨두는 것만으로도 `personality_notes`("3일 써보고 아니면 삭제") + `switching_cost: low` 경쟁재 조건에서 기대 불일치가 드러남. 포지셔닝 자체를 스쿼트 전용으로 좁혀 기대-실제 갭을 제거.
 **트레이드오프**: 푸쉬업/싯업 확장 시 운동 종류 선택 UI/상태를 복구해야 함. 단, `TrackingViewModel.exerciseType` 분기 + `PushUpCounter.swift`/`SitUpCounter.swift` 내부 판정 자산은 보존(CTO 조건부 #1)하여 재활성화 비용 최소화. 이번 삭제는 View 레이어 한정.
 **범위**: `Mofit/Views/Home/ExercisePickerView.swift` 파일 삭제, `Mofit/Views/Home/HomeView.swift` 에서 `exerciseSelector`·`showExercisePicker`·`selectedExerciseName` 상태 제거. `TrackingView(exerciseType: "squat", ...)` 호출로 하드코딩. ADR-008/ADR-016 은 SUPERSEDED 표기 유지(역사 보존).
+
+### ADR-018: 트래킹 미검출 진단 힌트 (2종 고정)
+**결정**: 트래킹 상태에서 최근 3초간 **양쪽(left/right) hip/knee/ankle 어느 쪽도 3조인트 모두 검출되지 않고** 현재 세션 rep 카운트가 0 이면 상단 반투명 힌트 배너를 1줄로 노출(.outOfFrame). 그 외 조건에서 하체 조인트 평균 confidence < 0.5 가 3초 지속되면 .lowLight. 우선순위 outOfFrame. 트래킹 시작 후 5초 grace. 한 세션(= TrackingView lifecycle) 내 rep 한 번이라도 카운트되면 힌트 숨김 + 이후 재표시 금지. 세트 경계에서 리셋 금지. `DiagnosticHint` enum 은 `.outOfFrame` / `.lowLight` 2종 고정.
+**이유**: iter 5 설득력 시뮬(run_id: `home-workout-newbie-20s_20260424_210609`, keyman `decision: drop`, `confidence: 55`) 에서 `tech_literacy: medium` 페르소나가 `personality_notes`("3일 써보고 아니면 삭제") 조건에서 "왜 안 세어지나요?" 를 혼자 추정해야 하는 부담이 reject 사유. 가치제안 §5.2 "실패 가이드 UI 얕음" 자체 고지를 인앱에서 증명.
+**트레이드오프**: 힌트 노출 레이턴시 최소 5+3=8초. 1초 슬롯마다 판정하면 false positive 과다 + 배터리 낭비. 3초 sustain 으로 프레임 튐 흡수. lowLight 임계치 0.5 는 v1 경계값, 튜닝은 실사용 데이터 누적 후 v2.
+**범위**: `Mofit/Services/PoseDetectionService.swift` 에 `PoseFrameResult` struct + `detectPoseDetailed(in:)` 메서드 신규, 기존 `detectPose(in:)` + `extractJoints` 삭제. `Mofit/ViewModels/TrackingViewModel.swift` 에 `DiagnosticHint` enum(2 case), `@Published var diagnosticHint`, `private enum Diagnostic`(카피·임계치 상수), `private struct DiagnosticHintEvaluator`(Foundation 만 사용하는 pure struct) 추가. `Mofit/Views/Tracking/TrackingView.swift` 에 `hintBanner(hint:)` private subview + ZStack 오버레이 추가. 상수·카피는 TVM `private enum Diagnostic` 한 곳에만 두며 `ConfigService` 신규 레이어 금지. `DiagnosticHint` 에 third case / 프로토콜 / 전략 패턴 도입 금지.
+**연계**: ADR-017 로 스쿼트 전용 포지셔닝이 확정됐으나, 진단 로직은 exercise-agnostic(`TrackingViewModel.currentReps` 및 `hasCompleteSideForSquat` 네이밍은 squat 기준 발화이나 pushup/situp 에서도 동일 임계치로 동작). 튜닝은 v2.
+**테스트**: `DiagnosticHintEvaluator` 를 Foundation 외 import 없는 pure struct 로 추출, phase1 에이전트가 구현 직후 6개 시나리오(grace / sustain / 중간 회복 / rep 후 숨김 / lowLight / 우선순위) 를 코드 트레이스로 검증. `MofitTests` 타겟 신설 금지(task 0~3 전례 유지). 실기기 QA 는 merge 전 1회: (a) 정상 환경 3rep 카운트, (b) 프레임 이탈 시 3~5초 내 .outOfFrame 배너 출현. 조도 케이스 실기기 생략 가능.
```

## `docs/code-architecture.md`

```diff
diff --git a/docs/code-architecture.md b/docs/code-architecture.md
index ea3ff9e..bb1539e 100644
--- a/docs/code-architecture.md
+++ b/docs/code-architecture.md
@@ -30,11 +30,11 @@ Mofit/
 │       └── ProfileEditView.swift
 │
 ├── ViewModels/
-│   ├── TrackingViewModel.swift     # 핵심. 상태 머신 + 카메라 + 포즈 + 카운팅
+│   ├── TrackingViewModel.swift     # 핵심. 상태 머신 + 카메라 + 포즈 + 카운팅 + DiagnosticHintEvaluator(2종 힌트)
 │   └── CoachingViewModel.swift     # API 호출 + 횟수 관리
 │
 ├── Services/
-│   ├── PoseDetectionService.swift  # VNDetectHumanBodyPoseRequest 래퍼
+│   ├── PoseDetectionService.swift  # VNDetectHumanBodyPoseRequest 래퍼. detectPoseDetailed → PoseFrameResult(joints + 하체 avg confidence + 양쪽 완전성)
 │   ├── HandDetectionService.swift  # VNDetectHumanHandPoseRequest 래퍼
 │   ├── SquatCounter.swift          # 관절 각도 → rep 판정
 │   ├── ClaudeAPIService.swift      # Claude API 호출
```

## `docs/spec.md`

```diff
diff --git a/docs/spec.md b/docs/spec.md
index 299525b..6d93ca0 100644
--- a/docs/spec.md
+++ b/docs/spec.md
@@ -78,6 +78,24 @@ AVCaptureSession (전면)
            └─ VNDetectHumanHandPoseRequest → 손바닥 판정
 ```
 
+### 2.5 트래킹 진단 힌트
+
+트래킹 상태에서 rep 카운트가 안 올라가는 원인을 1줄 배너로 안내. 2종 고정(.outOfFrame / .lowLight), ADR-018.
+
+- **판정 조건**
+  - `.outOfFrame`: **양쪽 hip/knee/ankle 중 어느 쪽도 3조인트 모두 검출되지 않은 상태** (= `SquatCounter` 가 angle 을 계산할 수 없는 조건) 가 3초 연속 지속.
+  - `.lowLight`: 하체 조인트(6개 중 검출분) 평균 confidence < 0.5 가 3초 연속 지속. outOfFrame 이 아닐 때만 평가.
+  - 우선순위: outOfFrame > lowLight.
+- **표시 규칙**
+  - 트래킹 시작 후 최소 5초 grace (카메라 안정화).
+  - 한 세션(TrackingView lifecycle) 내 rep 한 번이라도 카운트되면 힌트 숨김 + 재표시 금지.
+  - 세트 경계(setComplete → 다음 countdown → tracking) 에서 evaluator 상태 리셋 금지.
+  - 상단 반투명 배너 형태, 하단 종료 버튼 시야 가리지 않음.
+- **카피 (고정 2종)**
+  - `.outOfFrame`: "전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)"
+  - `.lowLight`: "조명이 어두울 수 있어요 · 실내 조명을 밝혀주세요"
+- **튜닝 대상**: grace 5s, sustain 3s, lowLight confidence 0.5. 전부 `TrackingViewModel` 내 `private enum Diagnostic` 에 상수화. 운영 중 튜닝은 이 enum 만 수정.
+
 ---
 
 ## 3. 데이터 모델
```

## `docs/user-intervention.md`

```diff
diff --git a/docs/user-intervention.md b/docs/user-intervention.md
index 259e30e..4fb1b0e 100644
--- a/docs/user-intervention.md
+++ b/docs/user-intervention.md
@@ -28,7 +28,18 @@ cc-system `plan-and-build` skill 원칙: **모든 구현은 CLI + AI 에이전
 
 ## 현재 등록된 절차
 
-_(없음 — 하네스가 실행되며 필요한 개입이 발견될 때마다 plan-and-build skill 이 이 파일에 항목을 추가한다.)_
+### 트래킹 진단 힌트 실기기 QA (ADR-018)
+
+- **트리거**: task `4-diagnostic-hint` 의 PR merge 직전 1회.
+- **이유**: Vision 기반 포즈 검출은 시뮬레이터에서 카메라 입력을 재현할 수 없어 실기기에서만 검증 가능. CTO 승인 조건부 #5.
+- **절차**:
+  1. 실기기(iPhone, iOS 17+) 에서 앱 실행 → 홈 → "스쿼트 시작" 탭 → 5초 카운트다운 → 트래킹 진입.
+  2. 정상 환경(밝은 실내, 2~3m 거리, 전신이 프레임에 들어옴) 에서 스쿼트 3회 수행. **3회가 그대로 카운트되어야 한다**.
+  3. 이어서 일부러 프레임 밖으로 나가 3~5초 정지. **상단에 "전신이 프레임에 들어오는지 확인하세요 (2~3m 거리 권장)" 배너가 출현해야 한다**.
+  4. 프레임으로 돌아와 세트 종료(탭 또는 손바닥 1초). 결과 화면에 세트/rep 기록이 정상 저장되는지 확인.
+  5. 조도(lowLight) 케이스는 실기기 검증 생략 가능(임계치 로직은 phase 1 에이전트의 코드 트레이스 시나리오로 커버).
+- **재개 신호**: 사용자가 에이전트에게 "QA OK" 라고 알려주면 merge 승인. 실패 시 재현 조건과 화면을 공유하고 phase 1 재실행.
+- **기록 위치**: PR 설명에 QA 수행 일시와 결과(a/b 각각 pass/fail) 기록.
 
 ---
 
```
