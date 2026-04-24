# ADR (Architecture Decision Records)

## 철학
MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정성과의 트레이드오프에서 "작동하는 최소 구현"을 선택.

---

### ADR-001: Apple Vision 선택 (vs MediaPipe, TensorFlow Lite)
**결정**: Apple Vision framework의 VNDetectHumanBodyPoseRequest + VNDetectHumanHandPoseRequest 사용.
**이유**: 네이티브 API라 외부 의존성 0, 설정 불필요, iOS 최적화 완료. MediaPipe/TFLite는 빌드 복잡도 증가 + 바이너리 크기 증가. 19개 관절 포인트로 스쿼트 판정에 충분.
**트레이드오프**: Apple 생태계 종속. 크로스 플랫폼 확장 시 재구현 필요. MVP에서는 무관.

### ADR-002: SwiftData 선택 (vs Core Data, UserDefaults, SQLite)
**결정**: SwiftData (iOS 17+).
**이유**: SwiftUI 네이티브 통합, Core Data 대비 코드량 70% 감소, @Model 매크로로 선언적 정의. iOS 17+ 점유율 90%+ 이므로 타겟 제한 수용 가능.
**트레이드오프**: iOS 17 미만 미지원. 마이그레이션 도구가 Core Data 대비 미성숙. MVP에서는 스키마 변경 가능성 낮으므로 수용.

### ADR-003: WorkoutSet 모델 제거 → repCounts 배열
**결정**: 세트를 별도 모델로 분리하지 않고 WorkoutSession.repCounts: [Int]로 관리.
**이유**: 세트별 추가 메타데이터(시간, 쉬는시간 등)가 없음. 관계 설정 + CRUD 복잡도 불필요. `[12, 10, 8]`이면 3세트, 총 30rep 즉시 도출.
**트레이드오프**: 세트별 상세 정보 확장 시 마이그레이션 필요. 필요해지면 그때 분리.

### ADR-004: Vision 분석 15fps 샘플링
**결정**: 카메라 프리뷰 30fps 유지, Vision 포즈/손 분석은 15fps로 샘플링.
**이유**: 스쿼트는 느린 동작이라 15fps로 충분. 배터리 소모 절감. 프리뷰는 AVCaptureVideoPreviewLayer가 독립 렌더링하므로 분석 빈도와 무관하게 부드러움.
**트레이드오프**: 관절 오버레이 업데이트가 15fps. 빠른 동작에서는 지연 느낄 수 있으나 스쿼트에서는 문제 없음.

### ADR-005: Claude API 직접 호출 (서버리스)
**결정**: 앱에서 Claude API를 직접 호출. API key를 Secrets.swift에 하드코딩, .gitignore로 보호.
**이유**: 서버 구축/유지 비용 제거. MVP 속도 최우선. 하루 2회 호출이라 비용 미미.
**트레이드오프**: API key가 앱 바이너리에 포함됨 → 리버스 엔지니어링으로 노출 가능. 출시 전 서버 프록시 전환 검토 필요. 오픈소스 repo이므로 Secrets.swift가 git에 올라가지 않도록 반드시 관리.

### ADR-006: AI 코칭 context 7일 제한 + 추이 데이터
**결정**: 최근 7일 기록 + 요약 통계 + 일별 추이를 context로 전달.
**이유**: 토큰 절약. 최근 패턴이 장기 이력보다 코칭에 유의미. 추이 데이터(일별 rep, 세트, 세트당 평균)로 경향성 기반 조언 가능.

