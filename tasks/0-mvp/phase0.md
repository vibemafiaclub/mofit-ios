# Phase 0: 프로젝트 세팅

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `/docs/prd.md`
- `/docs/code-architecture.md`
- `/docs/adr.md`

## 작업 내용

### 1. 디렉토리 구조 생성

`Mofit/` 하위에 아래 디렉토리를 생성하라:

```
Mofit/
├── App/
├── Models/
├── Views/
│   ├── Onboarding/
│   ├── Home/
│   ├── Tracking/
│   ├── Records/
│   ├── Coaching/
│   └── Profile/
├── ViewModels/
├── Services/
├── Camera/
├── Config/
└── Utils/
```

### 2. xcodegen spec 작성

프로젝트 루트에 `project.yml` 파일을 생성하라. 아래 요구사항을 반영:

- **프로젝트 이름**: Mofit
- **deployment target**: iOS 17.0
- **Swift 버전**: 5.9 이상
- **소스 경로**: `Mofit/`
- **Info.plist 설정**:
  - `NSCameraUsageDescription`: "운동 자세를 추적하기 위해 카메라가 필요합니다"
  - `UIUserInterfaceStyle`: `Dark` (다크모드 고정)
- **프레임워크**: SwiftUI, SwiftData, AVFoundation, Vision (모두 시스템 프레임워크)
- **scheme**: Mofit (Debug/Release)

`project.yml` 작성 후 `xcodegen generate`를 실행하여 `Mofit.xcodeproj`를 생성하라.

### 3. placeholder 파일 생성

이후 phase에서 빌드가 통과하도록 `Mofit/App/MofitApp.swift`에 최소한의 @main SwiftUI App을 작성하라:

```swift
// 최소한의 앱 진입점. Phase 2에서 온보딩 분기 + TabView로 교체 예정.
@main
struct MofitApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Mofit")
        }
    }
}
```

### 4. Theme.swift

`Mofit/Utils/Theme.swift` 생성:

- `neonGreen`: 형광초록 Color (예: `Color(red: 0.2, green: 1.0, blue: 0.4)` 또는 적절한 형광초록 hex)
- `darkBackground`: 다크모드 배경색
- `cardBackground`: 카드/시트 배경색 (약간 밝은 회색)
- `textPrimary`: 흰색
- `textSecondary`: 회색
- 모든 색상은 `static let`으로 정의. enum `Theme`에 네임스페이스.

### 5. Secrets 설정

`Mofit/Config/Secrets.swift` 생성:
```swift
enum Secrets {
    static let claudeAPIKey = "YOUR_API_KEY_HERE"
}
```

`Mofit/Config/Secrets.example.swift` 생성 (위와 동일한 구조, 실제 키 없이 placeholder):
```swift
// Secrets.swift를 복사하여 실제 API key를 입력하세요.
// 이 파일은 git에 포함됩니다. Secrets.swift는 .gitignore에 의해 제외됩니다.
enum Secrets {
    static let claudeAPIKey = "YOUR_API_KEY_HERE"
}
```

### 6. .gitignore 업데이트

기존 `.gitignore`에 아래 항목을 추가하라:

```
# Xcode
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
DerivedData/
*.xcworkspace
build/

# Secrets
Mofit/Config/Secrets.swift

# macOS
.DS_Store
```

## Acceptance Criteria

```bash
cd /Users/choesumin/Desktop/dev/mofit-ios && xcodegen generate && xcodebuild build -project Mofit.xcodeproj -scheme Mofit -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5
```

위 명령어 실행 시 **BUILD SUCCEEDED** 출력 확인.

## AC 검증 방법

위 AC 커맨드를 실행하라. 모두 통과하면 `/tasks/0-mvp/index.json`의 phase 0 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 에러 내용을 index.json의 해당 phase에 `"error_message"` 필드로 기록하라.

## 주의사항

- `Secrets.swift`가 절대로 git에 포함되지 않도록 `.gitignore`를 먼저 업데이트하고 나서 `Secrets.swift`를 생성하라.
- xcodegen spec에서 `INFOPLIST_KEY_UIUserInterfaceStyle`를 `Dark`로 설정하여 다크모드를 강제하라.
- 이 phase에서는 Models, Views, ViewModels 등의 실제 코드를 작성하지 마라. 디렉토리 구조와 빌드 환경만 세팅한다.
- xcodegen이 생성한 `.xcodeproj`는 git에 포함해도 된다 (팀원이 xcodegen 없이도 빌드 가능하도록).
