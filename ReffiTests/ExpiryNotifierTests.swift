import Testing
import Foundation
@testable import Reffi

/// 아침 알림 스케줄(`ExpiryNotifier.plan`)의 날짜·묶음 계약. 알림 센터 없이 순수 판정만 본다.
/// 문구는 언어와 무관하게 비교하려고 기대값도 같은 리졸버(`AppLanguage.localizedNow`)로 만든다.
struct ExpiryNotifierTests {

    /// 기준 시각 = 오늘 06:00 — 아침 9시 알림보다 앞이라 오늘 알림도 예약 대상이다.
    private let now = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!

    private func item(_ name: String, expiresInDays offset: Int, estimated: Bool = false) -> Ingredient {
        Ingredient(name: name, category: "Other", expiresAt: Ingredient.day(offset: offset, from: now),
                   expiryIsEstimated: estimated)
    }

    private func alert(_ plan: [ExpiryNotifier.MorningAlert], day: Int) -> ExpiryNotifier.MorningAlert? {
        plan.first { $0.id == ExpiryNotifier.identifier(forDay: day) }
    }

    /// 모레(D-2) 만료 재료: 내일 아침 D-1, 모레 아침 D-0, 그다음 날 아침 D+1 확인 — 그 뒤로는 없다.
    @Test func pastDueCheckFiresTheMorningAfterExpiryOnce() {
        let milk = item("Zyx milk", expiresInDays: 2)
        let plan = ExpiryNotifier.plan(for: [milk], now: now, hour: 9)

        #expect(alert(plan, day: 1)?.title == AppLanguage.localizedNow("Expiring tomorrow"))
        #expect(alert(plan, day: 2)?.title == AppLanguage.localizedNow("Use \(1) today"))
        let check = alert(plan, day: 3)
        #expect(check?.title == AppLanguage.localizedNow("Use-by date passed"))
        #expect(check?.body.contains(milk.displayName) == true)
        #expect(check?.body.hasSuffix(AppLanguage.localizedNow("Check them, then mark Ate or Tossed.")) == true)
        #expect(alert(plan, day: 4) == nil)
        #expect(plan.count == 3)
    }

    /// 어제 기한이 끝난 재료는 오늘 아침 확인 알림에 실리고, 이틀 전에 끝난 재료는 다시 조르지 않는다.
    @Test func expiredYesterdayIsCheckedThisMorningButOlderIsNot() {
        let yesterday = item("Zyx tofu", expiresInDays: -1)
        let older = item("Zyx cream", expiresInDays: -2)
        let plan = ExpiryNotifier.plan(for: [yesterday, older], now: now, hour: 9)

        #expect(plan.count == 1)
        let check = alert(plan, day: 0)
        #expect(check?.body.contains(yesterday.displayName) == true)
        #expect(check?.body.contains(older.displayName) == false)
    }

    /// 같은 날 오늘 만료 재료가 있으면 한 장으로 묶는다: 오늘 이름 → 오늘 행동 → 지난 재료 + 그 행동.
    /// 지난 재료는 "쓸 것"이 아니라 "확인할 것"이라 오늘 권유 뒤에 자기 행동 문구와 함께 붙는다.
    @Test func pastDueFollowsTodaysActionWithItsOwnAction() throws {
        let today = item("Zyx egg", expiresInDays: 0)
        let past = item("Zyx ham", expiresInDays: -1)
        let plan = ExpiryNotifier.plan(for: [today, past], now: now, hour: 9)

        #expect(plan.count == 2)   // 오늘(D-0 + D+1 묶음), 내일(오늘 재료의 D+1 확인)
        let merged = try #require(alert(plan, day: 0))
        #expect(merged.title == AppLanguage.localizedNow("Use \(1) today"))
        let body = merged.body
        let todayRange = try #require(body.range(of: today.displayName))
        let actionRange = try #require(body.range(of: AppLanguage.localizedNow("Pick one of today's tickets.")))
        let pastRange = try #require(body.range(of: past.displayName))
        #expect(todayRange.lowerBound < actionRange.lowerBound && actionRange.lowerBound < pastRange.lowerBound)
        #expect(body.hasSuffix(AppLanguage.localizedNow("Check them, then mark Ate or Tossed.")))
    }

    /// 합쳐진 알림에서도 추정 기한(냉동·개봉 포함)은 "지났다"고 단정하지 않는다.
    @Test func mergedEstimatedPastDueAsksToCheckTheDate() throws {
        let today = item("Zyx bean", expiresInDays: 0)
        let guess = item("Zyx broth", expiresInDays: -1, estimated: true)
        let merged = try #require(alert(ExpiryNotifier.plan(for: [today, guess], now: now, hour: 9), day: 0))
        #expect(merged.body.contains(AppLanguage.localizedNow("Check the packaging date: \(guess.displayName).")))
        #expect(!merged.body.contains(AppLanguage.localizedNow("Past use-by: \(guess.displayName).")))
    }

