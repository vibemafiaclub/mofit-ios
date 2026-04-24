# Phase 1: samples-ui

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/spec.md` (특히 §1.3 `AuthGateView` 라인 — Phase 0에서 갱신된 내용)
- `docs/adr.md` (특히 ADR-005, ADR-007 다크모드 고정, ADR-013, ADR-015)
- `docs/code-architecture.md` (MVVM · `Views/Coaching/` 폴더 규칙 · "과한 추상화 없이")
- `docs/testing.md` (테스트 정책 — mock 접착제 테스트 금지, 커버리지 숫자 목표 없음)
- `docs/user-intervention.md`
- `tasks/1-coaching-samples/docs-diff.md` (Phase 0 docs 변경 실제 diff)
- `iterations/2-20260424_155909/requirement.md` (iteration 원문 읽기 전용, 특히 L172/L173 샘플 카피 + "CTO 조건부 5개")

그리고 이전 phase의 작업물을 반드시 확인하라:

- `docs/spec.md` — Phase 0이 수정한 §1.3 L37
- `Mofit/Views/Coaching/CoachingView.swift` — 현재 구현 (이번 phase에서 수정 대상). 특히 `notLoggedInContent` property (L131-L180 부근)와 기존 `typeBadge(for:)` helper (L472 부근).
- `Mofit/Models/CoachingFeedback.swift` — SwiftData `@Model`. 이번 샘플은 `@Model`을 **사용하지 않는다** (persistence 불필요). 별도 plain struct로 정의.
- `Mofit/Utils/Theme.swift` — 사용 가능한 색상 상수(`Theme.darkBackground`, `Theme.cardBackground`, `Theme.textPrimary`, `Theme.textSecondary`, `Theme.neonGreen`). **신규 색상 정의 금지.**
- `project.yml` — xcodegen 설정. `Mofit/**/*.swift` 글롭 기반이라 신규 `.swift` 파일 자동 편입. `project.yml` 자체는 수정 금지.

이전 phase에서 만들어진 문서와 기존 코드를 꼼꼼히 읽고, Phase 0 spec.md L37 문구의 의도(샘플 피드백 카드 2장, 운동 전/후)를 그대로 Swift 리터럴로 옮긴다는 점을 명심하라.

## 작업 내용

### 대상 파일

1. **신규**: `Mofit/Views/Coaching/CoachingSamples.swift`
2. **수정**: `Mofit/Views/Coaching/CoachingView.swift` (`notLoggedInContent` property 재구성만)
3. **신규**: `tasks/1-coaching-samples/qa-checklist.md` (수동 QA 산출물)

### 목적

`CoachingView` 비로그인 분기(`notLoggedInContent`)에 "이런 피드백을 받게 됩니다" 섹션 + 샘플 피드백 카드 2장(운동 전 / 운동 후)을 노출한다. 샘플 카드는 항상 전개 상태로, 각 카드 하단에 고지 문구를 둔다. 기존 로그인/회원가입 버튼 흐름은 그대로 유지하고, 샘플 섹션은 헤딩과 버튼 사이에 삽입한다.

### 구현 요구사항

#### 1) `Mofit/Views/Coaching/CoachingSamples.swift` 신규

파일 레벨(internal) 타입으로 정의. private nested 금지(Preview/테스트 재사용 여지).

```swift
import Foundation

struct CoachingSample: Identifiable {
    let id = UUID()
    let type: String   // "pre" | "post"
    let content: String
}

