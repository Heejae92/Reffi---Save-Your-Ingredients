import ActivityKit
import Foundation
import os

/// 조리 세션 ↔ 라이브 액티비티 동기화. 스토어의 `activeCook`이 유일한 정본이고, 이 컨트롤러는
/// 그 값을 따라가기만 한다: 세션이 생기면 시작, 단계 체크·언어가 바뀌면 갱신, 완료·취소면 종료.
///
/// 세션 식별은 시작 시각이다(발주마다 새로 찍히고 세션이 사는 동안 안 바뀐다). 앱이 죽었다 살아나도
/// `Activity.activities`에서 같은 세션의 액티비티를 다시 찾으므로 중복이 안 생긴다.
/// 사용자가 설정에서 라이브 액티비티를 껐으면 조용히 건너뛴다.
@MainActor
enum CookActivityController {
    private static let log = Logger(subsystem: "com.reffi.app", category: "live-activity")

    /// 이 세션으로 이미 한 번 띄웠다는 표시(시작 시각). 띄운 액티비티가 목록에서 사라졌는데 세션은
    /// 그대로라면 사용자가 잠금화면에서 쓸어 닫았거나 시스템이 8시간 만에 끝낸 것이다 — 그때 다시
    /// 띄우면 닫은 카드가 다음 저장마다 되살아난다. 세션이 끝나면(완료·취소) 지워서, 되돌리기로
    /// 세션이 돌아오면 다시 띄울 수 있게 한다.
    private static let requestedKey = "liveActivity.requestedSession"

    /// 업데이트·종료는 비동기라, 따로따로 띄우면 ActivityKit에 도착하는 순서가 뒤바뀔 수 있다
    /// (체크 두 번이 역순으로 적용되는 식). 한 줄로 이어 붙여 요청 순서대로 처리한다.
    private static var tail: Task<Void, Never>?
    /// 마지막으로 보낸 상태 — `activity.content`는 앞선 업데이트가 끝나기 전엔 옛 값이라 비교에 못 쓴다.
    private static var lastSent: [String: CookActivityAttributes.ContentState] = [:]

    static func sync(_ session: FridgeStore.CookSession?, recipes: [Recipe]) {
        let running = Activity<CookActivityAttributes>.activities
        guard let session else {
            UserDefaults.standard.removeObject(forKey: requestedKey)
            for activity in running { end(activity) }
            return
        }
        let key = session.startedAt.timeIntervalSinceReferenceDate
        let state = contentState(of: session, recipes: recipes)
        let matching = running.first { $0.attributes.startedAt == session.startedAt }
        for activity in running where activity.id != matching?.id { end(activity) }   // 교체된 이전 세션

        if let matching {
            guard (lastSent[matching.id] ?? matching.content.state) != state else { return }
            lastSent[matching.id] = state
            let content = ActivityContent(state: state, staleDate: matching.attributes.endOfLife)
            enqueue { await matching.update(content) }
            return
        }
        // 이미 띄웠던 세션이면(닫혔거나 시스템이 끝냄) 다시 띄우지 않는다. 오래된 세션도 새로 띄우지 않는다 —
        // 시스템이 8시간 뒤 끝내므로, 완료를 잊은 며칠 묵은 발주가 앱을 열 때마다 되살아나게 된다.
        guard UserDefaults.standard.object(forKey: requestedKey) as? Double != key,
              Date().timeIntervalSince(session.startedAt) < CookActivityAttributes.maxDuration,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = CookActivityAttributes(recipeName: session.recipeName,
                                                startedAt: session.startedAt, minutes: session.minutes)
        do {
            let activity = try Activity.request(attributes: attributes,
                                                content: ActivityContent(state: state, staleDate: attributes.endOfLife))
            lastSent[activity.id] = state
            UserDefaults.standard.set(key, forKey: requestedKey)
        } catch {
            log.error("live activity request failed: \(String(describing: error), privacy: .public)")
        }
    }

    static func contentState(of session: FridgeStore.CookSession,
                             recipes: [Recipe]) -> CookActivityAttributes.ContentState {
        let progress = GlancePublisher.progress(of: session, recipes: recipes)
        return .init(stepsDone: progress.done, stepsTotal: progress.steps.count,
                     nextIndex: progress.nextIndex, nextStep: progress.nextIndex.map { progress.steps[$0] },
                     language: AppLanguage.current.overrideCode)
    }

    private static func end(_ activity: Activity<CookActivityAttributes>) {
        lastSent[activity.id] = nil
        enqueue { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private static func enqueue(_ operation: @escaping @Sendable () async -> Void) {
        let previous = tail
        tail = Task {
            await previous?.value
            await operation()
        }
    }
}
