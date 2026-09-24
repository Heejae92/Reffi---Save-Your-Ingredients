import Foundation
import os
import FirebaseCore
import FirebaseAnalytics

/// Google Analytics(Firebase) 출구 — 파이프라인(`Analytics`)이 만든 행을 GA4 이벤트로 바꿔 넘긴다.
///
/// 앱에서 Firebase를 아는 곳은 이 파일 하나다. 이벤트 사전·세션·옵트아웃은 그대로 `Analytics`가 쥐고,
/// 여기서는 (1) 앱 실행 시 설정 파일이 있을 때만 Firebase를 켜고 (2) 수집 동의 상태를 Firebase에 전달하고
/// (3) 행 하나를 GA 이벤트 하나로 옮긴다. `FirebaseAnalyticsCore` 제품만 링크하므로 광고 식별자(IDFA)는
/// 수집하지 않고 ATT 권한 요청도 없다.
///
/// `GoogleService-Info.plist`는 저장소에 없다(.gitignore). 파일이 번들에 없으면 조용히 꺼진 채로 앱이 돈다 —
/// 개발 머신·CI·유닛 테스트 호스트가 설정 파일 없이도 빌드·실행되게 하려는 의도다.
@MainActor
enum GoogleAnalyticsSink {

    nonisolated static let log = Logger(subsystem: "com.reffi.app", category: "analytics.ga")

    private(set) static var isConfigured = false