enum CoachingSamples {
    static let all: [CoachingSample] = [
        CoachingSample(
            type: "pre",
            content: "지난 주 3일 운동 · 총 78회 스쿼트 · 일평균 26회. 수요일엔 38회 최다였고 금요일 0회였네요. 오늘은 수요일 페이스 회복해서 30회 이상 도전해보세요."
        ),
        CoachingSample(
            type: "post",
            content: "오늘 3세트 총 32회. 1세트 14회 → 2세트 10회 → 3세트 8회. 세트별 감소폭 4회로 피로도 자연스러운 곡선. 내일은 2세트째에서 쉬는 시간 20초 늘려보세요."
        )
    ]
}
```

- `all` 배열 요소 정확히 2개. 3개 이상 추가 금지(CTO 조건부 #4).
- 각 `content` 문자열은 requirement.md L172 (pre) / L173 (post) 와 **글자까지 동일**해야 한다. 공백·문장부호·"·" 중점 등 바꾸지 마라.
- `type` 값은 `"pre"` / `"post"` 문자열만(기존 `CoachingFeedback.type` 규약과 일치).
- SwiftData `@Model` 사용 금지. modelContext 인자 받지 않음.

#### 2) `Mofit/Views/Coaching/CoachingView.swift` — `notLoggedInContent` 재구성

**기존 (L131-L180 부근)**: `Spacer() → brain icon → heading → buttons → Spacer()` 수직 중앙 정렬.

**신규 레이아웃 순서** (상단→하단):

```
ScrollView
  VStack(spacing: 24)
    [1] brain icon (figure: "brain.head.profile", 80pt, Theme.neonGreen)
    [2] heading "AI 코칭은 로그인 후\n사용할 수 있어요" (기존 Text 그대로, 중앙 정렬 유지)
    [3] 샘플 섹션
          VStack(alignment: .leading, spacing: 12)
            Text("이런 피드백을 받게 됩니다") — font(.headline), Theme.textPrimary
            ForEach(CoachingSamples.all) { sample in
              sampleFeedbackCard(sample: sample)
            }
          .padding(.horizontal, 16) // 또는 섹션 wrapper 공통 horizontal padding
    [4] 로그인 / 회원가입 버튼 (기존 VStack(spacing: 12) 블록 그대로)
          .padding(.horizontal, 32)
  .padding(.top, 40)
  .padding(.bottom, 32)
```

- `Spacer() ... Spacer()` 중앙 정렬 제거. 상단부터 자연스럽게 쌓이는 구조.
- `ScrollView`로 전환(SE 등 작은 디바이스에서 overflow 대비).
- 기존 `Spacer()` 대신 `VStack(spacing: 24)`의 spacing으로 수직 간격 확보.
- 로그인 / 회원가입 버튼의 라벨, 액션, 색상, 코너 반경 등 스타일은 **전부 기존 그대로**. `showLogin = true` / `showSignUp = true` 플래그도 그대로.

#### 3) `sampleFeedbackCard(sample:)` private helper (CoachingView 내부)

시그니처(예시):
```swift
private func sampleFeedbackCard(sample: CoachingSample) -> some View
```

카드 구성 (항상 전개, collapse 미사용):
```
VStack(alignment: .leading, spacing: 12)
  HStack
    typeBadge(for: sample.type)   // 기존 helper 재활용
    Spacer()
  Text(sample.content)
    .font(.body)
    .foregroundColor(Theme.textPrimary)
    .multilineTextAlignment(.leading)
    .fixedSize(horizontal: false, vertical: true)
  Text("※ 예시 피드백 (실제 데이터 기반으로 매번 다름)")
    .font(.caption)
    .foregroundColor(Theme.textSecondary)
.padding(16)
.frame(maxWidth: .infinity, alignment: .leading)
.background(Theme.cardBackground)
.cornerRadius(16)
```

- 기존 `typeBadge(for:)` (L472 부근) **그대로 재활용**. 시그니처·구현 수정 금지.
- `Button` 래핑 금지 — 기존 `feedbackCard(for:)`는 collapse 토글 버튼이지만, 샘플은 tap 인터랙션 없음.
- 카드 사이 간격은 상위 ForEach + VStack spacing 12로 확보.

#### 4) 기존 `loggedInContent` 분기 — 건드리지 마라

`loggedInContent`, `headerSection`, `buttonSection`, `feedbackCard(for:)`, `serverFeedbackCard(for:)`, `emptyState`, `errorCard(message:)`, `feedbackList`, `localFeedbackList`, `serverFeedbackList`, `loadServerFeedbacks()`, `requestFeedback(type:)` 등 로그인 유저 분기 전체는 **단 한 글자도 수정하지 마라**. 이번 변경은 `notLoggedInContent` property 하나만이다. 단, `typeBadge(for:)` 재활용은 허용(읽기만, 수정 금지).

### 4) `tasks/1-coaching-samples/qa-checklist.md` 신규

아래 내용 그대로 작성:

```markdown
# QA Checklist — task 1 (coaching-samples)

무인 세션에서는 시뮬레이터 실행이 불가능하다. 릴리즈 빌드 전 사용자가 디바이스/시뮬레이터에서 아래를 직접 확인한다.