**2026-04-24 업데이트 (task 6-coaching-generator)**: 비로그인 분기 AI 코칭 샘플은 `CoachingSamples.swift` 내 정적 카피 2종 하드코딩을 제거하고, Foundation-only pure struct `CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 `WorkoutSession` 기반으로 결정론적 생성.
- 템플릿 수: **6개 base** (goal 3종(weightLoss/strength/bodyShape) × kind 2종(pre/post)). 기록유무(최근 7일 내 `totalReps > 0` 세션 존재 여부) 와 `bodyType` 은 같은 템플릿 내부의 **문자열 인터폴레이션 분기** 로 처리 (템플릿 개수 증분 없음). 10개 한도 엄수 — 초과 시 재승인 티켓.
- 생성 경로: `CoachingView.notLoggedInContent` 가 `@Query UserProfile` + `@Query WorkoutSession` 결과를 Foundation-only intermediate struct(`CoachingGenInput`, `CoachingGenSession`) 로 변환 → `CoachingSampleGenerator.generate(input:now:)` 호출 → `[CoachingSample]`(pre 1 + post 1) 반환. `@Model` 타입을 generator 가 직접 참조하지 않음(테스트 결정론 + SwiftData 의존 격리).
- **프로필 nil(온보딩 미완) 폴백**: 하드코딩 샘플 재사용 **금지**. 카드 자체를 숨기고 "온보딩을 먼저 완료해주세요" CTA 만 노출. 이 폴백이 generic 복귀 경로가 되면 이번 delta 의 목적이 무력화됨.
- 카드 하단 disclaimer 현행 유지 ("※ 예시 피드백 (실제 데이터 기반으로 매번 다름)"). "로그인하면 Claude AI 기반 더 정교한 분석 가능" 유도 문구 **삽입 금지** (비로그인 단계에서 "이거 가짜구나" 역효과).
- 로그인 유저 경로(`POST /coaching/request` → 서버 → Claude API) 및 7일 context 계약은 **완전 불변** (ADR-006 원문 + ADR-012 유지). 이번 update 는 **비로그인 분기 한정**.
- 트레이드오프: (a) 템플릿 결정론 = 동일 입력 → 동일 출력이라 "다양성" 이 없음. 대신 입력(프로필/기록)이 바뀌면 출력이 바뀌므로 "내 상황 반영" 이 ChatGPT 대비 증거가 됨. (b) 7일 외 세션은 집계에서 제외 (ADR-006 원칙 준수). (c) `totalReps == 0` autosave 세션(ADR-009 task 5 delta) 은 기록유무 판정에서도 제외.
- 측정: phase 1 배포 후 차기 iter 시뮬(`ideation` → `persuasion-review`) 에서 keyman 의 "그거면 ChatGPT 쓰지" / "하드코딩 정적 카피" 언급이 report 개선 포인트에서 제거되는지 확인.

### ADR-007: 다크모드 고정
**결정**: 시스템 설정 무시, 다크모드만 지원.
**이유**: 무채색 기반 디자인이 다크모드에서 가장 자연스러움. 라이트/다크 두 벌 디자인 불필요 → 개발 속도 향상.

### ADR-008: 운동 선택 UI는 있되 내부 처리는 스쿼트 통일
**SUPERSEDED by ADR-017** — 스쿼트 전용 포지셔닝으로 전환. 운동 선택 UI 자체가 제거됨.
**결정**: 4종 운동 선택 UI 제공, 내부적으로 전부 스쿼트로 처리.
**이유**: UI 완성도 + 확장 가능성 확보. 사용자 입장에서 앱이 "하나만 되는 앱"으로 보이지 않게. 실제 운동별 판정 로직은 검증 후 점진적 추가.

### ADR-009: MVP 의도적 제외 목록
- 카메라 미인식 시 안내 → 사용자가 직접 위치 조정
- 세트 완료 진동 → 촉각 피드백은 후순위
- 앱 종료 시 운동 데이터 복구 → 복잡도 대비 발생 빈도 낮음
- SwiftData 마이그레이션 → 출시 전 스키마 확정으로 회피

**2026-04-24 업데이트 (task 5-rep-autosave)**: "앱 종료 시 운동 데이터 복구 → 발생 빈도 낮음" 항목의 delta — rep 단위 autosave 도입(비로그인 유저 한정).
- persist 시점을 **세트 종료 시 1회 insert** → **세션(TrackingView lifecycle) 첫 세트 시작 시 1회 insert + 매 rep 증가 시 `WorkoutSession.repCounts` snapshot update + `try? modelContext.save()`** 로 이동.
- `WorkoutSession` 스키마 **불변**. `isInProgress` 플래그 추가 금지. 복구 UI / "이어하기" 시트 / HomeView 재개 버튼 / `workout_interrupted_*` analytics 이벤트 / UserDefaults 별도 저장 경로 **모두 여전히 제외**.
- 로그인 유저 경로는 불변 — 서버 `POST /sessions` 로 세트 종료 시 1회 저장 (ADR-013, ADR-014 유지).
- 트레이드오프: (a) 0rep 빈 세션이 SwiftData 에 기록될 수 있음 → `RecordsView` 에서 `$0.totalReps > 0` 메모리 필터로 숨김. (b) `WorkoutSession.repCounts` 의 마지막 요소는 tracking 중에는 "진행 중 세트의 임시 snapshot", `completeSet` / `stopSession` 이후에는 "확정된 세트 합계" 로 상태가 바뀐다. 독자 혼동 방지를 위해 `docs/spec.md §3.1` 에 주석 추가.
- Phase 2(이어하기 UI) 트리거 임계는 `workout_set_started` / `workout_set_completed` Mixpanel 이벤트 비율 5% 주간 초과. **단 현재 `AnalyticsService` 미도입 상태** — Phase 2 는 analytics 인프라 선행 후 별건 티켓으로 다룬다.

### ADR-010: 커스텀 JWT 인증 (Supabase Auth 미사용)
**결정**: Supabase는 순수 DB로만 사용. bcrypt + JWT를 서버에서 직접 구현.
**이유**: Supabase Auth의 이메일 기반 로그인이 제공하는 기능 대비, 직접 구현이 더 간단하고 제어 가능. 의존성 최소화.
**트레이드오프**: 세션 관리, 토큰 갱신을 직접 구현해야 하지만, scope이 작아 부담 없음.

### ADR-011: 서버 아키텍처 (Node.js + Express + Railway)
**결정**: Node.js + Express로 REST API 서버 구축, Railway에 배포.
**이유**: 단순한 CRUD + 인증 서버에 적합. Railway의 Node.js 지원이 안정적.
**범위**: 인증 (signup/login), 데이터 CRUD (profile/sessions/feedbacks), Claude API 프록시.

### ADR-012: Claude API 서버 프록시
**결정**: 기존 앱 내 직접 Claude API 호출을 서버 경유로 전환.
**이유**: API 키가 앱 바이너리에 포함되는 보안 위험 제거. 서버에서 사용량 제어 가능.
**변경**: ClaudeAPIService는 더 이상 Anthropic API를 직접 호출하지 않음. 서버의 `/coaching/request` 엔드포인트를 호출.

### ADR-013: 로그인/비로그인 데이터 분기
**결정**: 로그인 유저는 서버 API, 비로그인 유저는 SwiftData. 로컬→서버 마이그레이션 없음.
**이유**: 동기화 복잡도 회피. MVP 단계에서 사용자 데이터가 적음.
**트레이드오프**: 비로그인 상태에서 쌓은 데이터는 로그인해도 서버로 이전되지 않음.

### ADR-014: 네트워크 실패 시 에러 알림만 (로컬 임시 저장 없음)
**결정**: 운동 완료 후 서버 저장 실패 시 에러 알림만 표시. 로컬 임시 저장 + 재시도 없음.
**이유**: 오프라인 동기화는 MVP scope 초과. 운동 자체는 로컬에서 완료되므로 치명적이지 않음.

### ADR-015: Mixpanel을 유저 행동분석 도구로 채택
**결정**: Mixpanel iOS SDK를 SPM으로 추가하여 유저 행동분석 로그를 수집한다. 이 프로젝트 최초의 외부 의존성이다.
**이유**: 행동분석에 가장 특화된 product analytics 도구. iOS SDK가 10년 이상 검증됨. 무료 20M events/month로 MVP에 충분. SPM 지원으로 project.yml에 추가하면 끝. YC 스타트업 채택률 높음.
**트레이드오프**: ADR-001의 "외부 의존성 0" 원칙에 대한 첫 예외. 행동분석은 Apple 네이티브 대안이 없으므로 불가피.
**대안 검토**: Firebase Analytics(plist 설정 복잡, CLI 완결 불가), Amplitude(행동분석 UX가 Mixpanel보다 약간 열세), PostHog(모바일 SDK 성숙도 낮음).

### ADR-016: 스쿼트 외 운동은 "준비중" UI로 공개 (ADR-008 보완)
**SUPERSEDED by ADR-017** — "준비중" UI 자체가 제거됨. 스쿼트 전용 포지셔닝으로 전환.
**결정**: ExercisePicker에서 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4의 비활성화 톤으로 표시. tap 자체는 차단하지 않되, selected 전환/화면 dismiss 대신 토스트 "현재는 스쿼트만 지원합니다"만 1.5초 노출하고 트래킹 진입은 차단.
**이유**: ADR-008("UI는 있되 내부 전부 스쿼트 통일")은 3일 체험 페르소나가 푸쉬업을 한 번만 눌러봐도 기대 불일치가 드러나 즉시 삭제 트리거가 됨 (시뮬 run_id: home-workout-newbie-20s_20260424_153242). 기능 다양성 과시보다 신뢰도 우선.
**트레이드오프**: 운동별 판정 로직이 추가될 때까지 선택지 다양성 축소. 셀 tap 자체는 남겨둬 향후 재활성화 시 회귀 테스트 누락 리스크를 줄임. 토스트 카피에는 출시 일정·확장 계획 등 미래 약속 문구 금지.

### ADR-017: 스쿼트 전용 포지셔닝 확정 (ADR-008, ADR-016 대체)
**결정**: ExercisePickerView 파일 삭제 + HomeView의 운동 종류 선택 드롭다운 제거. "스쿼트 시작" 고정 CTA 로 전환. 랜딩/README/docs 카피에서 "홈트/운동 종류" 언어를 "스쿼트"로 정돈. 미래 약속 문구(지원 예정·출시 예정·계획 등) 금지.
**이유**: iter 4 설득력 검토(run_id: home-workout-newbie-20s_20260424_193756)에서 "홈트 기대 설치 → 3일 안에 스쿼트 전용임 인지 → 무료 스쿼트 카운터로 전환" 이탈 경로가 keyman 최종 판정 실패의 독립적 reject 사유. "준비중" UI 를 남겨두는 것만으로도 `personality_notes`("3일 써보고 아니면 삭제") + `switching_cost: low` 경쟁재 조건에서 기대 불일치가 드러남. 포지셔닝 자체를 스쿼트 전용으로 좁혀 기대-실제 갭을 제거.
**트레이드오프**: 푸쉬업/싯업 확장 시 운동 종류 선택 UI/상태를 복구해야 함. 단, `TrackingViewModel.exerciseType` 분기 + `PushUpCounter.swift`/`SitUpCounter.swift` 내부 판정 자산은 보존(CTO 조건부 #1)하여 재활성화 비용 최소화. 이번 삭제는 View 레이어 한정.
**범위**: `Mofit/Views/Home/ExercisePickerView.swift` 파일 삭제, `Mofit/Views/Home/HomeView.swift` 에서 `exerciseSelector`·`showExercisePicker`·`selectedExerciseName` 상태 제거. `TrackingView(exerciseType: "squat", ...)` 호출로 하드코딩. ADR-008/ADR-016 은 SUPERSEDED 표기 유지(역사 보존).

### ADR-018: 트래킹 미검출 진단 힌트 (2종 고정)
**결정**: 트래킹 상태에서 최근 3초간 **양쪽(left/right) hip/knee/ankle 어느 쪽도 3조인트 모두 검출되지 않고** 현재 세션 rep 카운트가 0 이면 상단 반투명 힌트 배너를 1줄로 노출(.outOfFrame). 그 외 조건에서 하체 조인트 평균 confidence < 0.5 가 3초 지속되면 .lowLight. 우선순위 outOfFrame. 트래킹 시작 후 5초 grace. 한 세션(= TrackingView lifecycle) 내 rep 한 번이라도 카운트되면 힌트 숨김 + 이후 재표시 금지. 세트 경계에서 리셋 금지. `DiagnosticHint` enum 은 `.outOfFrame` / `.lowLight` 2종 고정.
**이유**: iter 5 설득력 시뮬(run_id: `home-workout-newbie-20s_20260424_210609`, keyman `decision: drop`, `confidence: 55`) 에서 `tech_literacy: medium` 페르소나가 `personality_notes`("3일 써보고 아니면 삭제") 조건에서 "왜 안 세어지나요?" 를 혼자 추정해야 하는 부담이 reject 사유. 가치제안 §5.2 "실패 가이드 UI 얕음" 자체 고지를 인앱에서 증명.
**트레이드오프**: 힌트 노출 레이턴시 최소 5+3=8초. 1초 슬롯마다 판정하면 false positive 과다 + 배터리 낭비. 3초 sustain 으로 프레임 튐 흡수. lowLight 임계치 0.5 는 v1 경계값, 튜닝은 실사용 데이터 누적 후 v2.
**범위**: `Mofit/Services/PoseDetectionService.swift` 에 `PoseFrameResult` struct + `detectPoseDetailed(in:)` 메서드 신규, 기존 `detectPose(in:)` + `extractJoints` 삭제. `Mofit/ViewModels/TrackingViewModel.swift` 에 `DiagnosticHint` enum(2 case), `@Published var diagnosticHint`, `private enum Diagnostic`(카피·임계치 상수), `private struct DiagnosticHintEvaluator`(Foundation 만 사용하는 pure struct) 추가. `Mofit/Views/Tracking/TrackingView.swift` 에 `hintBanner(hint:)` private subview + ZStack 오버레이 추가. 상수·카피는 TVM `private enum Diagnostic` 한 곳에만 두며 `ConfigService` 신규 레이어 금지. `DiagnosticHint` 에 third case / 프로토콜 / 전략 패턴 도입 금지.
**연계**: ADR-017 로 스쿼트 전용 포지셔닝이 확정됐으나, 진단 로직은 exercise-agnostic(`TrackingViewModel.currentReps` 및 `hasCompleteSideForSquat` 네이밍은 squat 기준 발화이나 pushup/situp 에서도 동일 임계치로 동작). 튜닝은 v2.
**테스트**: `DiagnosticHintEvaluator` 를 Foundation 외 import 없는 pure struct 로 추출, phase1 에이전트가 구현 직후 6개 시나리오(grace / sustain / 중간 회복 / rep 후 숨김 / lowLight / 우선순위) 를 코드 트레이스로 검증. `MofitTests` 타겟 신설 금지(task 0~3 전례 유지). 실기기 QA 는 merge 전 1회: (a) 정상 환경 3rep 카운트, (b) 프레임 이탈 시 3~5초 내 .outOfFrame 배너 출현. 조도 케이스 실기기 생략 가능.
