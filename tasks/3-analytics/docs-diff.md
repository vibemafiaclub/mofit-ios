# docs-diff: analytics

Baseline: `9b74e77`

## `docs/adr.md`

```diff
diff --git a/docs/adr.md b/docs/adr.md
index db695d1..2cd4bc6 100644
--- a/docs/adr.md
+++ b/docs/adr.md
@@ -71,3 +71,9 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 ### ADR-014: 네트워크 실패 시 에러 알림만 (로컬 임시 저장 없음)
 **결정**: 운동 완료 후 서버 저장 실패 시 에러 알림만 표시. 로컬 임시 저장 + 재시도 없음.
 **이유**: 오프라인 동기화는 MVP scope 초과. 운동 자체는 로컬에서 완료되므로 치명적이지 않음.
+
+### ADR-015: Mixpanel을 유저 행동분석 도구로 채택
+**결정**: Mixpanel iOS SDK를 SPM으로 추가하여 유저 행동분석 로그를 수집한다. 이 프로젝트 최초의 외부 의존성이다.
+**이유**: 행동분석에 가장 특화된 product analytics 도구. iOS SDK가 10년 이상 검증됨. 무료 20M events/month로 MVP에 충분. SPM 지원으로 project.yml에 추가하면 끝. YC 스타트업 채택률 높음.
+**트레이드오프**: ADR-001의 "외부 의존성 0" 원칙에 대한 첫 예외. 행동분석은 Apple 네이티브 대안이 없으므로 불가피.
+**대안 검토**: Firebase Analytics(plist 설정 복잡, CLI 완결 불가), Amplitude(행동분석 UX가 Mixpanel보다 약간 열세), PostHog(모바일 SDK 성숙도 낮음).
```

## `docs/code-architecture.md`

```diff
diff --git a/docs/code-architecture.md b/docs/code-architecture.md
index 66a769e..abbb8f3 100644
--- a/docs/code-architecture.md
+++ b/docs/code-architecture.md
@@ -38,7 +38,8 @@ Mofit/
 │   ├── PoseDetectionService.swift  # VNDetectHumanBodyPoseRequest 래퍼
 │   ├── HandDetectionService.swift  # VNDetectHumanHandPoseRequest 래퍼
 │   ├── SquatCounter.swift          # 관절 각도 → rep 판정
-│   └── ClaudeAPIService.swift      # Claude API 호출
+│   ├── ClaudeAPIService.swift      # Claude API 호출
+│   └── AnalyticsService.swift      # Mixpanel 래퍼. 이벤트 추적, 유저 식별
 │
 ├── Camera/
 │   ├── CameraManager.swift         # AVCaptureSession 설정/관리
@@ -125,6 +126,14 @@ Mofit/Services/
 └── ClaudeAPIService.swift # (기존) → 로그인 시 서버 프록시 경유로 변경
 ```
 
+## AnalyticsService
+
+Mixpanel SDK를 감싸는 싱글톤 서비스.
+
+- `AnalyticsEvent` enum으로 이벤트명을 타입 안전하게 관리.
+- 앱 시작 시 `MofitApp.init()`에서 초기화.
+- 로그인/로그아웃 시 `identify(userId:)` / `reset()` 호출로 유저 식별.
+
 ## 배포 URL
 
 - **서버 (Railway)**: https://server-production-45a4.up.railway.app
```
