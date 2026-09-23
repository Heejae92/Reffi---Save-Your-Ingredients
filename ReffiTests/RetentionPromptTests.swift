import Testing
import Foundation
import UserNotifications
@testable import Reffi

/// 리텐션 프롬프트(§14.9)의 판정 계약 — 언제 묻고 언제 안 묻는가. 다이얼로그 렌더와 시스템 권한
/// 요청은 UI 테스트(`RetentionPromptUITests`)가 본다.
@MainActor
struct RetentionPromptTests {

    /// 한국 달력 고정 — 자정 경계 판정이 테스트 호스트의 시간대에 흔들리지 않게.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    // MARK: 알림 제안

    /// 시스템 권한을 아직 묻지 않았고 앱 스위치도 꺼져 있을 때만 — 거부·허용이 정해졌으면 할 일이 없다.
    @Test func alertAskOnlyWhileUndeterminedAndOff() {
        #expect(RetentionPrompt.canAskAlerts(authorization: .notDetermined, alertsEnabled: false))
        #expect(!RetentionPrompt.canAskAlerts(authorization: .notDetermined, alertsEnabled: true))
        #expect(!RetentionPrompt.canAskAlerts(authorization: .denied, alertsEnabled: false))
        #expect(!RetentionPrompt.canAskAlerts(authorization: .authorized, alertsEnabled: false))
        #expect(!RetentionPrompt.canAskAlerts(authorization: .provisional, alertsEnabled: false))
    }

    /// 첫 등록 = 재고와 이력이 둘 다 빈 상태에서의 입고. 그 뒤의 입고는 첫 등록이 아니다.
    @Test func firstRegistrationIsSignalledOnceFromAnEmptyStore() {
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.firstRegisteredAt == nil)
        #expect(store.add(Ingredient(name: "Zyx milk", category: "Dairy", expiresAt: .now)))
        let first = store.firstRegisteredAt
        #expect(first != nil)
        #expect(store.add(Ingredient(name: "Zyx egg", category: "Dairy", expiresAt: .now)))
        #expect(store.firstRegisteredAt == first)   // 두 번째 입고가 신호를 새로 내지 않는다
    }

    /// 이력이 있는 사람(이 기능 이전부터 쓰던 사람)의 입고는 재고가 비어 있어도 첫 등록이 아니다.
    @Test func registrationAfterHistoryIsNotFirst() {
        let history = [RemovalLog(name: "Zyx milk", glyph: .milk, daysAgo: 3, wasted: false)]
        let store = FridgeStore(ingredients: [], recipes: [], history: history)
        #expect(store.add(Ingredient(name: "Zyx egg", category: "Dairy", expiresAt: .now)))
        #expect(store.firstRegisteredAt == nil)
    }

    /// 저장되지 않은 입고(수량 0)는 신호를 내지 않는다 — 실패한 저장 뒤에 알림을 묻지 않는다.
    @Test func rejectedRegistrationIsNotSignalled() {
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        let empty = Ingredient(name: "Zyx milk", category: "Dairy", expiresAt: .now,
                               quantity: Quantity(value: 0, unit: .piece))
        #expect(!store.add(empty))
        #expect(store.firstRegisteredAt == nil)
    }

    /// 샘플 불러오기는 입고가 아니다.
    @Test func sampleDataIsNotARegistration() {
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        store.loadSampleData()
        #expect(store.firstRegisteredAt == nil)
    }

    // MARK: 알림 미리보기 — 스케줄러가 실제로 짤 첫 알림

    /// 사흘 뒤 만료: 첫 알림은 이틀 뒤 아침의 "내일 만료"다 — 스케줄러의 첫 알림과 날짜·문구가 같다.
    @Test func previewIsTheSchedulersFirstAlert() throws {
        let now = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!
        let milk = Ingredient(name: "Zyx milk", category: "Dairy", expiresAt: Ingredient.day(offset: 3, from: now))
        let preview = try #require(AlertPreview.make(for: [milk], now: now, hour: 9))
        let first = try #require(ExpiryNotifier.plan(for: [milk], now: now, hour: 9).first)
        #expect(preview.fireDate == first.fireDate)
        #expect(preview.title == first.title)
        #expect(preview.body == first.body)
        #expect(preview.title == AppLanguage.localizedNow("Expiring tomorrow"))
    }

    /// 30일 창 밖(기한이 먼 재료뿐)이면 기한 전날 아침 — 창에 들어오는 날 스케줄러가 짤 알림과 같은 문구.
    @Test func farItemsPreviewTheMorningBeforeTheirDate() throws {
        let now = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!
        let rice = Ingredient(name: "Zyx rice", category: "Grain", expiresAt: Ingredient.day(offset: 60, from: now))
        let preview = try #require(AlertPreview.make(for: [rice], now: now, hour: 8))
        let expected = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0,
                                             of: Ingredient.day(offset: 59, from: now))
        #expect(preview.fireDate == expected)
        #expect(preview.title == ExpiryNotifier.message(today: [], tomorrow: [rice], pastDue: []).title)
    }

    /// 보여 줄 알림이 없으면 그림 없이 문구만 선다.
    @Test func noPreviewWithoutAnUpcomingAlert() {
        let now = Date()
        #expect(AlertPreview.make(for: [], now: now, hour: 9) == nil)
        let old = Ingredient(name: "Zyx tofu", category: "Other", expiresAt: Ingredient.day(offset: -5, from: now))
        #expect(AlertPreview.make(for: [old], now: now, hour: 9) == nil)
    }

    // MARK: 위젯 제안

    /// 사용 일수는 시각 차이가 아니라 달력 날짜로 센다 — 밤 11시 반 설치면 다음 날 0시 10분이 1일째.
    @Test func dayOfUseCountsCalendarDays() {
        let installed = date(20, 23, 30)
        #expect(RetentionPrompt.dayOfUse(firstUse: installed, now: date(20, 23, 59), calendar: calendar) == 0)
        #expect(RetentionPrompt.dayOfUse(firstUse: installed, now: date(21, 0, 10), calendar: calendar) == 1)
        #expect(RetentionPrompt.dayOfUse(firstUse: installed, now: date(22, 0, 0), calendar: calendar) == 2)
    }

    /// 2일째부터, 보여 줄 재료가 있고, 위젯이 아직 없을 때만.
    @Test func widgetOfferNeedsDayTwoStockAndNoWidget() {
        let installed = date(20, 10)
        func offer(on day: Int, upcoming: Bool = true, installedWidget: Bool = false) -> Bool {
            RetentionPrompt.canOfferWidget(firstUse: installed, now: date(day, 9), hasUpcoming: upcoming,
                                           widgetInstalled: installedWidget, calendar: calendar)
        }
        #expect(!offer(on: 20))
        #expect(!offer(on: 21))
        #expect(offer(on: 22))
        #expect(offer(on: 29))
        #expect(!offer(on: 22, upcoming: false))
        #expect(!offer(on: 22, installedWidget: true))
    }

    /// 첫 사용일 — 기록이 없을 때 정한다. 이력이 있으면(기능 이전부터 쓰던 사람) 가장 이른 이력의 날.
    @Test func firstUseFallsBackToEarliestHistory() {
        let now = Date()
        #expect(RetentionPrompt.firstUse(now: now, history: []) == now)
        let history = [RemovalLog(name: "Zyx a", glyph: .milk, daysAgo: 2, wasted: false),
                       RemovalLog(name: "Zyx b", glyph: .milk, daysAgo: 9, wasted: true)]
        #expect(RetentionPrompt.firstUse(now: now, history: history) == Ingredient.day(offset: -9))
    }
}
