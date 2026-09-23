import SwiftUI

@main
struct ReffiWatchApp: App {
    @State private var store = WatchGlanceStore()

    var body: some Scene {
        WindowGroup {
            GlanceWatchView(snapshot: store.snapshot)
        }
    }
}

/// 워치 첫 화면. 조리가 없으면 먼저 쓸 재료 목록 한 장이고, 조리 중이면 세로 페이지 두 장이다
/// (크라운 한 칸이 한 장): 1쪽은 화면 바탕 전체가 진행 게이지인 조리 화면, 2쪽은 조리가 없을 때와
/// 똑같은 목록. 쓸 재료가 없으면 1쪽 한 장이고, 새 조리가 시작되면 1쪽부터 연다.
/// D-day는 분마다 그 순간의 날짜로 다시 센다(자정을 넘기면 폰 없이도 숫자가 바뀐다).
///
/// 앱 메인과 같은 문법이다(§13.11): 워드마크 머리, 재료는 메인 배지처럼 종이 조각 위에 종이컷 그림 +
/// 신선도 표식. 시스템 목록의 회색 판 대신 종이 면(`paper`)을 쓰고, 바탕은 앱 캔버스 색의 그라디언트다
/// (watchOS 컨테이너 배경 — 가장자리는 시스템이 검정으로 녹여 베젤과 이어진다).
/// 이미 소비기한이 지난 재료는 위젯과 같은 이유로 싣지 않는다(확인은 다음 날 아침 알림이 맡는다).
struct GlanceWatchView: View {
    let snapshot: GlanceSnapshot?
    @State private var page: WatchPage = .cook

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let bundle = LanguageBundle.bundle(for: snapshot?.language)
                let upcoming = snapshot?.upcoming(asOf: context.date) ?? []
                if let cook = snapshot?.cook {
                    // 목록이 없으면 1쪽 한 장 — 선택을 고정해 빈 페이지로 넘어가지 않게 한다.
                    TabView(selection: upcoming.isEmpty ? .constant(.cook) : $page) {
                        WatchCookPage(cook: cook, bundle: bundle, isFront: upcoming.isEmpty || page == .cook)
                            .tag(WatchPage.cook)
                            .containerBackground(ReffiColor.canvas.gradient, for: .tabView)
                        if !upcoming.isEmpty {
                            WatchListPage(snapshot: snapshot, upcoming: upcoming, now: context.date, bundle: bundle)
                                .tag(WatchPage.list)
                                .containerBackground(ReffiColor.canvas.gradient, for: .tabView)
                        }
                    }
                    .tabViewStyle(.verticalPage)
                    // 목록 쪽이 사라지면 선택도 1쪽으로 — 두면 재료가 다시 생길 때 저절로 2쪽으로 넘어간다.
                    .onChange(of: upcoming.isEmpty) { _, empty in if empty { page = .cook } }
                } else {
                    WatchListPage(snapshot: snapshot, upcoming: upcoming, now: context.date, bundle: bundle)
                }
            }
            .containerBackground(ReffiColor.canvas.gradient, for: .navigation)
        }
        .onChange(of: snapshot?.cook?.startedAt) { page = .cook }   // 새 조리는 1쪽부터
        .environment(\.locale, snapshot?.locale ?? .autoupdatingCurrent)
    }
}

private enum WatchPage: Hashable { case cook, list }

/// 먼저 쓸 재료 한 장 — 조리가 없을 때의 첫 화면이자 조리 중 2쪽이다. 모양은 둘이 같다.
private struct WatchListPage: View {
    let snapshot: GlanceSnapshot?
    let upcoming: [GlanceSnapshot.Item]
    let now: Date
    let bundle: Bundle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                ReffiLogo(height: WatchMetrics.wordmark)
                    .padding(.bottom, ReffiSpace.s1)
                if !upcoming.isEmpty {
                    WatchEyebrow(text: "USE FIRST", color: ReffiColor.muted,
                                 spoken: String(localized: "Use first", bundle: bundle,
                                                comment: "Widget and watch header above the list of items to use first; also the widget name"))
                        .padding(.top, ReffiSpace.s1)
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, item in
                        WatchItemRow(item: item, now: now, bundle: bundle, seed: index)
                    }
                } else {
                    Text(snapshot == nil
                         ? String(localized: "Open Reffi on your iPhone to see what to use first.",
                                  comment: "Watch message before the phone has shared any data")
                         : String(localized: "Nothing to use up right now.", bundle: bundle,
                                  comment: "Widget and watch message when there is nothing in the fridge to use"))
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 화면 모서리가 둥글어 가장자리에 붙은 조각·워드마크가 잘려 보인다 — 모바일 거터(s2).
            .padding(.horizontal, ReffiSpace.s2)
        }
    }
}

