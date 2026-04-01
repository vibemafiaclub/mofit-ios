다음 과정에 따라 작업 논의 및 구현을 진행하자:

1. 먼저 `/docs/` 하위 경로의 문서들을 적절히 읽어 이 프로젝트의 기획, 디자인, 아키텍쳐, 설계의도를 파악한다. 필요시 여러 Explore 에이전트를 병렬로 사용한다.
2. 이번 작업을 구현하기위해 더 구체화해야할 점, 기술적으로 논의해야할 점이 있다면 사용자에게 제시한 후 논의를 이어간다.
3. 사용자가 충분히 논의했다고 판단 후 구현계획 작성을 지시하면, 가장 먼저 `/prompts/task-create.md` 파일의 내용을 정확히 숙지한다. 이후 해당 방식으로 생성하기위한 구현 계획을 여러 phase로 나뉜 초안으로 작성하고, 논의점까지 포함하여 사용자에게 피드백을 요청한다.
4. 사용자가 충분히 논의했다고 판단 후 task 생성을 지시하면, `/prompts/task-create.md`의 형식과 절차에 맞게 task와 phase 파일들을 생성한다.
5. `scripts/run-phases.py`를 실행해서 각 phase를 순차적으로 실행한다.
6. `scripts/run-phases.py` 종료 후, 종료 코드에 따라 Discord로 사용자에게 알림을 보낸다:
   - **exit 0 (성공)**: 모든 phase 완료. `✅ Task {name} 완료 (N phases)` 메시지 전송.
   - **exit 1 (오류)**: phase 실행 중 오류 발생. task의 index.json에서 error_message를 읽어 `❌ Task {name} phase {n} 실패: {error}` 메시지 전송.
   - **exit 2 (blocked)**: 사용자 개입 필요. task의 index.json에서 blocked_reason을 읽어 `⚠️ Task {name} phase {n} blocked: {reason}` 메시지 전송.
