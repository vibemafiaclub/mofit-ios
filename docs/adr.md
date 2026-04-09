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

### ADR-007: 다크모드 고정
**결정**: 시스템 설정 무시, 다크모드만 지원.
**이유**: 무채색 기반 디자인이 다크모드에서 가장 자연스러움. 라이트/다크 두 벌 디자인 불필요 → 개발 속도 향상.

### ADR-008: 운동 선택 UI는 있되 내부 처리는 스쿼트 통일
**결정**: 4종 운동 선택 UI 제공, 내부적으로 전부 스쿼트로 처리.
**이유**: UI 완성도 + 확장 가능성 확보. 사용자 입장에서 앱이 "하나만 되는 앱"으로 보이지 않게. 실제 운동별 판정 로직은 검증 후 점진적 추가.

### ADR-009: MVP 의도적 제외 목록
- 카메라 미인식 시 안내 → 사용자가 직접 위치 조정
- 세트 완료 진동 → 촉각 피드백은 후순위
- 앱 종료 시 운동 데이터 복구 → 복잡도 대비 발생 빈도 낮음
- SwiftData 마이그레이션 → 출시 전 스키마 확정으로 회피

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
