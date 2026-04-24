import Foundation

struct CoachingSample: Identifiable {
    let id = UUID()
    let type: String   // "pre" | "post"
    let content: String
}

enum CoachingSamples {
    static let all: [CoachingSample] = [
        CoachingSample(
            type: "pre",
            content: "지난 주 3일 운동 · 총 78회 스쿼트 · 일평균 26회. 수요일엔 38회 최다였고 금요일 0회였네요. 오늘은 수요일 페이스 회복해서 30회 이상 도전해보세요."
        ),
        CoachingSample(
            type: "post",
            content: "오늘 3세트 총 32회. 1세트 14회 → 2세트 10회 → 3세트 8회. 세트별 감소폭 4회로 피로도 자연스러운 곡선. 내일은 2세트째에서 쉬는 시간 20초 늘려보세요."
        )
    ]
}
