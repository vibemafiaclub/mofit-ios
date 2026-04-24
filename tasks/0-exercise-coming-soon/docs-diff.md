# docs-diff: exercise-coming-soon

Baseline: `1e095c4`

## `docs/adr.md`

```diff
diff --git a/docs/adr.md b/docs/adr.md
index 2cd4bc6..ca641c6 100644
--- a/docs/adr.md
+++ b/docs/adr.md
@@ -77,3 +77,8 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 **이유**: 행동분석에 가장 특화된 product analytics 도구. iOS SDK가 10년 이상 검증됨. 무료 20M events/month로 MVP에 충분. SPM 지원으로 project.yml에 추가하면 끝. YC 스타트업 채택률 높음.
 **트레이드오프**: ADR-001의 "외부 의존성 0" 원칙에 대한 첫 예외. 행동분석은 Apple 네이티브 대안이 없으므로 불가피.
 **대안 검토**: Firebase Analytics(plist 설정 복잡, CLI 완결 불가), Amplitude(행동분석 UX가 Mixpanel보다 약간 열세), PostHog(모바일 SDK 성숙도 낮음).
+
+### ADR-016: 스쿼트 외 운동은 "준비중" UI로 공개 (ADR-008 보완)
+**결정**: ExercisePicker에서 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4의 비활성화 톤으로 표시. tap 자체는 차단하지 않되, selected 전환/화면 dismiss 대신 토스트 "현재는 스쿼트만 지원합니다"만 1.5초 노출하고 트래킹 진입은 차단.
+**이유**: ADR-008("UI는 있되 내부 전부 스쿼트 통일")은 3일 체험 페르소나가 푸쉬업을 한 번만 눌러봐도 기대 불일치가 드러나 즉시 삭제 트리거가 됨 (시뮬 run_id: home-workout-newbie-20s_20260424_153242). 기능 다양성 과시보다 신뢰도 우선.
+**트레이드오프**: 운동별 판정 로직이 추가될 때까지 선택지 다양성 축소. 셀 tap 자체는 남겨둬 향후 재활성화 시 회귀 테스트 누락 리스크를 줄임. 토스트 카피에는 "곧 지원됩니다" 같은 미래 약속 문구 금지.
```

## `docs/prd.md`

```diff
diff --git a/docs/prd.md b/docs/prd.md
index 629bdf1..b938e71 100644
--- a/docs/prd.md
+++ b/docs/prd.md
@@ -31,8 +31,8 @@ MVP를 빠르게 출시하여 시장 반응을 검증한다 (YC 지원 대상).
 - 운동 종료 후 복귀 시 폭죽 효과
 
 ### 운동 선택 (바텀시트)
-- 2열 그리드: 스쿼트 / 푸쉬업 / 런지 / 플랭크
-- MVP에서는 전부 내부적으로 스쿼트로 처리
+- 2열 그리드: 스쿼트 / 푸쉬업 / 싯업 (실코드 기준)
+- MVP에서는 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4로 비활성화 톤, tap 시 토스트 "현재는 스쿼트만 지원합니다"만 표시하고 트래킹 진입 차단. (ADR-016)
 
 ### 트래킹 화면
 - 전체화면 카메라 프리뷰 + 오버레이
```

## `docs/spec.md`

```diff
diff --git a/docs/spec.md b/docs/spec.md
index 200ccba..6550f1d 100644
--- a/docs/spec.md
+++ b/docs/spec.md
@@ -29,7 +29,7 @@ MofitApp
 
 - `OnboardingView` — 단계별(성별→키→몸무게→체형→목표)
 - `HomeView` — 오늘 요약 + 운동 시작
-- `ExercisePickerView` — 바텀시트 2열 그리드 (스쿼트/푸쉬업/런지/플랭크)
+- `ExercisePickerView` — 바텀시트 2열 그리드 (스쿼트/푸쉬업/싯업). 스쿼트만 active, 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4로 비활성화 톤, tap 시 토스트 "현재는 스쿼트만 지원합니다"만 표시. (ADR-016)
 - `TrackingView` — 카메라 프리뷰 + 오버레이 + 상태머신
 - `RecordsView` — 날짜바 + 세션 리스트
 - `CoachingView` — AI 피드백 카드 + 운동 전/후 버튼
```
