# Phase 1: picker-ui

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/prd.md` (특히 "운동 선택 (바텀시트)" 섹션 — Phase 0에서 갱신된 내용)
- `docs/spec.md` (특히 §1.3 `ExercisePickerView` 줄)
- `docs/adr.md` — **ADR-008**(기존 결정, 히스토리)과 **ADR-016**(본 iteration 보완 결정)을 반드시 대조하여 읽어라.
- `docs/code-architecture.md` (MVVM · 폴더 규칙 · "과한 추상화 없이"를 숙지)
- `docs/testing.md` (테스트 정책)
- `tasks/0-exercise-coming-soon/docs-diff.md` (Phase 0 docs 변경 실제 diff)
- `iterations/1-20260424_153124/requirement.md` (iteration 원문, 읽기 전용)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `docs/prd.md`, `docs/spec.md`, `docs/adr.md` — Phase 0가 수정한 실제 본문
- `Mofit/Views/Home/ExercisePickerView.swift` — 현재 구현 (이번 phase에서 수정)
- `Mofit/Views/Home/HomeView.swift` — 호출자. `ExercisePickerView(selectedExerciseName: ...)` 바인딩 시그니처가 바뀌면 안 된다.
- `Mofit/Utils/Theme.swift` — 사용 가능한 색상 상수 확인 (`Theme.darkBackground`, `Theme.cardBackground`, `Theme.textPrimary`, `Theme.textSecondary`, `Theme.neonGreen` 등). **신규 색상 정의 금지.**
- `project.yml` — xcodegen 설정. 이번 phase에서 target/dependency 변경 없음.

이전 phase에서 만들어진 문서와 기존 코드를 꼼꼼히 읽고, Phase 0 ADR-016 본문의 문구(배지 `준비중`, 토스트 `현재는 스쿼트만 지원합니다`, opacity `0.4`)를 그대로 Swift 리터럴로 옮긴다는 점을 명심하라.

## 작업 내용

### 대상 파일
`Mofit/Views/Home/ExercisePickerView.swift` (**이 파일 1개만** 수정)

### 목적
ExercisePicker 바텀시트에서 스쿼트만 active 상태로 유지하고, 푸쉬업/싯업은 "준비중" 표시로 공개한다. tap 자체는 막지 않되 진입 대신 토스트만 띄운다.

### 구현 요구사항

1. **운동 목록을 튜플 3필드로 확장**
   - 기존: `[(name: String, icon: String)]`
   - 신규: `[(name: String, icon: String, locked: Bool)]`
   - 값:
     - `("스쿼트", "figure.strengthtraining.traditional", false)`
     - `("푸쉬업", "figure.strengthtraining.functional", true)`
     - `("싯업", "figure.core.training", true)`
   - **아이콘 SF Symbol은 건드리지 마라.** 기존 것 그대로 유지.
   - **배열 순서는 스쿼트 → 푸쉬업 → 싯업 그대로 유지.**

2. **토스트 상태 변수 추가**
   ```swift
   @State private var showToast: Bool = false
   @State private var toastWorkItem: DispatchWorkItem?
   ```

3. **`exerciseCard`에 `locked` 파라미터 추가하고 렌더링 분기**
   - 시그니처(예시, 이름/순서 자유): `private func exerciseCard(name: String, icon: String, locked: Bool) -> some View`
   - **locked=true일 때 시각 처리**:
     - 전체 카드의 opacity는 `0.4` (리터럴 그대로).
     - 카드 우상단에 "준비중" pill 배지(텍스트 `준비중`, 작은 font, 둥근 배경). 배경/전경은 Theme에 이미 있는 상수 재활용(예: 배경 `Theme.textSecondary.opacity(0.25)` 같은 변형 허용, **새 색상 상수 정의 금지**).
     - 기존 selected 하이라이트(`Theme.neonGreen` 테두리 + 텍스트 색)는 locked 셀에서 절대 뜨면 안 된다. 판정 조건을 `selectedExerciseName == name && !locked`로 교체.
   - **locked=false일 때**: 기존 스타일 그대로.

4. **Button action 분기**
   - locked=true:
     1. `selectedExerciseName`을 변경하지 않는다.
     2. `dismiss()`를 호출하지 않는다.
     3. `UIImpactFeedbackGenerator(style: .light).impactOccurred()` 를 호출 (한 줄. `import UIKit` 추가 필요).
     4. 기존 `toastWorkItem?.cancel()` → `showToast = true` → 새 `DispatchWorkItem { showToast = false }` 생성 → `toastWorkItem = newItem` 보관 → `DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: newItem)`.
   - locked=false:
     - 기존 로직 그대로: `selectedExerciseName = name`, `dismiss()`.

5. **토스트 오버레이 렌더링**
   - `VStack` 의 `.overlay(alignment: .bottom) { ... }` 로 추가.
   - `showToast == true`일 때만 표시. 내용:
     - `Text("현재는 스쿼트만 지원합니다")` — **리터럴 그대로**.
     - 둥근 사각형 배경(`Theme.cardBackground`), 가로/세로 패딩, 하단 safe area 위 적당한 `.padding(.bottom, 40)` 수준.
     - `.transition(.opacity)` + 상위에 `.animation(.easeInOut, value: showToast)` 정도. 애니메이션 프레임워크(Task/Combine) 도입 금지.
   - `showToast == false`일 때는 `EmptyView()` 반환.

6. **HomeView 영향 없음**
   - `ExercisePickerView`의 public API(`selectedExerciseName: Binding<String>`)는 건드리지 마라.
   - `HomeView.swift`를 수정하지 마라.

### 하지 말아야 할 것

- 신규 파일 생성 금지 (ToastView 등 별도 컴포넌트 추출 금지 — 현재 코드베이스에 `Views/Components/` 폴더 자체가 없다).
- `Exercise` struct/enum 도입 금지 (튜플 유지).
- Mixpanel/Analytics 호출 추가 금지 (ADR-015는 결정만, 실장 티켓 별도).
- `Task { try await ... }` / Combine `Timer.publish` 금지. `DispatchQueue.main.asyncAfter` + `DispatchWorkItem`만 사용.
- Theme에 신규 색 상수 정의 금지.
- `project.yml` / `scripts/` / `docs/` 수정 금지.
- SwiftData 모델 수정 금지.

### QA 체크리스트 산출물 생성

Phase 1 작업의 마지막 단계로, 디바이스 수동 QA용 체크리스트를 아래 경로에 생성하라. 단 **`iterations/1-20260424_153124/requirement.md`는 건드리지 말고** 같은 폴더에 **별도 파일**로 만든다.

경로: `iterations/1-20260424_153124/qa-checklist.md`

내용(그대로 작성):

```markdown
# QA Checklist — iteration 1 (exercise-coming-soon)

