# Phase 7: AI 코칭

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md` (AI 코칭탭 섹션)
- `/docs/flow.md` (AI 코칭 흐름)
- `/docs/data-schema.md` (CoachingFeedback, AI 코칭 Context 구조)
- `/docs/adr.md` (ADR-005: Claude API 직접 호출, ADR-006: 7일 context)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Mofit/App/ContentView.swift`
- `Mofit/Models/UserProfile.swift`
- `Mofit/Models/WorkoutSession.swift`
- `Mofit/Models/CoachingFeedback.swift`
- `Mofit/Config/Secrets.swift` (또는 Secrets.example.swift)
- `Mofit/Utils/Theme.swift`

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

### 1. ClaudeAPIService.swift

`Mofit/Services/ClaudeAPIService.swift`:

Claude Messages API를 직접 호출하는 서비스. 외부 SDK 없이 URLSession으로 구현.

**API 호출 사양:**
- Endpoint: `https://api.anthropic.com/v1/messages`
- Method: POST
- Headers:
  - `x-api-key`: `Secrets.claudeAPIKey`
  - `anthropic-version`: `2023-06-01`
  - `content-type`: `application/json`
- Body:
  ```json
  {
    "model": "claude-sonnet-4-5-20250514",
    "max_tokens": 1024,
    "messages": [
      { "role": "user", "content": "<프롬프트>" }
    ]
  }
  ```
- Response에서 `content[0].text` 추출

**인터페이스:**
```swift
class ClaudeAPIService {
    func requestFeedback(prompt: String) async throws -> String
}
```

에러 처리: 네트워크 오류, API 오류 시 적절한 Error throw.

### 2. CoachingViewModel.swift

`Mofit/ViewModels/CoachingViewModel.swift`:

AI 코칭 로직을 관리하는 ViewModel. `ObservableObject` 채택.

**기능:**

1. **피드백 요청**: `requestFeedback(type: "pre" | "post")` 메서드
   - UserProfile + 최근 7일 WorkoutSession 데이터를 조합하여 프롬프트 생성
   - ClaudeAPIService로 API 호출
   - 성공 시: CoachingFeedback을 SwiftData에 저장
   - 실패 시: 에러 메시지 표시, 횟수 차감 안 함

2. **하루 2회 제한**:
   - 오늘 날짜의 CoachingFeedback을 조회하여 "pre" / "post" 각각 사용 여부 체크
   - 자정 기준 리셋 (날짜 비교로 자연스럽게 구현)

3. **프롬프트 생성**: 아래 구조로 context를 조합
   ```
   당신은 전문 피트니스 코치입니다. 사용자의 프로필과 최근 운동 기록을 바탕으로 {운동 전/후} 피드백을 제공해주세요.

   [사용자 프로필]
   - 성별: {gender}
   - 키: {height}cm
   - 몸무게: {weight}kg
   - 체형: {bodyType}
   - 목표: {goal}

   [최근 7일 운동 요약]
   - 운동한 날 수: {N}/7일
   - 총 세션 수: {N}회
   - 총 반복 수: {N}회
   - 일평균 반복 수: {N}회

   [일별 추이] (최근 7일, 오래된 순)
   - {날짜}: {rep}회, {세트}세트, 세트당 평균 {N}회
   ...

   한국어로 응답해주세요. 200자 이내로 간결하게.
   ```

4. **운동 기록 0일 처리**: WorkoutSession이 하나도 없으면 API 호출하지 않고 "아직 운동 기록이 없어서 피드백을 드리기 어려워요" 반환.

**Published 프로퍼티:**
- `isLoading: Bool`
- `errorMessage: String?`

### 3. CoachingView.swift

`Mofit/Views/Coaching/CoachingView.swift`:

**레이아웃 (위→아래):**

**상단:**
- "AI 코칭" 타이틀 (크게, 볼드)
- 남은 횟수 표시: "오늘 {사용}회 / 2회 사용" (textSecondary)

**버튼 영역:**
- "운동 전 피드백" 버튼
- "운동 후 피드백" 버튼
- 이미 사용한 유형의 버튼: 비활성화 (회색 처리)
- 로딩 중: ProgressView 표시

**피드백 카드 영역 (아래, ScrollView):**
- SwiftData에서 CoachingFeedback 전체 조회, 최신순 정렬
- 각 카드:
  - 날짜 (yyyy.MM.dd)
  - 유형 뱃지: "운동 전" 또는 "운동 후" (작은 라벨)
  - 피드백 내용 텍스트
- **최신 카드만 펼쳐져 있고, 나머지는 접혀있음**:
  - 접힌 상태: 날짜 + 유형만 표시
  - 탭하면 펼침/접힘 토글
- 카드 배경: `Theme.cardBackground`

### 4. ContentView.swift 업데이트

AI 코칭 탭의 placeholder를 `CoachingView()`로 교체하라.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

**BUILD SUCCEEDED** 출력 확인.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 7 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- Claude API 호출은 URLSession의 `async/await`를 사용하라. Combine이나 콜백 패턴 사용 금지.
- API key는 `Secrets.claudeAPIKey`에서 가져온다. 하드코딩하지 마라.
- API 응답 파싱 시 JSON 구조: `{"content": [{"type": "text", "text": "..."}]}`. `content` 배열의 첫 번째 아이템의 `text` 필드를 추출.
- 피드백 요청 실패 시 횟수를 차감하면 안 된다. 성공 시에만 CoachingFeedback을 저장 (= 횟수 차감).
- "하루" 기준: `Calendar.current.isDateInToday(feedback.date)`로 판단.
- 7일치 데이터 조회: `Calendar.current.date(byAdding: .day, value: -6, to: Date())`부터 오늘까지.
- 프롬프트의 한국어 매핑: gender "male"→"남성", bodyType "slim"→"마른 체형", goal "weightLoss"→"체중 감량" 등.