/// 워치 전용 치수 — 좁은 화면에 맞춘 값만 이름으로 둔다.
private enum WatchMetrics {
    /// 워드마크 높이 — 앱 메인 머리의 비율 그대로 줄인 것(시계 옆 한 줄 높이).
    static let wordmark: CGFloat = 22
    /// 조리 1쪽의 워드마크 줄(22 + s1). 블록 아래에 같은 높이를 비워 블록이 시계 아래~화면 바닥의 가운데 선다.
    static let wordmarkRow: CGFloat = wordmark + ReffiSpace.s1
    /// 재료 그림 — `ReffiFoodIcon.rowMini`(32)보다 한 단 작게(좁은 행).
    static let rowIcon: CGFloat = 28
    /// 경과 시계 상한 — 폰의 라이브 액티비티와 같은 8시간(완료를 잊은 세션에서 시계가 끝없이 흐르지 않게).
    static let timerCap: TimeInterval = 8 * 60 * 60
}

/// 섹션 머리말 — 앱 메인의 "COOKING NOW"와 같은 크롬 아이브로(비번역 라틴 올캡). 소리로는 로컬라이즈된 말.
private struct WatchEyebrow: View {
    let text: String
    let color: Color
    let spoken: String
    var body: some View {
        Text(verbatim: text)
            .reffiType(.monoEyebrow)
            .foregroundStyle(color)
            .accessibilityLabel(Text(verbatim: spoken))
            .accessibilityAddTraits(.isHeader)
    }
}

/// 조리 1쪽 — 종이 카드도 막대도 없이 화면 바탕 전체가 진행 게이지다(`WatchCookGauge`, §13.11).
/// 글자는 전부 가운데 정렬: 워드마크 · 아이브로 · 메뉴명 · 단계와 경과. 수위가 올라오며 글자 뒤를 지나도
/// 글자색은 바뀌지 않는다 — 마른 면·뒤 장·앞 장 어디서나 실측 4.5를 넘는다(최저 `blueDark` 6.40).
private struct WatchCookPage: View {
    let cook: GlanceSnapshot.Cook
    let bundle: Bundle
    let isFront: Bool

