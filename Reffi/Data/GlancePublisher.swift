import Foundation
import os
import WidgetKit

/// 앱 밖 표면으로 재고 요약을 내보내는 단일 출구 — 스토어가 저장될 때마다(`FridgeStore.persist`),
/// 앱이 앞으로 올 때, 앱 언어·시간대가 바뀔 때 부른다.
///
/// 세 갈래로 나간다: ① App Group 파일 + 위젯 타임라인 재로드(홈·잠금화면 위젯)
/// ② WatchConnectivity 컨텍스트(워치) ③ 조리 라이브 액티비티 동기화.
/// ①②는 요약이 실제로 바뀐 때만 보낸다(판정 제스처마다 위젯 재로드 예산을 쓰지 않게) — 갈래마다
/// "마지막으로 성공한 값"을 따로 들고 있어, 한쪽이 실패해도 다음 발행에서 그쪽만 다시 시도한다.
/// ③은 단계 본문처럼 요약에 없는 값도 보므로 컨트롤러가 따로 비교한다.
@MainActor
enum GlancePublisher {
    private static let log = Logger(subsystem: "com.reffi.app", category: "glance")
    private static var lastSaved: GlanceSnapshot?
    private static var lastSent: GlanceSnapshot?

    static func publish(from store: FridgeStore) {
        // 저장 파일을 못 읽은 스토어는 빈 냉장고처럼 보인다 — 그 상태로 발행하면 마지막 정상 요약을
        // 빈 목록으로 덮고 조리 액티비티까지 끈다(오류 화면의 "빈 냉장고로 바꾸지 않는다"는 약속 위반).
        // 복구(`retryLoad`·`restoreBackup`)는 오류 표시를 먼저 걷고 `restore()`를 거쳐 다시 발행한다.
        guard !store.hasLoadError else { return }
        CookActivityController.sync(store.activeCook, recipes: store.recipes)
        let snapshot = snapshot(of: store)
        if snapshot != lastSaved {
            if let failure = GlanceStore.save(snapshot) {
                log.error("glance save failed: \(failure, privacy: .public)")
            } else {
                lastSaved = snapshot
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        if snapshot != lastSent {
            lastSent = snapshot
            WatchBridge.shared.send(snapshot)   // 워치가 아직 없으면 보관했다가 연결될 때 보낸다
        }
    }

    static func snapshot(of store: FridgeStore) -> GlanceSnapshot {
        // 이미 지난 재료는 표면이 싣지 않는다(확인은 다음 날 아침 알림이 맡는다). 상한을 자르기 전에
        // 걸러야 지난 재료가 앞자리(임박순)를 차지해 미래 자정 엔트리가 셀 재료를 밀어내지 않는다.
        // 지난 재료는 다시 안 지난 재료가 되지 않으므로 발행 시점에 버려도 안전하다.
        let items = store.available.lazy.filter { $0.effectiveDaysLeft >= 0 }.prefix(GlanceSnapshot.itemCap).map {
            GlanceSnapshot.Item(id: $0.id, name: $0.displayName, expiresAt: $0.effectiveExpiresAt,
                                estimated: $0.effectiveExpiryIsEstimated, frozen: $0.isFrozen, glyph: $0.glyph)
        }
        let cook = store.activeCook.map { session in
            let progress = progress(of: session, recipes: store.recipes)
            return GlanceSnapshot.Cook(recipeName: session.recipeName, startedAt: session.startedAt,
                                       minutes: session.minutes, stepsDone: progress.done,
                                       stepsTotal: progress.steps.count, nextIndex: progress.nextIndex)
        }
        return GlanceSnapshot(items: Array(items), cook: cook, language: AppLanguage.current.overrideCode,
                              timeZone: TimeZone.current.identifier)
    }

    /// 조리 진행 — 워치 요약과 라이브 액티비티가 **같은 계산**을 본다. 체크 기록은 범위 밖 인덱스를
    /// 걸러 세고(레시피가 바뀐 구세션), "지금 단계"는 아직 체크 안 한 첫 단계다(순서 없이 체크해도 맞다).
    static func progress(of session: FridgeStore.CookSession,
                         recipes: [Recipe]) -> (steps: [String], done: Int, nextIndex: Int?) {
        let steps = FridgeStore.CookSession.resolvedSteps(snapshot: session.steps, recipeID: session.recipeID,
                                                          in: recipes) ?? []
        let done = Set(session.completedSteps ?? []).filter { steps.indices.contains($0) }
        return (steps, done.count, steps.indices.first { !done.contains($0) })
    }
}
