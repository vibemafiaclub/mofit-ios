# 데이터 스키마 (SwiftData)

## 모델

### UserProfile
싱글톤. 앱 전체에서 1개만 존재.
```swift
@Model class UserProfile {
    var gender: String          // "male" | "female"
    var height: Double          // cm
    var weight: Double          // kg
    var bodyType: String        // "slim" | "normal" | "muscular" | "chubby"
    var goal: String            // "weightLoss" | "strength" | "bodyShape"
    var onboardingCompleted: Bool
}
```

### WorkoutSession
운동 1회 = 1 세션. 하루에 여러 세션 가능.
```swift
@Model class WorkoutSession {
    var id: UUID
    var exerciseType: String    // "squat" (MVP에서는 전부 이 값)
    var startedAt: Date
    var endedAt: Date
    var totalDuration: Int      // 초. 첫 카운트다운 시작 ~ 종료 버튼
    var repCounts: [Int]        // 세트별 rep. [12, 10, 8] = 3세트
}
```
- 별도 WorkoutSet 모델 없음. repCounts 배열로 단순화.
- `세트 수 = repCounts.count`, `총 rep = repCounts.sum()`

### CoachingFeedback
```swift
@Model class CoachingFeedback {
    var id: UUID
    var date: Date              // 날짜 (하루 2회 제한 체크용)
    var type: String            // "pre" | "post"
    var content: String         // AI 응답 전문
    var createdAt: Date
}
```

## AI 코칭 Context 구조
Claude API 호출 시 넘기는 데이터:
```
사용자: { gender, height, weight, bodyType, goal }
최근 7일 요약: { 운동일수, 총세션, 총rep, 일평균rep }
추이 (일별): { rep[], 세트수[], 세트당평균rep[] }
```
토큰 절약을 위해 7일로 제한. 추이 데이터로 AI가 경향성 기반 조언 가능.

---

## 서버 측 스키마 (Supabase PostgreSQL)

로그인 유저의 데이터는 Supabase DB에 저장된다. 비로그인 유저는 기존 SwiftData(로컬) 사용.

### `users` 테이블
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK, default gen_random_uuid()) | 유저 고유 ID |
| email | text (UNIQUE, NOT NULL) | 이메일 (로그인 ID) |
| password_hash | text (NOT NULL) | bcrypt 해싱된 비밀번호 |
| created_at | timestamptz (default now()) | 가입 시각 |

### `user_profiles` 테이블
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK, default gen_random_uuid()) | |
| user_id | uuid (FK → users.id, UNIQUE, NOT NULL) | |
| gender | text (NOT NULL) | male / female |
| height | double precision (NOT NULL) | cm |
| weight | double precision (NOT NULL) | kg |
| body_type | text (NOT NULL) | slim / normal / muscular / chubby |
| goal | text (NOT NULL) | weightLoss / strength / bodyShape |
| coach_style | text (NOT NULL, default 'warm') | tough / warm / analytical |
| created_at | timestamptz (default now()) | |
| updated_at | timestamptz (default now()) | |

### `workout_sessions` 테이블
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK, default gen_random_uuid()) | |
| user_id | uuid (FK → users.id, NOT NULL) | |
| exercise_type | text (NOT NULL) | squat / pushup / situp |
| started_at | timestamptz (NOT NULL) | |
| ended_at | timestamptz (NOT NULL) | |
| total_duration | integer (NOT NULL) | 초 단위 |
| rep_counts | integer[] (NOT NULL) | 세트별 반복 수 배열 |
| created_at | timestamptz (default now()) | |

### `coaching_feedbacks` 테이블
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK, default gen_random_uuid()) | |
| user_id | uuid (FK → users.id, NOT NULL) | |
| date | date (NOT NULL) | 피드백 날짜 |
| type | text (NOT NULL) | pre / post |
| content | text (NOT NULL) | Claude 응답 본문 |
| created_at | timestamptz (default now()) | |

### 인덱스
- `workout_sessions(user_id, started_at)` — 날짜별 조회 최적화
- `coaching_feedbacks(user_id, date)` — 일일 사용량 체크 최적화