    /// 지금 하는 단계(1부터) — 아직 체크 안 한 첫 단계. 라이브 액티비티와 같은 규칙.
    private var current: Int { cook.nextIndex.map { $0 + 1 } ?? cook.stepsTotal }
    /// 모든 단계를 체크했는가(라이브 액티비티와 같은 판정: 체크 안 한 단계가 없다).
    private var allChecked: Bool { cook.stepsTotal > 0 && cook.nextIndex == nil }
    /// 수위 = 체크한 단계 / 전체(라이브 액티비티 막대와 같은 값). 단계가 없는 레시피는 물이 없다.
    private var fraction: Double? {
        guard cook.stepsTotal > 0 else { return nil }
        return min(max(Double(cook.stepsDone) / Double(cook.stepsTotal), 0), 1)
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                ReffiLogo(height: WatchMetrics.wordmark)
                    .padding(.bottom, ReffiSpace.s1)
                block.frame(maxHeight: .infinity)
                Color.clear.frame(height: WatchMetrics.wordmarkRow)   // 워드마크 줄과 짝 — 블록을 한가운데 세운다
            }
            block.frame(maxHeight: .infinity)                         // 큰 글자: 워드마크를 먼저 내린다
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 세로 페이지는 아래에도 안전 영역을 둬서(시뮬레이터 실측 ≈37pt) 블록이 화면 중심보다 15pt 위에 떴다 —
        // 수위 60%의 수면이 아이브로를 지나갔다. 아래 안전 영역만 무시해 블록을 시계 아래~화면 바닥의 가운데에 세운다.
        .ignoresSafeArea(.container, edges: .bottom)
        .background {
            // 세션마다 새 게이지 — 조리를 바꿔 끼우면 옛 수위에서 새 수위로 빠지는 스프링 없이 제 수위로 뜬다.
            if let fraction { WatchCookGauge(fraction: fraction, isFront: isFront).id(cook.startedAt) }
        }
        // 한 장짜리 게이지라 글자 크기에 상한을 둔다(라이브 액티비티가 large에서 멈추는 것과 같은 이유).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var block: some View {
        VStack(spacing: 0) {
            WatchEyebrow(text: "COOKING NOW", color: ReffiColor.blueDark,
                         spoken: String(localized: "Cooking now", bundle: bundle,
                                        comment: "Watch section header for the recipe being cooked"))
            Text(verbatim: cook.recipeName)
                .reffiType(.menuName)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(ReffiShrink.fit)
                .padding(.top, ReffiSpace.s1)
            // 메인 조리 카드와 같은 접힘: 한 줄에 안 들어가면 단계와 경과를 두 줄로.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ReffiSpace.s1) {
                    stepLabel
                    if cook.stepsTotal > 0 { Text(verbatim: "·").accessibilityHidden(true) }
                    elapsed
                }
                VStack(spacing: ReffiSpace.s0) {
                    stepLabel
                    elapsed
                }
            }
            .reffiType(.metaText)
            .foregroundStyle(ReffiColor.ink2)
            .padding(.top, ReffiSpace.s0)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, ReffiSpace.s4)
        .accessibilityElement(children: .combine)
        // 다 체크하면 "Step 5 of 5"가 4/5 체크와 같게 읽힌다 — 게이지가 가득 찬 사실을 말로 덧붙인다
        // (라이브 액티비티와 같은 문장).
        .accessibilityValue(allChecked
                            ? Text(String(localized: "All steps checked. Tap Finish cooking in Reffi.", bundle: bundle,
                                          comment: "Live Activity message after every step is checked; Finish cooking is the in-app button"))
                            : Text(verbatim: ""))
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder private var stepLabel: some View {
        if cook.stepsTotal > 0 {
            Text(String(localized: "Step \(current) of \(cook.stepsTotal)",
                        bundle: bundle, comment: "Watch step progress, e.g. Step 2 of 5"))
        }
    }

    private var elapsed: some View {
        Text(timerInterval: cook.startedAt...cook.startedAt.addingTimeInterval(WatchMetrics.timerCap),
             countsDown: false)
            .monospacedDigit()
    }
}

/// 재료 한 조각 — 메인 배지(`IngredientBadge`)의 종이 조각 위에 냉장고 목록의 그림을 얹은 것.
private struct WatchItemRow: View {
    let item: GlanceSnapshot.Item
    let now: Date
    let bundle: Bundle
    let seed: Int

    var body: some View {
        let days = GlanceSnapshot.daysLeft(item, asOf: now)
        let freshness = Freshness(daysLeft: days)
        let dDay = DDayLabel.text(daysLeft: days, estimated: item.estimated, bundle: bundle)
        HStack(spacing: ReffiSpace.s2) {
            PaperSilhouette(glyph: item.glyph ?? .generic, fresh: freshness)
                .frame(width: WatchMetrics.rowIcon, height: WatchMetrics.rowIcon)
            VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                Text(verbatim: item.name)
                    .reffiType(.checklistItem)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(2)
                FreshnessTag(freshness: freshness, text: dDay)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReffiSpace.s3)
        .padding(.vertical, ReffiSpace.s2)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)   // 메인 배지와 같은 조각
            shape.fill(ReffiColor.paper).paperEdge(shape)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(item.name), \(DDayLabel.spoken(daysLeft: days, estimated: item.estimated, bundle: bundle))"))
    }
}
