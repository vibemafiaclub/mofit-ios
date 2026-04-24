---
persona_id: home-workout-newbie-20s
version: 1
created_at: 2026-04-24
updated_at: 2026-04-24
company_meta:
  industry: consumer-b2c
  size: n/a
  stage: individual
keyman:
  id: km
  role: 개인 소비자 (홈트 초급자)
  decision_authority: full
  budget_range_krw: "월 0~1만원 (무료 선호, PT는 부담)"
  tech_literacy: medium
  risk_preference: conservative
  personality_notes: "앱 스토어 리뷰와 인스타 리일 추천으로 앱 선택. 3일 써보고 아니면 삭제. 개인정보/로그인 요구에 민감."
  current_pains:
    - "헬스장 3개월 등록만 해두고 2주 못 감"
    - "집에서 스쿼트 해도 폼이 맞는지 확신 안 서고, 횟수 세다가 까먹음"
    - "PT 받자니 비용(회당 7~10만원) 부담"
    - "유튜브 홈트 영상은 많은데 자세 피드백은 못 받음"
  existing_alternatives:
    - "애플 피트니스+ (비용 부담, 단방향)"
    - "유튜브 홈트 영상 (피드백 없음)"
    - "운동 기록 수첩/메모앱 (수동)"
    - "무료 홈트 앱 (자세 인식 없음)"
  buy_triggers:
    - "촬영 없이 폰 세워두는 것만으로 자동 카운팅·피드백"
    - "로그인 없이 바로 시작 가능"
    - "첫 1회 후 무료로 쭉 쓰게 될 것 같다는 확신"
  reject_triggers:
    - "첫 화면에 회원가입 벽"
    - "'카메라 권한 없으면 아무것도 못함' 으로 시작"
    - "실제로 써보니 rep 카운트가 자주 틀림 → 신뢰도 붕괴"
    - "광고 팝업 과다"
  communication_style: "리뷰·앱스토어 별점으로 의사결정. 친구 추천 없이도 혼자 시도."
trust_with_salesman: 40
stakeholders: []
competing_solutions:
  - name: "Apple Fitness+"
    usage: aware
    strengths: ["영상 퀄리티", "Apple 생태계 통합"]
    weaknesses: ["자세 피드백 없음", "월 구독료"]
    switching_cost: low
  - name: "YouTube 홈트 영상"
    usage: using
    strengths: ["무료", "다양성"]
    weaknesses: ["피드백 0", "몰입 끊김"]
    switching_cost: low
  - name: "헬스장 + PT"
    usage: aware
    strengths: ["실제 피드백", "강제성"]
    weaknesses: ["비용", "시간·이동 부담"]
    switching_cost: high
  - name: "무료 홈트 카운터 앱 (기존 스토어 앱)"
    usage: aware
    strengths: ["무료"]
    weaknesses: ["수동 카운팅", "자세 인식 없음"]
    switching_cost: low
---

# 배경 서술

20대 후반 직장인/학생. 체중 감량 또는 체형 개선이 목표지만 운동 자체가 습관이 안 된 단계. 운동을 "해본 적"은 있으나 꾸준히 간 적 없음. 헬스장 등록 → 1~2주 후 중단 패턴 반복.

집에 요가매트는 있지만 덤벨 같은 기구는 없음. 맨몸 운동 위주. "오늘 스쿼트 몇 개 했는지" 기억에만 의존.

## 구매 맥락

- 앱 스토어에서 "홈트", "스쿼트 카운터", "AI 코칭" 같은 키워드로 검색.
- 설치 후 **첫 30초 안에 무언가 되어야 함**. 온보딩에 성별/키/몸무게 정도까지는 수용하나, 회원가입 벽은 이탈 트리거.
- "AI" 키워드에 호기심은 있지만, 실제로 써봤을 때 generic한 조언만 뱉으면 바로 실망.

## 조직 역학 메모

개인 소비자라 stakeholder 없음. 구매·사용 결정이 전적으로 본인. 단, **SNS/지인 추천**이 앱 인지에 영향 크고, 한 번이라도 좋은 경험이면 친구에게 공유할 잠재력 있음 (리퍼럴 경로).

## 시뮬 시 비판 포인트

- Mofit이 "폰 세워두면 자동 카운트" 라고 주장할 때, **실제 카운트 정확도**를 의심한다. 한 번이라도 misdetect 하면 즉시 신뢰 붕괴.
- "AI 코칭" 이 일반론 수준이면 "그거면 ChatGPT 쓰지" 로 결론.
- 로그인 흐름(이메일 + 비밀번호) 이 앞에 놓이면 바로 삭제.
- 스쿼트만 제대로 되고 나머지 운동(푸쉬업/런지/플랭크) UI만 있고 내부는 스쿼트 통일이라는 점을 알게 되면 실망 가능성 있음.
