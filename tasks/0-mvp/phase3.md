# Phase 3: 홈탭 + 운동 선택 + 프로필 수정

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md` (홈탭, 운동 선택, 프로필 수정 섹션)
- `/docs/flow.md` (운동 흐름, 프로필 수정 흐름)
- `/docs/adr.md` (ADR-008: 운동 선택 UI)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Mofit/App/MofitApp.swift`
- `Mofit/App/ContentView.swift`
- `Mofit/Models/UserProfile.swift`
- `Mofit/Models/WorkoutSession.swift`
- `Mofit/Utils/Theme.swift`
- `Mofit/Views/Onboarding/OnboardingView.swift`

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

### 1. HomeView.swift

`Mofit/Views/Home/HomeView.swift`:

**레이아웃 (위→아래):**

- **상단 바**: 좌측 "모핏" 타이틀 (굵은 폰트), 우측 프로필 아이콘 버튼 (SF Symbol: `person.circle`)
- **운동 종류 선택 영역**: 탭 가능한 카드/칩. 현재 선택된 운동명 표시 (기본값: "스쿼트"). 탭하면 `ExercisePickerView` 바텀시트 표시.
- **운동 시작 버튼**: 크고 눈에 띄는 버튼, `Theme.neonGreen` 배경, "운동 시작" 텍스트. 탭하면 트래킹 화면으로 이동 (이 phase에서는 빈 화면으로 NavigationLink/fullScreenCover 연결만).
- **오늘의 기록 요약 카드**:
  - SwiftData에서 오늘 날짜의 WorkoutSession들을 조회
  - 총 세트 수, 총 rep 수, 총 운동 시간 표시
  - 기록 없으면: "첫 운동을 시작해보세요!" 텍스트

- **폭죽 효과**: `@State var showConfetti: Bool`로 제어. SwiftUI Canvas + particles 또는 간단한 이모지 애니메이션으로 구현. 운동 종료 후 홈에 돌아왔을 때 트리거 (Phase 5에서 연결 예정이므로, 이 phase에서는 효과 컴포넌트만 만들어두고 수동 트리거 가능하게).

### 2. ExercisePickerView.swift

`Mofit/Views/Home/ExercisePickerView.swift`:

- `.sheet`로 표시되는 바텀시트
- 2열 `LazyVGrid` 그리드
- 4개 운동 카드: 스쿼트 / 푸쉬업 / 런지 / 플랭크
- 각 카드: 운동명 텍스트 + 적절한 SF Symbol 아이콘
- 선택하면 시트 닫히고 HomeView의 선택된 운동명 업데이트
- 내부적으로 `exerciseType`은 항상 `"squat"` (ADR-008)

### 3. ProfileEditView.swift

`Mofit/Views/Profile/ProfileEditView.swift`:

- `.fullScreenCover`로 표시
- 온보딩에서 입력한 5개 값 전부 수정 가능:
  - 성별 (남성/여성 선택)
  - 키 (숫자 입력, 온보딩과 동일한 검증)
  - 몸무게 (숫자 입력, 온보딩과 동일한 검증)
  - 체형 (4개 선택지)
  - 목표 (3개 선택지)
- 상단: "프로필 수정" 타이틀 + 닫기(X) 버튼
- 하단: "저장" 버튼 (Theme.neonGreen)
- 저장 시 SwiftData의 UserProfile 업데이트

### 4. ContentView.swift 업데이트

홈 탭의 placeholder를 `HomeView()`로 교체하라. 나머지 탭(기록, AI코칭)은 placeholder 유지.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

**BUILD SUCCEEDED** 출력 확인.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 3 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 운동 시작 버튼은 이 phase에서 트래킹 화면으로의 네비게이션 연결만 한다. 트래킹 화면 자체는 Phase 5에서 구현.
- 트래킹 화면 대상으로 빈 View (placeholder)를 만들어 연결하라. `fullScreenCover`를 사용하라.
- 폭죽 효과는 외부 라이브러리 없이 순수 SwiftUI로 구현하라.
- ProfileEditView의 입력 검증 로직은 OnboardingView와 동일하다. 코드 중복이 생기더라도 별도 유틸리티/컴포넌트로 추출하지 마라 — 두 곳에서만 쓰이므로 추상화는 오버엔지니어링이다.
