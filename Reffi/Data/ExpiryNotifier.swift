import Foundation
import UserNotifications

/// 소비기한 로컬 알림 — 매일 아침(설정 시각) 그날 만료(D-0)·내일 만료(D-1) 재료와, **어제 기한이
/// 지난(D+1) 재료의 확인 요청**을 한 장에 묶어 알린다. 지난 재료는 다음 날 아침 **한 번만** 싣는다
/// (이틀째부터는 조르지 않는다). 하루 한 장 원칙이라 대기 알림은 여전히 최대 31개(iOS 한도 64 내).
/// 스토어가 바뀔 때마다 앞으로 30일 치를 다시 짠다 — 오래 안 열어도 한 달은 알림이 살아 있고,
/// 그 사이 먹음/버림으로 정리한 재료는 다음 재구성에서 빠진다. 냉동 재료는 유예 시계(`effectiveExpiresAt`) 기준.
/// 설정은 MyPage의 토글/시각.
enum ExpiryNotifier {
    static let enabledKey = "expiryAlertsEnabled"
    static let hourKey = "expiryAlertHour"
    static let defaultHour = 9
    /// 사전 등록 창 — 미실행 상태에서도 이만큼은 알림이 이어진다.
    static let windowDays = 30

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var alertHour: Int {
        UserDefaults.standard.object(forKey: hourKey) as? Int ?? defaultHour
    }