- [ ] 1. 비로그인 상태에서 "AI 코칭" 탭 진입 → 상단에 brain 아이콘 + "AI 코칭은 로그인 후 사용할 수 있어요" 헤딩 렌더.
- [ ] 2. 헤딩 아래 섹션 "이런 피드백을 받게 됩니다" + 샘플 카드 2장이 차례로 보임. 카드는 항상 펼쳐진 상태.
- [ ] 3. 첫 카드: `운동 전` 배지 + 본문(지난 주 3일 운동 시작) + 하단 고지 `※ 예시 피드백 (실제 데이터 기반으로 매번 다름)`.
- [ ] 4. 둘째 카드: `운동 후` 배지 + 본문(오늘 3세트 총 32회 시작) + 동일 고지.
- [ ] 5. 샘플 섹션 아래에 기존 "로그인" / "회원가입" 버튼 2종이 그대로 노출됨.
- [ ] 6. "로그인" 탭 → `LoginView` 가 fullScreenCover로 뜸. "회원가입" 탭 → `SignUpView` 가 뜸. (기존 동작 회귀 없음)
- [ ] 7. SE(작은 디바이스)에서 스크롤로 전체 내용 접근 가능. 콘텐츠 잘림 없음.
- [ ] 8. 다크 모드 고정 유지(ADR-007). 라이트 모드 전환 시에도 화면이 다크 톤 그대로.
- [ ] 9. 로그인 상태로 돌아가면 기존 `loggedInContent` 뷰(AI 코칭 헤더 + 운동 전/후 버튼 + 피드백 리스트)가 정상 동작. 회귀 없음.