무인 세션에서는 시뮬레이터 실행이 불가능하다. 릴리즈 빌드 전 사용자가 디바이스/시뮬레이터에서 아래를 직접 확인한다.

- [ ] 1. 스쿼트 셀 탭 → ExercisePicker가 dismiss 되고 `selectedExerciseName`이 "스쿼트"로 설정됨.
- [ ] 2. 푸쉬업 셀 탭 → 바텀시트가 dismiss 되지 않고, 하단에 토스트 "현재는 스쿼트만 지원합니다"가 나타남.
- [ ] 3. 싯업 셀 탭 → 푸쉬업과 동일 동작(dismiss 없음 + 토스트).
- [ ] 4. 토스트가 1.5초 후 자동 소멸. 연속 tap 시 타이머가 reset되어 마지막 tap 기준 1.5초 후 사라짐.
- [ ] 5. locked 셀(푸쉬업/싯업)에 selected 하이라이트(네온그린 테두리/텍스트)가 절대 뜨지 않음. opacity는 0.4.
- [ ] 6. 푸쉬업/싯업 탭 시 가벼운 햅틱(light impact) 피드백이 한 번 발생.

결과는 각 항목 체크 + 실패 시 메모. 이 파일은 iteration 산출물로 git에 커밋된다.
```

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0이어야 한다.

```bash
# 1) 프로젝트 재생성
xcodegen generate

# 2) 빌드 성공 (시뮬레이터용, 코드 사이닝 off)
xcodebuild \
  -scheme Mofit \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -60

# 3) 핵심 리터럴이 실제 코드에 있음
grep -F '"준비중"' Mofit/Views/Home/ExercisePickerView.swift
grep -F '"현재는 스쿼트만 지원합니다"' Mofit/Views/Home/ExercisePickerView.swift
grep -F "0.4" Mofit/Views/Home/ExercisePickerView.swift
grep -F "UIImpactFeedbackGenerator" Mofit/Views/Home/ExercisePickerView.swift
grep -F "DispatchWorkItem" Mofit/Views/Home/ExercisePickerView.swift

# 4) HomeView 미변경
git diff --quiet HEAD -- Mofit/Views/Home/HomeView.swift

# 5) docs / project.yml / scripts 미변경
git diff --quiet HEAD -- docs/ project.yml scripts/

# 6) QA 체크리스트 산출물 존재
test -f iterations/1-20260424_153124/qa-checklist.md

# 7) requirement.md 불변
git diff --quiet HEAD -- iterations/1-20260424_153124/requirement.md
```

xcodebuild 출력 말미에 `** BUILD SUCCEEDED **` 가 찍혀야 한다.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/0-exercise-coming-soon/index.json`의 phase 1 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

xcodebuild가 디스크/시뮬레이터 런타임 부재 등으로 실패하면, `xcodebuild -showsdks | grep iphonesimulator` 로 사용 가능한 SDK를 확인하고 `-sdk` 값을 조정하라. 그래도 해결이 안 되면 `-destination 'generic/platform=iOS'` 로 전환을 시도하되, 실패 로그 전체를 `error_message`에 기록하라.

## 주의사항

- **`selectedExerciseName` 바인딩 시그니처를 바꾸지 마라.** HomeView에서 `@State`로 보관하고 sheet로 전달 중. 깨지면 상위 화면이 컴파일 실패한다.
- **Mixpanel/Analytics 이벤트 호출을 추가하지 마라.** (CTO 조건부 #2, ADR-015 미실장)
- **ToastView/Components 신규 파일 생성 금지.** 현재 `Mofit/Views/Components/` 폴더 자체가 없음. 단일 사용처용이므로 view 내부 private view 또는 `.overlay` 인라인으로 해결.
- **신규 색 상수 금지.** Theme에 정의된 기존 색만 (필요 시 `.opacity()` 변형은 허용).
- **Task/Combine 금지.** 타이머는 `DispatchQueue.main.asyncAfter` + `DispatchWorkItem`만.
- **HomeView.swift, docs/*, project.yml 수정 금지.** 이번 phase의 scope는 `Mofit/Views/Home/ExercisePickerView.swift` 한 파일 + `iterations/1-20260424_153124/qa-checklist.md` 신규 생성 뿐.
- **"곧 지원됩니다" 같은 미래 약속 문구 금지.** 토스트 카피는 정확히 "현재는 스쿼트만 지원합니다".
- **세트 완료/locked tap haptic은 light 한 가지만.** 패턴/타이밍 변경 금지.
- **기존 테스트를 깨뜨리지 마라.** (현재 test target 없음 — 영향 받을 테스트는 없지만, 만약 향후 추가돼도 이 phase가 깨뜨리지 않도록 순수 UI 변경 범위 유지.)