    /// 권한 요청 — MyPage에서 토글을 켤 때 호출.
    static func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        await MainActor.run { Analytics.shared.track(.notificationPermission(granted: granted)) }
        return granted
    }

    /// 하루 한 장의 아침 알림 — 스케줄 판정(`plan`)의 산출물. 알림 센터에 넘기기 전의 순수 값이라
    /// 테스트가 UNUserNotificationCenter 없이 날짜·문구를 고정할 수 있다.
    struct MorningAlert: Equatable {
        let id: String
        let fireDate: Date
        let title: String
        let body: String
    }

    static func identifier(forDay offset: Int) -> String { "expiry-day-\(offset)" }

    /// 오늘 아침 알림이 어디까지 왔나 — 재구성 때마다 오늘 몫을 새로 계산하면, 알림 시각을 바꾼 날
    /// 이미 받은 알림이 새 시각에 한 번 더 가거나(9시 받고 10시로 바꿈), 아직 안 간 알림이 사라진다
    /// (9시 대기 중에 8시 반에 8시로 바꿈). D+1 확인은 한 번뿐이라 사라지면 되찾을 길이 없다.
    enum TodayAlert: Equatable { case none, pending, delivered }

    /// 예약해 둔 아침 알림들의 발화 시각. **모든 날짜**를 남긴다 — 내일 알림은 오늘 밤에 예약되므로,
    /// 오늘 몫만 적어 두면 아침에 알림이 간 뒤 앱을 처음 여는 순간 그 기록이 없다(어제 날짜뿐이다).
    private static let fireDatesKey = "expiryAlertFireDates"

    /// 오늘 몫의 상태 — 기록 중 오늘 날짜의 발화 시각이 이미 지났으면 전달됨, 아직이면 대기 중.
    static func todayAlert(now: Date, fireDates: [Date], calendar cal: Calendar = .current) -> TodayAlert {
        guard let today = fireDates.first(where: { cal.isDate($0, inSameDayAs: now) }) else { return .none }
        return today <= now ? .delivered : .pending
    }

    /// 재구성 뒤 남길 기록 — 새로 예약한 알림들 + (이미 전달된 오늘 몫이면) 그 시각. 지난 날은 버린다.
    static func record(after alerts: [MorningAlert], previous: [Date], now: Date,
                       calendar cal: Calendar = .current) -> [Date] {
        let delivered = previous.filter { cal.isDate($0, inSameDayAs: now) && $0 <= now }
        return delivered + alerts.map(\.fireDate)
    }

    /// 앞으로 `windowDays`일 치 아침 알림을 재구성. 꺼져 있으면 전부 걷어낸다.
    static func reschedule(for ingredients: [Ingredient]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0...windowDays).map { identifier(forDay: $0) })
        let now = Date()
        let previous = UserDefaults.standard.array(forKey: fireDatesKey) as? [Date] ?? []
        let today = todayAlert(now: now, fireDates: previous)
        let alerts = isEnabled ? plan(for: ingredients, now: now, hour: alertHour, today: today) : []
        UserDefaults.standard.set(record(after: alerts, previous: previous, now: now), forKey: fireDatesKey)

        let cal = Calendar.current
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: alert.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger))
        }
    }

    /// 순수 스케줄 판정 — 재료를 만료 오프셋으로 한 번 버킷팅(O(N))한 뒤, 알림 날 `d`마다
    /// 오늘 만료(`d`)·내일 만료(`d+1`)·어제 만료(`d-1`) 세 묶음을 읽는다. 어제 만료 묶음이 있어서
    /// 버킷 범위가 -1부터다(오늘 아침 알림이 어제 기한이 끝난 재료를 싣는다).
    /// 알림 시각이 이미 지난 날은 건너뛴다 — 그날의 D+1 확인은 다음 날로 밀리지 않는다(한 번만).
    /// 오늘 몫은 `today`가 정한다: 이미 전달됐으면 다시 보내지 않고, 대기 중이었는데 새 시각이 이미
    /// 지났으면 1분 뒤로 당겨 한 번 보낸다(사라지지 않게).
    static func plan(for ingredients: [Ingredient], now: Date, hour: Int,
                     today todayState: TodayAlert = .none) -> [MorningAlert] {
        guard !ingredients.isEmpty else { return [] }
        let cal = Calendar.current
        // 냉동은 유예 시계 기준 — 냉동해 둔 재료가 원래 기한으로 오늘 알림에 섞이지 않는다.
        var buckets: [Int: [Ingredient]] = [:]
        for ing in ingredients {
            let offset = Ingredient.days(from: now, to: ing.effectiveExpiresAt)
            if (-1...(windowDays + 1)).contains(offset) { buckets[offset, default: []].append(ing) }
        }
        return (0...windowDays).compactMap { offset in
            let today = buckets[offset] ?? []
            let tomorrow = buckets[offset + 1] ?? []
            let pastDue = buckets[offset - 1] ?? []
            guard !(today.isEmpty && tomorrow.isEmpty && pastDue.isEmpty),
                  !(offset == 0 && todayState == .delivered),
                  var fireDate = cal.date(bySettingHour: hour, minute: 0, second: 0,
                                          of: Ingredient.day(offset: offset, from: now)) else { return nil }
            if fireDate <= now {
                guard offset == 0, todayState == .pending,
                      // 분 단위 트리거라 정각으로 맞춘다 — 초가 남으면 기록(초 포함)보다 먼저 울려,
                      // 그 사이 재구성이 아직 대기 중으로 보고 한 번 더 예약한다.
                      let soon = cal.nextDate(after: now.addingTimeInterval(30), matching: DateComponents(second: 0),
                                              matchingPolicy: .nextTime) else { return nil }
                fireDate = soon
            }
            let message = message(today: today, tomorrow: tomorrow, pastDue: pastDue)
            return MorningAlert(id: identifier(forDay: offset), fireDate: fireDate,
                                title: message.title, body: message.body)
        }
    }

    /// 한 장의 제목·본문. 본문은 **데이터 문장들 → 행동 문장** 순서로 조립한다.
    ///
    /// **같은 종류의 정보는 붙여 세운다(43차, 오너 결정)** — 옛 순서(오늘 이름들 → 행동
    /// 문구 → 내일 이름들)는 데이터 두 묶음 사이에 권유가 끼어 눈이 튀고, 잠금화면에서
    /// 본문이 잘릴 때 정보성이 가장 높은 '내일' 목록이 가장 먼저 사라졌다. 이름 묶음을
    /// 먼저 붙이고 권유는 꼬리로 — 잘려도 없어지는 건 권유 문장이다. 행동 문구는 화면
    /// 이름("오늘의 티켓")으로 목적지를 부른다 — "Reffi를 열고"는 알림 탭이 이미 하는
    /// 일이고, "fire a ticket"은 UI 어디에도 없는 내부 동사였다.
    ///
    /// 어제 기한이 지난 재료(D+1 확인)는 오늘·내일 할 일과 **다른 종류의 정보**다(쓸 것이 아니라
    /// 확인할 것). 그래서 오늘·내일 권유 뒤에 **자기 행동 문구와 함께** 붙는다 — 권유 앞에 끼우면
    /// "상하기 전에 뭘 해 먹을지"가 지난 재료까지 가리키는 것처럼 읽혔다. 그것만 있는 날엔 확인 알림
    /// 자체가 된다. 행동 문구는 실제 버튼 이름(먹음·버림)을 부른다. 추정 기한(냉동·개봉 포함)이
    /// 섞이면 "지났다"고 단정하지 않고 포장의 날짜를 확인해 달라고 한다.
    /// 문구는 전부 선택 언어 번들로 즉시 조회한다(`localizedNow`) — 한 장 안에서 언어가 섞이지 않게.
    static func message(today: [Ingredient], tomorrow: [Ingredient],
                        pastDue: [Ingredient]) -> (title: String, body: String) {
        func names(_ items: [Ingredient], _ limit: Int) -> String {
            items.prefix(limit).map(\.displayName).joined(separator: ", ")
        }
        let upcoming = today + tomorrow
        var sentences: [String] = []
        let title: String
        let action: String
        if upcoming.isEmpty {
            // D+1 확인만 있는 날. 추정 기한이 섞였으면 "지났다"고 단정하지 않고 포장 확인을 부탁한다.
            let estimated = pastDue.contains { $0.effectiveExpiryIsEstimated }
            title = estimated ? AppLanguage.localizedNow("Check your ingredients")
                              : AppLanguage.localizedNow("Use-by date passed")
            sentences.append(names(pastDue, 4) + ".")   // 이름 나열 + 마침표 — 번역할 문장 성분이 없다
            action = estimated
                ? AppLanguage.localizedNow("Some dates are estimates. Check the packaging and condition before using.")
                : AppLanguage.localizedNow("Check them, then mark Ate or Tossed.")
        } else if upcoming.contains(where: { $0.effectiveExpiryIsEstimated }) {
            title = AppLanguage.localizedNow("Check your ingredients")
            sentences.append(names(upcoming, 4) + ".")
            action = AppLanguage.localizedNow("Some dates are estimates. Check the packaging and condition before using.")
        } else if today.isEmpty {
            title = AppLanguage.localizedNow("Expiring tomorrow")
            sentences.append(names(tomorrow, 4) + ".")
            action = AppLanguage.localizedNow("Plan a dish before they turn.")
        } else {
            // 제목 카운트와 첫 나열을 '오늘 만료'로 일치시키고, 내일 건은 별도 문장으로.
            title = AppLanguage.localizedNow("Use \(today.count) today")
            sentences.append(names(today, 4) + ".")
            if !tomorrow.isEmpty {
                sentences.append(AppLanguage.localizedNow("Tomorrow: \(names(tomorrow, 3))."))
            }
            action = AppLanguage.localizedNow("Pick one of today's tickets.")
        }
        sentences.append(action)
        if !upcoming.isEmpty && !pastDue.isEmpty {
            if pastDue.contains(where: { $0.effectiveExpiryIsEstimated }) {
                sentences.append(AppLanguage.localizedNow("Check the packaging date: \(names(pastDue, 3))."))
            } else {
                sentences.append(AppLanguage.localizedNow("Past use-by: \(names(pastDue, 3))."))
                sentences.append(AppLanguage.localizedNow("Check them, then mark Ate or Tossed."))
            }
        }
        return (title, sentences.joined(separator: " "))
    }
}

/// 알림 표시 델리게이트 — 앱이 포그라운드일 때도 배너로 보여준다
/// (아침 알림 시각에 마침 앱을 열어둔 사용자가 놓치지 않게).
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// 알림 탭(64차) — 배너를 눌러 들어온 세션을 표시한다(`notification_open`, 알림 기여 세션 비율의 소스).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        await MainActor.run { Analytics.shared.track(.notificationOpen) }
    }
}
