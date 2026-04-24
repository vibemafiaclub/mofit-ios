# cc-company Testing Strategy

## 원칙

- **순수 로직에 집중**: mock으로 접착제 코드를 테스트하지 않는다. 구현을 두 번 쓰는 것이지 동작을 검증하는 게 아니다.
- **커버리지 숫자 목표 없음**: 숫자를 채우기 위한 mock 테스트 양산은 시간 낭비. 깨지면 치명적인 분기만 커버.
- **구현과 테스트를 함께 작성**: 모듈 구현 직후 해당 테스트를 작성한다. 일괄 작성 금지.

- 중요!: 테스트는 해당 모듈 구현 직후 바로 작성한다. 구현 계획에 테스트 작성 시점이 명시된다.

---

## XCTest 타겟

`MofitTests` 타겟은 **iter 7(task 6-coaching-generator) 에서 신설**. 이전 task 0~5 의 "MofitTests 타겟 신설 금지" 선례는 **명시적으로 폐기**한다 (iter 7 CTO 조건 1: "실기기 QA 필수화 금지 + XCTest 2케이스 CI 통과 조건").

- **범위**: Foundation-only pure struct 의 회귀 방지용. `@Model` / SwiftData / UIKit / AVFoundation / Vision / 네트워크 의존 코드는 여전히 테스트 대상 아님 (mock 재작성이 구현 중복).
- **현재 유일 대상**: `CoachingSampleGenerator` (Foundation-only, 입력 결정론적). 2 케이스 — (a) 빈 세션 + 프로필 인터폴레이션 포함 확인, (b) rep 수 인터폴레이션 포함 확인.
- **파일 위치**: `MofitTests/<TypeName>Tests.swift` 1파일 1타입. 접근은 `@testable import Mofit` 로 internal 심볼 사용 (public 노출 금지).
- **CI 실행**: `xcodebuild -scheme Mofit test -destination "platform=iOS Simulator,name=<iPhone ...>"`. destination 은 `xcrun simctl list devices available` 결과에서 동적으로 선택하거나 `iPhone 16` 폴백.
- **외부 의존 금지**: Nimble / Quick / Sourcery / Mockingbird 등 테스트 보조 SPM 도입 금지. XCTest 내장만 사용 (ADR-015 외부 의존성 최소화 원칙 유지).
- **확장 정책**: 다른 모듈 회고 테스트는 각 모듈 변경 시점에 함께 추가(원칙 9행 유지). 이 target 을 "전 모듈 커버리지"로 부풀리지 않음.
