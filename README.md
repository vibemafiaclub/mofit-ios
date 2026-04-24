# Mofit

AI 기반 실시간 운동 자세 분석 및 코칭 iOS 앱

> Made by VibeMatfia. [(제작 영상)](https://www.youtube.com/watch?v=F9a69NsgnVQ)

## 소개

Mofit은 iPhone 카메라와 Apple Vision 프레임워크를 활용하여 사용자의 운동 자세를 실시간으로 분석하고, Claude AI를 통해 개인 맞춤형 코칭 피드백을 제공하는 피트니스 앱입니다.

## 주요 기능

- **실시간 자세 분석** — Vision 프레임워크로 15개 이상의 관절을 추적하여 운동 폼을 실시간 분석
- **자동 레프 카운팅** — 무릎 각도 기반으로 스쿼트 횟수를 자동 측정
- **제스처 컨트롤** — 손바닥 펼침 인식으로 세트 완료 등 핸즈프리 조작
- **AI 코칭** — Claude AI가 운동 이력과 사용자 프로필을 기반으로 맞춤형 피드백 제공
- **코치 스타일 선택** — 강한 동기부여 / 따뜻한 격려 / 데이터 분석형 중 선호 스타일 선택
- **운동 기록 관리** — 날짜별 운동 세션 기록 조회

## 기술 스택

| 항목        | 기술                          |
| ----------- | ----------------------------- |
| UI          | SwiftUI                       |
| 데이터      | SwiftData                     |
| 자세 인식   | Vision (Human Pose Detection) |
| 제스처 인식 | Vision (Hand Pose Detection)  |
| 카메라      | AVFoundation                  |
| AI 코칭     | Anthropic Claude API          |
| 빌드        | XcodeGen                      |
| 아키텍처    | MVVM                          |

## 요구 사항

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## 설치 및 실행

```bash
# 1. 저장소 클론
git clone https://github.com/your-org/mofit-ios.git
cd mofit-ios

# 2. API 키 설정
cp Mofit/Config/Secrets.example.swift Mofit/Config/Secrets.swift
# Secrets.swift에 Anthropic API 키 입력

# 3. Xcode 프로젝트 생성
xcodegen generate

# 4. Xcode에서 열기
open Mofit.xcodeproj
```

## 프로젝트 구조

```
Mofit/
├── App/            # 앱 진입점, 루트 뷰 라우팅
├── Camera/         # 카메라 캡처 및 프리뷰
├── Config/         # API 키 등 설정
├── Models/         # SwiftData 모델 (UserProfile, WorkoutSession, CoachingFeedback)
├── Services/       # 핵심 비즈니스 로직
│   ├── PoseDetectionService    # 자세 인식
│   ├── HandDetectionService    # 손 제스처 인식
│   ├── SquatCounter            # 레프 카운팅
│   ├── ClaudeAPIService        # AI 코칭 API
│   └── CameraManager           # 카메라 세션 관리
├── Utils/          # 테마 설정
├── ViewModels/     # 상태 관리 (TrackingVM, CoachingVM)
└── Views/          # SwiftUI 화면
    ├── Coaching/       # AI 코칭
    ├── Home/           # 홈 (운동 시작, 오늘의 요약)
    ├── Onboarding/     # 온보딩 (프로필 설정)
    ├── Profile/        # 프로필 편집
    ├── Records/        # 운동 기록
    └── Tracking/       # 실시간 운동 추적
```

## 자율 주행 하네스

이 레포는 [`greatSumini/cc-system`](https://github.com/greatSumini/cc-system) 의 자율 주행 하네스를 사용한다. `python3 scripts/run-server.py` 가 ideation → plan-and-build → commit → build-check → rollback 루프를 반복하면서 `iterations/<N>-<timestamp>/` 하위에 산출물을 쌓는다.

- **트리거**: 사용자가 로컬에서 `run-server.py` 를 실행 (CI/자동 기동 아님).
- **컨텍스트 파일**: `docs/mission.md`, `docs/spec.md`, `docs/testing.md`, `docs/user-intervention.md`, `persuasion-data/personas/*`. 하네스가 이들을 주 참조서로 쓴다.
- **무인 모드**: `run-server.py` 가 자식 claude 세션에 `HARNESS_HEADLESS=1` 을 주입하면 skill 들이 사용자 확인 단계를 모두 자동 승인한다. 수동 쉘에서 이 변수를 직접 export 하지 말 것.
- **출력**: `iterations/*/requirement.md`(아이디에이션 결과), `iterations/*/check-report.json`, `tasks/<id>/phaseN.md` (구현 계획).

## 라이선스

All rights reserved.
