import Foundation
import WatchConnectivity

/// 폰 → 워치 재고 요약 전송. 워치는 다른 기기라 App Group 파일을 못 읽으므로, 같은 `GlanceSnapshot`
/// JSON을 WatchConnectivity의 **애플리케이션 컨텍스트**로 보낸다 — 최신 값 하나만 유지되고,
/// 워치 앱이 꺼져 있어도 다음에 켤 때 마지막 값이 도착한다(메시지 큐가 쌓이지 않는다).
///
/// 세션 활성화는 비동기라 첫 발행이 활성화보다 먼저 올 수 있다 — 마지막 요약을 늘 보관해 두고
/// 활성화·워치 앱 설치 콜백에서 다시 보낸다. 워치가 없거나 워치 앱이 안 깔렸으면 보관만 한다.
final class WatchBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchBridge()

    private let lock = NSLock()
    private var latest: Data?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ snapshot: GlanceSnapshot) {
        guard WCSession.isSupported(), let data = try? JSONEncoder().encode(snapshot) else { return }
        lock.withLock { latest = data }
        flush()
    }

    private func flush() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = lock.withLock({ latest }) else { return }
        // 실패하면 다음 발행이나 다음 활성화에서 보관값으로 다시 시도한다.
        try? session.updateApplicationContext([GlanceSnapshot.watchContextKey: data])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        flush()
    }

    /// 워치 앱을 새로 깔았거나 페어링이 바뀌면 보관값을 다시 보낸다.
    func sessionWatchStateDidChange(_ session: WCSession) {
        flush()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// 워치를 바꿔 끼운 경우 — 새 워치와 세션을 다시 연다(Apple 권장 처리).
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
