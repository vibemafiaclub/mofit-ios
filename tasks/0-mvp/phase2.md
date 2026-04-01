# Phase 2: 앱 진입점 + 온보딩

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md` (온보딩 섹션)
- `/docs/flow.md` (최초 실행 + 재방문 흐름)
- `/docs/code-architecture.md`

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Mofit/Models/UserProfile.swift`
- `Mofit/Models/WorkoutSession.swift`
- `Mofit/Models/CoachingFeedback.swift`
- `Mofit/App/MofitApp.swift`
- `Mofit/Utils/Theme.swift`

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

### 1. MofitApp.swift 업데이트

앱 시작 시 `UserProfile`의 `onboardingCompleted`를 확인하여:
- `false` 또는 프로필 없음 → `OnboardingView` 표시
- `true` → `ContentView` (탭뷰) 표시

SwiftData의 `@Query`나 `modelContext`를 사용하여 UserProfile을 조회하라.

### 2. ContentView.swift

`Mofit/App/ContentView.swift`:

- 3개 탭의 `TabView`: 홈 / 기록 / AI코칭
- SF Symbols 아이콘 사용 (예: `house.fill`, `chart.bar.fill`, `brain.head.profile`)
- 탭바 선택 색상: `Theme.neonGreen`
- 각 탭의 내용은 임시 placeholder Text로 채워라 (이후 phase에서 교체)

### 3. OnboardingView.swift

`Mofit/Views/Onboarding/OnboardingView.swift`:

5단계 온보딩을 하나의 View 파일에 구현. `@State`로 현재 단계(0~4)를 관리.

**단계별 구성:**

**Step 0 — 성별 선택:**
- 제목: "성별을 선택해주세요"
- 큰 버튼 2개: "남성" / "여성"
- 선택하면 자동으로 다음 단계 진행 (탭 즉시 이동)

**Step 1 — 키 입력:**
- 제목: "키를 입력해주세요"
- 숫자 입력 필드 (cm 단위, numberPad 키보드)
- 입력값 검증:
  - 허용: 100~250
  - 경고(100~140 또는 200~250): "다음" 버튼 누르면 Alert "정말 {값}cm가 맞나요?" → 확인 시 진행, 취소 시 유지
  - 거부(100 미만 또는 250 초과): "다음" 버튼 비활성화 + 빨간 텍스트 "올바른 키를 입력해주세요"
- "다음" 버튼

**Step 2 — 몸무게 입력:**
- 제목: "몸무게를 입력해주세요"
- 숫자 입력 필드 (kg 단위, decimalPad 키보드)
- 입력값 검증:
  - 허용: 20~300
  - 경고(20~35 또는 150~300): Alert "정말 {값}kg이 맞나요?"
  - 거부(20 미만 또는 300 초과): 비활성화 + 빨간 텍스트 "올바른 몸무게를 입력해주세요"
- "다음" 버튼

**Step 3 — 체형 선택:**
- 제목: "체형을 선택해주세요"
- 4개 텍스트 버튼: "마른 체형" / "보통 체형" / "근육질 체형" / "통통한 체형"
- 내부 값 매핑: "slim" / "normal" / "muscular" / "chubby"
- 선택하면 자동으로 다음 단계

**Step 4 — 목표 선택:**
- 제목: "목표를 선택해주세요"
- 3개 텍스트 버튼: "체중 감량" / "근력 증가" / "체형 개선"
- 내부 값 매핑: "weightLoss" / "strength" / "bodyShape"
- 선택하면 온보딩 완료:
  - UserProfile 생성 (또는 업데이트) + `onboardingCompleted = true` 저장
  - ContentView로 전환

**공통:**
- 모든 단계에서 뒤로가기 버튼 표시 (Step 0 제외)
- 다크 배경, 흰색 텍스트, 버튼은 `Theme.neonGreen` 배경 or 테두리
- 애니메이션: 단계 전환 시 좌우 슬라이드

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

**BUILD SUCCEEDED** 출력 확인.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 2 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 온보딩 완료 후 UserProfile을 SwiftData에 저장할 때, 기존 프로필이 있으면 업데이트, 없으면 새로 생성하라.
- 키보드 타입: 키는 `numberPad` (정수), 몸무게는 `decimalPad` (소수점 허용).
- 온보딩 뷰는 1개 파일에 전부 구현하라. 불필요한 파일 분리 금지.
- ContentView의 각 탭 내용은 이 phase에서 placeholder Text로만 채운다. 실제 뷰는 이후 phase에서 구현.
