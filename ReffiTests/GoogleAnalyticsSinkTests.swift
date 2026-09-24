import Testing
import Foundation
@testable import Reffi

/// 파이프라인 행 → GA4 이벤트 변환(`GoogleAnalyticsSink.event(for:)`)을 고정한다. Firebase 자체는 건드리지
/// 않는다 — 설정 파일이 없는 테스트 호스트에서 SDK는 꺼져 있고, 변환은 순수 함수다.
struct GoogleAnalyticsSinkTests {

    private func row(_ name: String, _ props: [String: AnalyticsValue] = [:]) -> Analytics.Row {
        Analytics.Row(install_id: "i", session_id: "s", seq: 1, name: name, props: props,
                      occurred_at: "2026-09-19T00:00:00.000Z", app_version: "1.0", build: "31",
                      os_version: "26.5.0", device_model: "iPhone17,3", locale: "ko_KR", language: "ko",
                      channel: "release")
    }

    @Test func sessionStartIsLeftToFirebase() {
        #expect(GoogleAnalyticsSink.event(for: row("session_start", ["cold": .bool(true)])) == nil)
    }

    @Test func screenViewUsesTheReservedEventWithScreenName() throws {
        let event = try #require(GoogleAnalyticsSink.event(for: row("screen_view", ["screen": .string("fridge.stock")])))
        #expect(event.name == "screen_view")
        #expect(event.parameters["screen_name"] as? String == "fridge.stock")
        #expect(event.parameters["screen_class"] as? String == "fridge.stock")   // 자동 화면 추적이 꺼져 있어 클래스 축도 우리가 준다
        #expect(event.parameters.count == 2)
    }

    @Test func screenViewWithoutScreenIsDropped() {
        #expect(GoogleAnalyticsSink.event(for: row("screen_view")) == nil)
    }

    @Test func reservedNamesGetThePrefix() throws {
        let event = try #require(GoogleAnalyticsSink.event(for: row("notification_open")))
        #expect(event.name == "reffi_notification_open")
        #expect(GoogleAnalyticsSink.reservedEventNames.contains("first_open"))
    }

    @Test func ordinaryEventsKeepNameAndConvertBools() throws {
        let event = try #require(GoogleAnalyticsSink.event(for: row("ingredient_decide", [
            "outcome": .string("ate"), "days_left": .int(2), "frozen": .bool(false), "glyph": .string("tomato"),
        ])))
        #expect(event.name == "ingredient_decide")
        #expect(event.parameters["outcome"] as? String == "ate")
        #expect(event.parameters["days_left"] as? Int == 2)
        #expect(event.parameters["frozen"] as? Int == 0)
        #expect(event.parameters["glyph"] as? String == "tomato")
    }

    @Test func valuesAreClampedToGoogleAnalyticsLimits() throws {
        let long = String(repeating: "x", count: 150)
        let event = try #require(GoogleAnalyticsSink.event(for: row("undo", ["kind": .string(long)])))
        #expect((event.parameters["kind"] as? String)?.count == 100)
    }

    /// 프로젝트 정의가 광고 식별자 없는 제품·SDK 기본 꺼짐·광고 개인 최적화 끔을 유지하는지 — 한 단어만 바꿔도
    /// (`FirebaseAnalyticsCore` → `FirebaseAnalytics`) IDFA·광고 SDK가 딸려 들어와 매니페스트·방침이 거짓이 된다.
    @Test func projectDefinitionKeepsTheAdFreeAnalyticsProduct() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let yml = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        #expect(yml.contains("product: FirebaseAnalyticsCore"))
        #expect(!yml.contains("product: FirebaseAnalytics\n"))
        #expect(!yml.contains("FirebaseAnalyticsIdentitySupport"))
        #expect(yml.contains("FIREBASE_ANALYTICS_COLLECTION_ENABLED: false"))
        #expect(yml.contains("GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS: false"))
        #expect(yml.contains("exactVersion: 12.19.2"))
    }

    /// 사전의 모든 이벤트 이름은 GA 규칙(≤40자, 영문 소문자·숫자·밑줄, 예약 접두사 없음)을 지킨다.
    @Test func dictionaryNamesSatisfyGoogleAnalyticsRules() {
        let names = [
            "session_start", "app_background", "screen_view", "onboarding_complete", "notification_open",
            "notification_permission", "alerts_toggled", "language_change", "receipt_scan", "ingredient_add",
            "ingredient_edit", "ingredient_delete", "ingredient_freeze", "ingredient_pin", "ingredient_decide",
            "sealed_check", "deck_open", "ticket_pass", "ticket_fire", "cook_finish", "cook_cancel", "video_open",
            "undo", "tobuy_add", "tobuy_remove", "recipe_custom", "sample_load", "data_reset",
            "auth_signin", "auth_upgrade", "auth_signout",
        ]
        for name in names {
            let mapped = GoogleAnalyticsSink.event(for: row(name, ["screen": .string("home")]))?.name ?? name
            #expect(mapped.count <= 40, "\(name)")
            #expect(mapped.range(of: "^[a-z][a-z0-9_]*$", options: .regularExpression) != nil, "\(name)")
            for prefix in ["firebase_", "google_", "ga_"] { #expect(!mapped.hasPrefix(prefix), "\(name)") }
        }
    }
}