결과는 각 항목 체크 + 실패 시 메모. 이 파일은 task 산출물로 git에 커밋된다.
```

### 하지 말아야 할 것

- 신규 파일 생성은 `CoachingSamples.swift` + `qa-checklist.md` 2개만 허용. 그 외 신규 파일(`AuthGateView.swift`, `SampleFeedbackCard.swift`, `CoachingSamplesTests.swift` 등) 생성 금지.
- `loggedInContent` / `headerSection` / `buttonSection` / `feedbackCard(for:)` / `serverFeedbackCard(for:)` / `feedbackList` 등 로그인 분기 관련 코드 수정 금지.
- `Mofit/Models/**`, `Mofit/Services/**`, `Mofit/ViewModels/**` 수정 금지(CTO 조건부 #5). 특히 `CoachingViewModel.swift` · `AnalyticsService.swift` · SwiftData 모델 모두 불변.
- `server/**` 수정 금지.
- `docs/**`, `iterations/**`, `project.yml`, `scripts/**`, `tasks/0-exercise-coming-soon/**` 수정 금지.
- Analytics 이벤트 추가 금지(`.sampleViewed`, `.ctaShown` 등 새 이벤트 박지 마라). 이유: ADR-015 결정만, 실장 미완 + CTO 조건부 #5.
- SwiftData `@Model` 도입 금지. `CoachingSample`은 plain struct.
- `Theme`에 신규 색상 상수 정의 금지. 기존 상수 + `.opacity()` 변형만 허용.
- collapse 토글 / tap 제스처 / 샘플 카드 `Button` 래핑 금지.
- 샘플 카피 변형 금지. "화이팅!", "힘내세요!" 등 일반론 추가 금지. requirement.md L172/L173 원문 그대로.
- 샘플 3종 이상 추가 금지(CTO 조건부 #4).
- `AuthGateView.swift` 파일 분리 금지. 이번 scope 밖.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0이어야 한다.

```bash
# 1) 프로젝트 재생성 (신규 .swift 파일이 target에 편입되도록)
xcodegen generate

# 2) 빌드 성공 (시뮬레이터용, 코드 사이닝 off)
xcodebuild \
  -scheme Mofit \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -80

# 3) 신규 파일 존재
test -f Mofit/Views/Coaching/CoachingSamples.swift

# 4) CoachingSamples 내용 검증 — 카피 리터럴 정확도
grep -F "지난 주 3일 운동 · 총 78회 스쿼트 · 일평균 26회. 수요일엔 38회 최다였고 금요일 0회였네요. 오늘은 수요일 페이스 회복해서 30회 이상 도전해보세요." Mofit/Views/Coaching/CoachingSamples.swift
grep -F "오늘 3세트 총 32회. 1세트 14회 → 2세트 10회 → 3세트 8회. 세트별 감소폭 4회로 피로도 자연스러운 곡선. 내일은 2세트째에서 쉬는 시간 20초 늘려보세요." Mofit/Views/Coaching/CoachingSamples.swift

# 5) 샘플 개수 정확히 2 — type별 1회씩
test "$(grep -c 'type: "pre"' Mofit/Views/Coaching/CoachingSamples.swift)" -eq 1
test "$(grep -c 'type: "post"' Mofit/Views/Coaching/CoachingSamples.swift)" -eq 1

# 6) CoachingView.swift 에 섹션 제목 + 고지 리터럴 존재
grep -F "이런 피드백을 받게 됩니다" Mofit/Views/Coaching/CoachingView.swift
grep -F "※ 예시 피드백 (실제 데이터 기반으로 매번 다름)" Mofit/Views/Coaching/CoachingView.swift

# 7) 데드코드 방지 — CoachingSamples.all 이 실제로 뷰에서 참조됨
grep -F "CoachingSamples.all" Mofit/Views/Coaching/CoachingView.swift

# 8) 금지 스코프 미변경 — 핵심 5개 영역
git diff --quiet HEAD -- Mofit/Models/
git diff --quiet HEAD -- Mofit/Services/
git diff --quiet HEAD -- Mofit/ViewModels/
git diff --quiet HEAD -- server/
git diff --quiet HEAD -- docs/ iterations/ project.yml scripts/

# 9) 이전 task 미변경
git diff --quiet HEAD -- tasks/0-exercise-coming-soon/

# 10) QA 체크리스트 산출물 존재
test -f tasks/1-coaching-samples/qa-checklist.md

# 11) 신규 파일 금지 경계 — AuthGateView / 테스트 파일 생성 없음
test ! -f Mofit/Views/Coaching/AuthGateView.swift
test ! -f Mofit/Views/Coaching/SampleFeedbackCard.swift
test ! -d MofitTests
```

xcodebuild 출력 말미에 `** BUILD SUCCEEDED **` 가 찍혀야 한다.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/1-coaching-samples/index.json`의 phase 1 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

xcodebuild가 디스크/시뮬레이터 런타임 부재 등으로 실패하면, `xcodebuild -showsdks | grep iphonesimulator` 로 사용 가능한 SDK를 확인하고 `-sdk` 값을 조정하라. 그래도 해결이 안 되면 `-destination 'generic/platform=iOS'` 로 전환을 시도하되, 실패 로그 전체를 `error_message`에 기록하라.

## 주의사항

- **샘플 카피는 requirement.md L172/L173 원문을 글자까지 동일하게 사용하라.** 중점(·), 화살표(→), 조사·구두점까지 그대로. CTO 조건부 #2 (숫자+요일/시점+구체행동 3요소) 및 "화이팅/힘내세요 금지" 기준 충족.
- **샘플은 정확히 2종.** 3종 이상 추가 시 CTO 승인 무효(조건부 #4).
- **SwiftData 스키마 · 서버 API · Analytics 손대지 마라.** CTO 조건부 #5. 해당 영역 수정 시 승인 자체가 무효가 된다.
- **"고지 문구 `※ 예시 피드백 (실제 데이터 기반으로 매번 다름)` 누락 금지.** CTO 조건부 #3. 샘플 카드 **각각**의 하단에 반드시 포함.
- **로그인 유저 분기(`loggedInContent` 하위) 한 글자도 수정 금지.** 이번 변경은 `notLoggedInContent` property 재구성만.
- **`Theme`에 신규 색상 정의 금지.** 기존 상수(`Theme.darkBackground`, `Theme.cardBackground`, `Theme.textPrimary`, `Theme.textSecondary`, `Theme.neonGreen`)만 사용. `.opacity()` 변형은 허용.
- **collapse 토글/`Button` 래핑 금지.** 샘플 카드는 정적 디스플레이. tap 인터랙션 없음.
- **`AuthGateView.swift` 별도 파일 분리 금지.** 현재 `CoachingView.swift` 내부 인라인 구조 유지. 파일 분리 시 spec.md 추가 정리·preview 추가 등 scope 확대.
- **다크모드 고정 유지.** ADR-007. 라이트 모드 대응 코드 추가 금지. 샘플 카드 색상도 `Theme.cardBackground` 하나로.
- **`CoachingSample`은 plain struct.** SwiftData `@Model`, Codable, Hashable 도입 금지(필요 없음). `Identifiable`만 채택.
- **Analytics 이벤트 추가 금지.** "샘플 노출률 측정하려면 이벤트 추가해야" 유혹에 넘어가지 마라. 이번 scope 밖.
- **기존 `typeBadge(for:)` helper 재활용.** 새 배지 컴포넌트 만들지 마라. 그대로 호출.
- **`ScrollView` 전환 시 중앙 정렬 시도 금지.** `Spacer()`로 수직 중앙 맞추려 하지 말고, 상단부터 `VStack(spacing: 24)`로 자연스럽게 쌓이게 하라.
- **기존 테스트를 깨뜨리지 마라.** (현재 `MofitTests` target 없음 — XCTest 추가 금지, `testing.md` 원칙.)