    /// 오늘 몫은 한 번만 간다: 이미 전달됐으면 알림 시각을 바꿔도 다시 안 가고, 대기 중이었는데
    /// 새 시각이 이미 지났으면 사라지지 않고 곧바로(1분 뒤) 한 번 간다.
    @Test func todaysAlertFiresExactlyOnceAcrossHourChanges() throws {
        let late = Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date())!
        let past = Ingredient(name: "Zyx fig", category: "Other", expiresAt: Ingredient.day(offset: -1, from: late))

        // 9시에 이미 받았다 → 11시로 바꿔도 오늘 몫은 없다.
        #expect(ExpiryNotifier.plan(for: [past], now: late, hour: 11, today: .delivered).isEmpty)
        // 11시로 대기 중이었는데 8시로 당겼다 → 1분 뒤 한 번.
        let pulled = try #require(ExpiryNotifier.plan(for: [past], now: late, hour: 8, today: .pending).first)
        #expect(pulled.id == ExpiryNotifier.identifier(forDay: 0))
        #expect(pulled.fireDate.timeIntervalSince(late) > 0 && pulled.fireDate.timeIntervalSince(late) <= 90)
        #expect(Calendar.current.component(.second, from: pulled.fireDate) == 0)   // 분 단위 트리거와 같은 시각
        // 오늘 예약한 적이 없고 시각도 지났다 → 오늘 몫은 없다(다음 날로 밀리지 않는다).
        #expect(ExpiryNotifier.plan(for: [past], now: late, hour: 8, today: .none).isEmpty)
    }

    /// 기록은 날을 넘어 이어진다 — 어젯밤 재구성이 예약한 오늘 아침 알림이 간 뒤 앱을 처음 열어도
    /// 오늘 몫이 전달됨으로 읽힌다(오늘 날짜 기록이 어젯밤에 이미 남아 있다).
    @Test func todayAlertRecordSurvivesTheDayChange() throws {
        let cal = Calendar.current
        let lastNight = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        let milk = Ingredient(name: "Zyx milk", category: "Other", expiresAt: Ingredient.day(offset: 1, from: lastNight))
        let scheduled = ExpiryNotifier.plan(for: [milk], now: lastNight, hour: 9)
        let record = ExpiryNotifier.record(after: scheduled, previous: [], now: lastNight)

        let nextMorning = try #require(cal.date(byAdding: .day, value: 1, to: lastNight))
        let afterAlert = cal.date(bySettingHour: 9, minute: 5, second: 0, of: nextMorning)!
        let beforeAlert = cal.date(bySettingHour: 8, minute: 55, second: 0, of: nextMorning)!
        #expect(ExpiryNotifier.todayAlert(now: afterAlert, fireDates: record) == .delivered)
        #expect(ExpiryNotifier.todayAlert(now: beforeAlert, fireDates: record) == .pending)
        // 전달된 오늘 몫은 다음 재구성의 기록에도 남는다(그래야 그날 안에 시각을 또 바꿔도 다시 안 간다).
        #expect(ExpiryNotifier.record(after: [], previous: record, now: afterAlert).count == 1)
    }

    /// 추정 기한이 지난 재료는 "지났다"고 단정하지 않고 포장 확인을 부탁한다.
    @Test func estimatedPastDueAsksToCheckPackaging() {
        let guess = item("Zyx kimchi", expiresInDays: -1, estimated: true)
        let check = ExpiryNotifier.plan(for: [guess], now: now, hour: 9).first
        #expect(check?.title == AppLanguage.localizedNow("Check your ingredients"))
        #expect(check?.body.hasSuffix(
            AppLanguage.localizedNow("Some dates are estimates. Check the packaging and condition before using.")) == true)
    }

    /// 알림 시각이 이미 지났으면 그날 몫은 건너뛴다(다음 날로 밀리지 않는다).
    @Test func missedAlertHourSkipsTheDay() {
        let late = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let past = Ingredient(name: "Zyx leek", category: "Other",
                              expiresAt: Ingredient.day(offset: -1, from: late))
        #expect(ExpiryNotifier.plan(for: [past], now: late, hour: 9).isEmpty)
    }

    /// 발화 시각은 설정 시각 정각이다.
    @Test func firesOnTheHour() throws {
        let plan = ExpiryNotifier.plan(for: [item("Zyx pear", expiresInDays: 1)], now: now, hour: 14)
        let first = try #require(plan.first)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: first.fireDate)
        #expect(comps.hour == 14 && comps.minute == 0)
    }
}