    /// 앱 실행 직후 한 번. 설정 파일이 없으면 아무것도 하지 않는다(`FirebaseApp.configure()`는 파일이 없으면
    /// 앱을 죽인다). `collectionEnabled`는 사용자의 "Share usage data" 상태 — Firebase 자체 플래그와 항상
    /// 같은 값을 갖게 해서, 파이프라인이 큐를 비우는 동안 SDK가 자동 이벤트(first_open 등)를 따로 보내지 않게 한다.
    static func configureIfAvailable(collectionEnabled: Bool) {
        guard !isConfigured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            log.notice("GoogleService-Info.plist not bundled; Google Analytics stays off")
            return
        }
        FirebaseApp.configure()
        applyConsent(collectionEnabled: collectionEnabled)
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(collectionEnabled)
        isConfigured = true
    }

    /// 동의 플래그를 **코드로 고정**한다 — 광고 저장·광고 사용자 데이터·광고 개인 최적화는 항상 거부.
    /// `NSPrivacyTracking = false`와 방침의 "맞춤형 광고에 제공하지 않음"이 콘솔 설정(바뀔 수 있음)이 아니라
    /// 바이너리에 걸리게 하는 장치다. Info.plist의 `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS`가
    /// 같은 값을 SDK 시작 시점부터 보장한다.
    private static func applyConsent(collectionEnabled: Bool) {
        FirebaseAnalytics.Analytics.setConsent([
            .analyticsStorage: collectionEnabled ? .granted : .denied,
            .adStorage: .denied,
            .adUserData: .denied,
            .adPersonalization: .denied,
        ])
    }

    /// 프로필 토글 → Firebase. 끄면 앱 인스턴스 식별자까지 재발급해(`resetAnalyticsData`) 다시 켜도 이전
    /// 기록과 이어지지 않는다 — 방침의 "끄면 식별자도 초기화" 문장이 여기에 걸려 있다.
    static func setCollectionEnabled(_ on: Bool) {
        guard isConfigured else { return }
        applyConsent(collectionEnabled: on)
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(on)
        if !on { FirebaseAnalytics.Analytics.resetAnalyticsData() }
    }

    /// "Erase this device"·계정 삭제 — 파이프라인의 install id뿐 아니라, 실제로 Google에 나가는 유일한 식별자인
    /// 앱 인스턴스 ID도 새로 발급한다. 그래야 삭제 확인 문구("공유한 사용 기록")가 사실이 된다.
    static func resetIdentifier() {
        guard isConfigured else { return }
        FirebaseAnalytics.Analytics.resetAnalyticsData()
    }

    /// 사용자가 GA 기록 삭제를 요청할 때 필요한 식별자(GA4 User Deletion API 키). 방침 화면이 읽기 전용으로
    /// 보여 준다 — 이 값이 없으면 운영자도 요청을 처리할 수 없다.
    static func appInstanceID() -> String? {
        guard isConfigured else { return nil }
        return FirebaseAnalytics.Analytics.appInstanceID()
    }

    /// 앱 언어·채널을 사용자 속성으로 — 행마다 싣는 대신 GA 보고서의 세그먼트 축으로 쓴다.
    static func setUserProperties(from context: Analytics.Context) {
        guard isConfigured else { return }
        FirebaseAnalytics.Analytics.setUserProperty(context.language, forName: "app_language")
        FirebaseAnalytics.Analytics.setUserProperty(context.channel, forName: "channel")
    }

    /// 파이프라인 업로더 — Firebase가 자체 디스크 큐·배치 전송을 가지므로 여기서는 넘기기만 한다.
    static func upload(_ rows: [Analytics.Row]) throws {
        guard isConfigured else { throw SinkError.notConfigured }
        for row in rows {
            guard let event = event(for: row) else { continue }
            FirebaseAnalytics.Analytics.logEvent(event.name, parameters: event.parameters)
        }
    }

    enum SinkError: Error { case notConfigured }

    // MARK: - 행 → GA 이벤트 (순수 함수, 테스트 고정)

    /// SDK가 예약한 이벤트 이름 — 직접 로그하면 SDK가 거부한다. `FIRAnalytics.h`(FirebaseAnalytics 12.19.2)의
    /// `logEventWithName:` 문서에 적힌 목록을 그대로 옮겼다(`screen_view`는 수동 로그가 허용되는 예외라 위 분기가
    /// 따로 다룬다). SDK를 올리면 헤더와 다시 대조한다.
    nonisolated static let reservedEventNames: Set<String> = [
        "ad_activeview", "ad_click", "ad_exposure", "ad_query", "ad_reward", "adunit_exposure",
        "app_clear_data", "app_exception", "app_remove", "app_store_refund", "app_store_subscription_cancel",
        "app_store_subscription_convert", "app_store_subscription_renew", "app_update", "app_upgrade",
        "dynamic_link_app_open", "dynamic_link_app_update", "dynamic_link_first_open", "error",
        "firebase_campaign", "first_open", "first_visit", "notification_dismiss", "notification_foreground",
        "notification_open", "notification_receive", "os_update", "session_start", "session_start_with_rollout",
        "user_engagement",
    ]

    /// 파이프라인 행 하나를 GA 이벤트로. `nil`이면 보내지 않는다.
    /// - `session_start`: Firebase가 같은 30분 규칙으로 자동 수집하므로 뺀다(두 번 세지 않게).
    /// - `screen_view`: GA의 화면 보고서가 읽도록 예약 이벤트 `screen_view`에 `screen_name`으로 싣는다
    ///   (Info.plist에서 자동 화면 추적을 꺼 두었으므로 이 수동 로그가 유일한 화면 신호다).
    /// - 그 밖의 예약 이름(`notification_open`)은 `reffi_` 접두사로 비켜 간다.
    /// - Bool 속성은 GA가 숫자·문자열만 받으므로 1/0으로, 이름·값 길이는 GA 한도(40/100)로 자른다.
    nonisolated static func event(for row: Analytics.Row) -> (name: String, parameters: [String: Any])? {
        switch row.name {
        case "session_start":
            return nil
        case "screen_view":
            guard case .string(let screen)? = row.props["screen"] else { return nil }
            // 자동 화면 추적을 껐으므로 클래스 축도 우리가 준다 — SwiftUI엔 뷰 컨트롤러 이름이 없어 화면 이름을 그대로 쓴다.
            let name = String(screen.prefix(100))
            return (AnalyticsEventScreenView, [AnalyticsParameterScreenName: name, AnalyticsParameterScreenClass: name])
        default:
            let name = reservedEventNames.contains(row.name) ? "reffi_" + row.name : row.name
            var parameters: [String: Any] = [:]
            for (key, value) in row.props {
                let parameterName = String(key.prefix(40))
                switch value {
                case .string(let s): parameters[parameterName] = String(s.prefix(100))
                case .int(let i): parameters[parameterName] = i
                case .bool(let b): parameters[parameterName] = b ? 1 : 0
                }
            }
            return (String(name.prefix(40)), parameters)
        }
    }
}
