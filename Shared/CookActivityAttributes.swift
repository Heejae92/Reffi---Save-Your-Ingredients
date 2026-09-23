#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// 조리 세션 라이브 액티비티(잠금화면·다이내믹 아일랜드). 발주로 시작해 완료·취소로 끝난다.
/// 고정 값(레시피·시작 시각)은 속성에, 단계 체크·언어처럼 바뀔 수 있는 값은 `ContentState`에 둔다
/// (속성은 요청 뒤 못 바꾼다 — 언어를 속성에 두면 앱에서 언어를 바꿔도 끝날 때까지 옛 언어였다).
struct CookActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stepsDone: Int
        var stepsTotal: Int
        /// 아직 체크 안 한 첫 단계(0부터). "Step N of M"의 N과 아래 본문이 **같은 단계**를 가리키게
        /// 이 인덱스 하나에서 둘 다 낸다(단계는 순서 없이 체크할 수 있다).
        var nextIndex: Int?
        /// 그 단계의 본문 — 세션 스냅샷 원문 그대로(레시피 데이터에서 온 값).
        var nextStep: String?
        /// 앱 언어 선택(`AppLanguage` raw). nil = 기기 언어.
        var language: String?
    }

    var recipeName: String
    var startedAt: Date
    /// 레시피 조리 시간(분). nil이면 경과 시간만 보여 준다.
    var minutes: Int?

    /// 시스템이 라이브 액티비티를 끝내는 시간(8시간). 새로 띄우는 창·경과 타이머 상한·stale 시각이
    /// 모두 이 값 하나를 본다.
    static let maxDuration: TimeInterval = 8 * 60 * 60

    /// 경과 타이머가 멈추는 시각 — 시스템이 끝낸 뒤에도 잠금화면에 남는 몇 시간 동안 시계가
    /// 계속 흐르지 않게 한다.
    var endOfLife: Date { startedAt.addingTimeInterval(Self.maxDuration) }

    /// 예상 완료 시각 — 조리 시간이 있을 때만.
    var expectedEnd: Date? {
        minutes.map { startedAt.addingTimeInterval(TimeInterval(max($0, 1) * 60)) }
    }
}
#endif
