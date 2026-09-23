import Foundation

/// 앱 밖 표면(홈 위젯·잠금화면 위젯·워치)이 읽는 재고 요약.
///
/// 앱이 스토어를 저장할 때마다 발행하고(`GlancePublisher`), 확장·워치는 **읽기만** 한다 — 정본은
/// 언제나 앱의 `FridgeStore`다. 그래서 여기엔 판정 로직을 두지 않고 그리는 데 필요한 값만 싣는다:
/// 이름은 발행 시점의 앱 언어로 이미 풀린 표시명, 기한은 **절대 날짜**(냉동 유예·개봉 반영된
/// `effectiveExpiresAt`)다. D-day는 읽는 쪽이 그 순간의 날짜로 다시 센다 — 위젯 타임라인이
/// 자정마다 앱 없이 넘어가도 숫자가 맞는다. 신선도 색·시듦은 앱과 같은 `Freshness(daysLeft:)`로 낸다.
struct GlanceSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: UUID
        var name: String
        var expiresAt: Date
        var estimated: Bool
        var frozen: Bool
        /// 종이컷 그림(`PaperSilhouette`) — 이 필드가 생기기 전에 저장된 요약엔 없다(nil = 일반 그림).
        var glyph: FoodGlyph?
    }

    /// 조리 중 세션(발주~완료) 요약 — 워치가 진행 상태를 그린다.
    struct Cook: Codable, Equatable {
        var recipeName: String
        var startedAt: Date
        var minutes: Int?
        var stepsDone: Int
        var stepsTotal: Int
        /// 아직 체크 안 한 첫 단계(0부터). 단계를 건너뛰며 체크해도 "지금 단계"가 이 값을 따른다.
        var nextIndex: Int?
    }

    /// 기한이 이른 순. 조리 예약된 재료는 빠진다(이미 쓰이는 중이라 할 일이 아니다).
    var items: [Item]
    var cook: Cook?
    /// 앱 언어 선택(`AppLanguage` raw: "en"/"ko"). nil = 기기 언어.
    var language: String?
    /// 발행 시점의 시간대 — 시간대가 바뀌면 요약이 달라져 재발행·위젯 재로드가 따라온다
    /// (타임라인의 자정 엔트리는 시간대에 묶여 있다).
    var timeZone: String?

    /// 표면이 한 번에 싣는 상한 — 워치 컨텍스트 전송 크기와 위젯 메모리를 같이 묶는다.
    static let itemCap = 60

    /// 폰 → 워치 WatchConnectivity 애플리케이션 컨텍스트에서 이 JSON이 실리는 키.
    static let watchContextKey = "glance"

    var locale: Locale {
        language.map(Locale.init(identifier:)) ?? .autoupdatingCurrent
    }

    // MARK: - 날짜 규칙 (앱 `Ingredient.days(from:to:)`와 같은 달력 일수 차)

    static func daysLeft(_ item: Item, asOf now: Date, calendar cal: Calendar = .current) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: item.expiresAt)).day ?? 0
    }

    /// "오늘 쓸 재료" — 오늘이 소비기한인(D-0) 재료만 센다. 이미 지난 재료는 할 일이 아니라
    /// 확인할 일이라(앱 추천도 쓰지 않는다) 여기 넣지 않는다 — 그 확인은 다음 날 아침 알림이 한 번 맡는다.
    func todayCount(asOf now: Date) -> Int {
        items.filter { Self.daysLeft($0, asOf: now) == 0 }.count
    }

    /// 먼저 쓸 재료 — 기한이 아직 안 지난 것만(오늘 포함), 기한 순. 지난 재료가 목록 앞자리를
    /// 붙박이로 차지하지 않게 한다.
    func upcoming(asOf now: Date) -> [Item] {
        items.filter { Self.daysLeft($0, asOf: now) >= 0 }
    }
}

/// 앱과 위젯 확장이 함께 쓰는 App Group 저장소. 워치는 다른 기기라 이 경로를 못 읽는다 —
/// 워치 쪽은 WatchConnectivity로 같은 JSON을 받는다.
enum GlanceStore {
    static let appGroup = "group.com.reffi.app"
    private static let fileName = "glance.json"

    private static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    static func load() -> GlanceSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GlanceSnapshot.self, from: data)
    }

    /// 실패 사유를 돌려준다(nil = 성공) — 컨테이너가 없거나(엔타이틀먼트 누락) 쓰기가 실패하면
    /// 호출부가 "보냈음"으로 기록하지 않고 다음 발행에서 다시 시도한다.
    static func save(_ snapshot: GlanceSnapshot) -> String? {
        guard let url else { return "App Group container unavailable" }
        do {
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            return nil
        } catch {
            return String(describing: error)
        }
    }
}
