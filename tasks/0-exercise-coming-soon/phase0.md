# Phase 0: docs

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/mission.md`
- `docs/prd.md`
- `docs/spec.md` (특히 §1.3 화면 목록)
- `docs/adr.md` (특히 ADR-008, ADR-015)
- `docs/code-architecture.md`
- `docs/flow.md`
- `docs/testing.md`
- `docs/user-intervention.md`
- `iterations/1-20260424_153124/requirement.md` (이번 iteration 원문 — 수정 금지)

## 작업 내용

이번 iteration의 UI 변경을 문서 레이어에 먼저 반영한다. **실코드는 Phase 1에서 수정한다.**
본 phase에서는 `docs/`만 건드리고, 다른 디렉토리는 절대 변경하지 않는다.

### 1. `docs/prd.md` — "운동 선택 (바텀시트)" 섹션 (현재 L33~L35)

아래 블록을 그대로 교체하라.

**기존**:
```markdown
### 운동 선택 (바텀시트)
- 2열 그리드: 스쿼트 / 푸쉬업 / 런지 / 플랭크
- MVP에서는 전부 내부적으로 스쿼트로 처리
```

**신규**:
```markdown
### 운동 선택 (바텀시트)
- 2열 그리드: 스쿼트 / 푸쉬업 / 싯업 (실코드 기준)
- MVP에서는 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4로 비활성화 톤, tap 시 토스트 "현재는 스쿼트만 지원합니다"만 표시하고 트래킹 진입 차단. (ADR-016)
```

### 2. `docs/spec.md` — §1.3 화면 목록의 `ExercisePickerView` 라인 (현재 L32)

**기존**:
```markdown
- `ExercisePickerView` — 바텀시트 2열 그리드 (스쿼트/푸쉬업/런지/플랭크)
```

**신규**:
```markdown
- `ExercisePickerView` — 바텀시트 2열 그리드 (스쿼트/푸쉬업/싯업). 스쿼트만 active, 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4로 비활성화 톤, tap 시 토스트 "현재는 스쿼트만 지원합니다"만 표시. (ADR-016)
```

### 3. `docs/adr.md` — 파일 말미에 ADR-016 신규 항목 추가

**ADR-008, ADR-015 등 기존 ADR은 절대 수정하지 마라.** 파일 마지막 ADR(ADR-015) 아래에 아래 블록을 그대로 append.

```markdown

### ADR-016: 스쿼트 외 운동은 "준비중" UI로 공개 (ADR-008 보완)
**결정**: ExercisePicker에서 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4의 비활성화 톤으로 표시. tap 자체는 차단하지 않되, selected 전환/화면 dismiss 대신 토스트 "현재는 스쿼트만 지원합니다"만 1.5초 노출하고 트래킹 진입은 차단.
**이유**: ADR-008("UI는 있되 내부 전부 스쿼트 통일")은 3일 체험 페르소나가 푸쉬업을 한 번만 눌러봐도 기대 불일치가 드러나 즉시 삭제 트리거가 됨 (시뮬 run_id: home-workout-newbie-20s_20260424_153242). 기능 다양성 과시보다 신뢰도 우선.
**트레이드오프**: 운동별 판정 로직이 추가될 때까지 선택지 다양성 축소. 셀 tap 자체는 남겨둬 향후 재활성화 시 회귀 테스트 누락 리스크를 줄임. 토스트 카피에는 "곧 지원됩니다" 같은 미래 약속 문구 금지.
```

### 4. 건드리지 말 것

- `iterations/1-20260424_153124/requirement.md` — iteration 산출물. 본문/메타 수정 금지.
- `docs/user-intervention.md` — 이번 변경으로 새로 등록할 인간 개입 지점 없음. 무변경.
- `docs/adr.md`의 ADR-001 ~ ADR-015 — 기존 히스토리 보존.
- `Mofit/**`, `project.yml`, 기타 코드/설정 — Phase 0에서 코드 변경 절대 금지.

### 5. 문구 일관성 (Phase 1 구현과 1:1 일치)

Phase 1이 ExercisePickerView에 박을 리터럴은 아래와 같다. 본 phase에서 작성하는 ADR-016·PRD·Spec 본문의 해당 문구가 **글자까지 정확히 일치**해야 한다.

| 항목             | 리터럴 값                            |
| ---------------- | ------------------------------------ |
| 배지 텍스트      | `준비중`                             |
| 토스트 카피      | `현재는 스쿼트만 지원합니다`         |
| 비활성 셀 opacity | `0.4`                                |

## Acceptance Criteria

아래 커맨드를 모두 실행하고 지정된 결과가 나와야 한다. Bash에서 실행.

```bash
# 1) 구버전 종목명 잔존 0건
grep -RF "런지" docs/ ; test $? -eq 1
grep -RF "플랭크" docs/ ; test $? -eq 1
grep -RF "전부 내부적으로 스쿼트로 처리" docs/ ; test $? -eq 1

# 2) ADR-016 추가됨
test "$(grep -c '### ADR-016' docs/adr.md)" -ge 1

# 3) ADR-008 hunk 변경 0 (기존 5줄 원문 그대로 존재)
grep -F "### ADR-008: 운동 선택 UI는 있되 내부 처리는 스쿼트 통일" docs/adr.md
grep -F "**결정**: 4종 운동 선택 UI 제공, 내부적으로 전부 스쿼트로 처리." docs/adr.md

# 4) 새 문구가 PRD/Spec/ADR에 실제로 들어감
grep -F "스쿼트 / 푸쉬업 / 싯업" docs/prd.md
grep -F "(스쿼트/푸쉬업/싯업)" docs/spec.md
grep -F "현재는 스쿼트만 지원합니다" docs/adr.md

# 5) 관련 없는 디렉토리 변경 0 — 스테이징 전 상태로 확인
git diff --name-only | grep -vE '^docs/' ; test $? -eq 1
git diff --name-only HEAD -- Mofit/ project.yml scripts/ ; test -z "$(git diff --name-only HEAD -- Mofit/ project.yml scripts/)"
```

(테스트 target 없음. 이 phase는 docs only이므로 xcodebuild는 Phase 1에서만 수행.)

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/0-exercise-coming-soon/index.json`의 phase 0 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

## 주의사항

- **ADR-008을 절대 수정하지 마라.** ADR-008은 히스토리 레코드로 보존한다(CTO 조건부 #3). ADR-016이 보완 관계임을 결정문 제목에 "(ADR-008 보완)"로 명시하는 것만 허용.
- **requirement.md를 수정하지 마라.** iteration 디렉토리 하위는 읽기 전용이다.
- **문구는 Phase 1 구현과 1:1 일치해야 한다.** "준비중"/"현재는 스쿼트만 지원합니다"/opacity `0.4` — 본 phase에서 확정하는 값이 Phase 1 리터럴의 원본이 된다. 절대 바꾸지 마라.
- **Mofit/ 디렉토리 및 project.yml을 건드리지 마라.** 이 phase는 docs-only 변경이다.
- **새 파일을 만들지 마라.** `docs/` 내 기존 파일 3개(`prd.md`, `spec.md`, `adr.md`)만 편집한다.
- **user-intervention.md에 항목을 추가하지 마라.** 본 iteration에서 새로 발생한 인간 개입 지점이 없음(App Store 배포는 이미 문서 상 등록됨).
