import Foundation
import Observation
import WatchConnectivity

/// 워치 쪽 재고 요약 — 폰 앱이 WatchConnectivity 애플리케이션 컨텍스트로 보낸 `GlanceSnapshot`을
/// 받아 들고 있는다. 정본은 폰의 `FridgeStore`이고 여기서는 읽기만 한다.
/// 마지막으로 받은 JSON은 기기에 남겨 두어, 폰이 멀리 있어도 앱을 켜면 바로 그린다.
@MainActor
@Observable
final class WatchGlanceStore: NSObject, WCSessionDelegate {
    private(set) var snapshot: GlanceSnapshot?

    private static let cacheKey = "glance.cache"

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey) {
            snapshot = try? JSONDecoder().decode(GlanceSnapshot.self, from: data)
        }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func apply(_ data: Data?) {
        guard let data, let next = try? JSONDecoder().decode(GlanceSnapshot.self, from: data) else { return }
        snapshot = next
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    // MARK: - WCSessionDelegate

    /// 활성화 시점에 이미 도착해 있던 최신 컨텍스트부터 반영한다(워치 앱이 꺼져 있던 사이의 발행).
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let data = session.receivedApplicationContext[GlanceSnapshot.watchContextKey] as? Data
        Task { @MainActor in self.apply(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext[GlanceSnapshot.watchContextKey] as? Data
        Task { @MainActor in self.apply(data) }
    }
}
