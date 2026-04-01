# Phase 6: 기록탭

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md` (기록탭 섹션)
- `/docs/flow.md` (기록 열람 흐름)
- `/docs/data-schema.md` (WorkoutSession)

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Mofit/App/ContentView.swift`
- `Mofit/Models/WorkoutSession.swift`
- `Mofit/Utils/Theme.swift`

이전 phase에서 만들어진 코드를 꼼꼼히 읽고, 설계 의도를 이해한 뒤 작업하라.

## 작업 내용

### 1. RecordsView.swift

`Mofit/Views/Records/RecordsView.swift`:

**레이아웃 (위→아래):**

**상단: 날짜 선택 바**
- 가로 스크롤 (`ScrollView(.horizontal)`)
- 한 줄에 7일 표시 (오늘부터 과거 6일)
- 각 날짜 아이템: 요일 (월, 화...) + 날짜 (1, 2...)
- 선택된 날짜: `Theme.neonGreen` 배경 원형 강조
- 좌로 스와이프하면 더 이전 날짜 로드 (무한 스크롤까지는 불필요, 최근 30일 정도면 충분)
- 기본 선택: 오늘

**하단: 세션 리스트**
- 선택된 날짜의 `WorkoutSession` 목록을 SwiftData에서 조회
- 날짜 필터: `startedAt`이 선택된 날짜의 00:00~23:59 범위
- 각 세션 카드:
  - 운동 종류 아이콘 + 이름 ("스쿼트")
  - 세트 수: `repCounts.count`개
  - 총 rep: `repCounts.reduce(0, +)`회
  - 운동 시간: `totalDuration`을 MM:SS 형식으로
  - 시작 시각: `startedAt`을 HH:mm 형식으로
- **스와이프 삭제**: `.onDelete` 또는 `swipeActions`로 삭제 구현. SwiftData에서 해당 세션 삭제.
- 기록 없는 날: "이 날은 운동 기록이 없어요" 텍스트 (화면 중앙)

### 2. ContentView.swift 업데이트

기록 탭의 placeholder를 `RecordsView()`로 교체하라.

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

**BUILD SUCCEEDED** 출력 확인.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 6 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- 날짜 비교 시 Calendar를 사용하여 시간대를 올바르게 처리하라. `Calendar.current.isDate(_:inSameDayAs:)` 활용.
- SwiftData `@Query`에 predicate를 사용하여 날짜 필터링하거나, 전체 조회 후 필터링하라. `@Query`의 predicate에서 날짜 범위 비교가 복잡할 수 있으므로, 전체 조회 + computed property 필터링도 허용.
- 하루에 여러 세션이 있을 수 있다. 리스트로 전부 표시.
- 삭제는 확인 없이 즉시 실행한다.
- 이 phase에서 HomeView나 TrackingView를 수정하지 마라.
