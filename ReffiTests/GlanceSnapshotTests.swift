import Testing
import Foundation
@testable import Reffi

/// 앱 밖 표면(위젯·워치·라이브 액티비티)으로 나가는 요약의 계약.
/// 표면은 앱 코드를 못 쓰고 요약만 읽으므로, 여기서 앱의 규칙과 어긋나지 않는지 고정한다.
@MainActor
struct GlanceSnapshotTests {

    private func store(daysLeft: [Int]) -> FridgeStore {
        let ings = daysLeft.enumerated().map { i, d in
            Ingredient(name: "Item\(i)", category: "Veg", daysLeft: d,
                       quantity: Quantity(value: 2, unit: .piece), glyph: .generic)
        }
        return FridgeStore(ingredients: ings, recipes: [], history: [])
    }

    /// 위젯이 엔트리 날짜로 다시 세는 D-day가 앱의 달력 일수 규칙과 같다(자정 직전·정오 모두).
    @Test func daysLeftMatchesAppCalendarRule() {
        let cal = Calendar.current
        for hour in [0, 12, 23] {
            let now = cal.date(bySettingHour: hour, minute: 30, second: 0, of: Date())!
            for offset in -3...10 {
                let expires = Ingredient.day(offset: offset, from: now)
                let item = GlanceSnapshot.Item(id: UUID(), name: "x", expiresAt: expires, estimated: false, frozen: false)
                #expect(GlanceSnapshot.daysLeft(item, asOf: now) == Ingredient.days(from: now, to: expires))
            }
        }
    }

    /// "오늘 쓸 재료"는 오늘이 소비기한인 재료만 센다. 이미 지난 재료는 세지도, 목록에 싣지도 않는다.
    @Test func todayCountAndUpcomingSkipOverdueItems() {
        let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        func item(_ offset: Int) -> GlanceSnapshot.Item {
            GlanceSnapshot.Item(id: UUID(), name: "d\(offset)", expiresAt: Ingredient.day(offset: offset, from: now),
                                estimated: false, frozen: false, glyph: .egg)
        }
        let snapshot = GlanceSnapshot(items: [item(-3), item(-1), item(0), item(0), item(2)], cook: nil,
                                      language: nil, timeZone: nil)
        #expect(snapshot.todayCount(asOf: now) == 2)
        #expect(snapshot.upcoming(asOf: now).map(\.name) == ["d0", "d0", "d2"])
    }

    /// 이 필드들이 생기기 전에 저장된 요약도 읽힌다(업데이트 직후 위젯이 빈 채로 남지 않게).
    @Test func decodesSnapshotsSavedBeforeGlyphAndTimeZone() throws {
        let legacy = #"{"items":[{"id":"8D4E1A52-7C1B-4C43-9E2A-1F5C2B3A4D6E","name":"x","expiresAt":0,"estimated":false,"frozen":false}]}"#
        let snapshot = try JSONDecoder().decode(GlanceSnapshot.self, from: Data(legacy.utf8))
        #expect(snapshot.items.first?.glyph == nil)
        #expect(snapshot.timeZone == nil)
    }

    /// 요약은 기한 순이고, 조리에 예약된 재료는 빠지며, 조리 세션은 단계 진행과 함께 실린다.
    @Test func snapshotSkipsReservedItemsAndCarriesCookProgress() throws {
        let store = store(daysLeft: [0, 2, 5])
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0"], minutes: 10,
                                       steps: ["Chop", "Stir", "Plate"])
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))
        store.toggleCookStep(0)

        let snapshot = GlancePublisher.snapshot(of: store)
        #expect(snapshot.items.map(\.name) == ["Item1", "Item2"])
        #expect(snapshot.items.allSatisfy { $0.glyph == .generic })
        #expect(snapshot.timeZone == TimeZone.current.identifier)
        let cook = try #require(snapshot.cook)
        #expect(cook.stepsDone == 1 && cook.stepsTotal == 3 && cook.nextIndex == 1)

        let state = CookActivityController.contentState(of: try #require(store.activeCook), recipes: store.recipes)
        #expect(state.nextStep == "Stir" && state.nextIndex == 1)
        #expect(state.stepsDone == 1 && state.stepsTotal == 3)
    }

    /// 단계를 순서 없이 체크해도 "지금 단계"와 본문이 같은 단계를 가리킨다 — 3단계만 체크하면
    /// 완료 수는 1이지만 지금 단계는 여전히 1단계다.
    @Test func progressFollowsFirstUncheckedStepWhenCheckedOutOfOrder() throws {
        let store = store(daysLeft: [0])
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0"], minutes: 10,
                                       steps: ["Chop", "Stir", "Plate"])
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))
        store.toggleCookStep(2)

        let state = CookActivityController.contentState(of: try #require(store.activeCook), recipes: store.recipes)
        #expect(state.nextIndex == 0 && state.nextStep == "Chop")
        #expect(state.stepsDone == 1)
    }

    /// 범위 밖 체크 기록(레시피가 바뀐 구세션)은 완료 수에 들어가지 않는다.
    @Test func progressIgnoresOutOfRangeCheckedSteps() {
        let session = FridgeStore.CookSession(recipeName: "x", recipeID: nil, startedAt: Date(), count: 1,
                                              minutes: nil, steps: ["a", "b"], completedSteps: [0, 5, 9])
        let progress = GlancePublisher.progress(of: session, recipes: [])
        #expect(progress.done == 1 && progress.nextIndex == 1)
    }

    /// 표면의 D-day 글자는 앱과 같은 포맷터 한 벌에서 나온다(§3.4) — 추정 표시 포함.
    @Test func dDayTextIsTheAppFormatter() {
        let guess = Ingredient(name: "Zyx", category: "Other", expiresAt: Ingredient.day(offset: 2),
                               expiryIsEstimated: true)
        #expect(DDayLabel.text(daysLeft: guess.effectiveDaysLeft, estimated: true) == guess.dDayText)
        #expect(guess.dDayText.hasPrefix("≈ "))
    }

    /// 소리로 읽는 D-day도 추정 표시를 싣는다 — 화면의 "≈"와 같은 정보.
    @Test func spokenDDayCarriesTheEstimate() {
        let plain = DDayLabel.spoken(daysLeft: 2)
        let estimated = DDayLabel.spoken(daysLeft: 2, estimated: true)
        #expect(estimated != plain && estimated.contains(plain))
    }
}
