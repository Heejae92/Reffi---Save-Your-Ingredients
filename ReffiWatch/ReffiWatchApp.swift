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

/// 워치 첫 화면 — 조리 중이면 그 진행을 맨 위에, 아래로 먼저 쓸 재료를 기한 순으로.
/// D-day는 분마다 그 순간의 날짜로 다시 센다(자정을 넘기면 폰 없이도 숫자가 바뀐다).
///
/// 앱 메인과 같은 문법이다(§13.11): 워드마크 머리, "Cooking now" 카드(손으로 자른 8각 종이 + 결 +
/// 아이브로 + 진행 막대), 재료는 메인 배지처럼 종이 조각 위에 종이컷 그림 + 신선도 표식.
/// 시스템 목록의 회색 판 대신 종이 면(`paper`)을 쓰고, 바탕은 앱 캔버스 색의 그라디언트다
/// (watchOS 컨테이너 배경 — 가장자리는 시스템이 검정으로 녹여 베젤과 이어진다).
/// 이미 소비기한이 지난 재료는 위젯과 같은 이유로 싣지 않는다(확인은 다음 날 아침 알림이 맡는다).
struct GlanceWatchView: View {
    let snapshot: GlanceSnapshot?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                ScrollView {
                    content(asOf: context.date)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 화면 모서리가 둥글어 가장자리에 붙은 조각·워드마크가 잘려 보인다 — 모바일 거터(s2).
                        .padding(.horizontal, ReffiSpace.s2)
                }
            }
            .containerBackground(ReffiColor.canvas.gradient, for: .navigation)
        }
        .environment(\.locale, snapshot?.locale ?? .autoupdatingCurrent)
    }

    @ViewBuilder private func content(asOf now: Date) -> some View {
        let bundle = LanguageBundle.bundle(for: snapshot?.language)
        let upcoming = snapshot?.upcoming(asOf: now) ?? []
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            ReffiLogo(height: WatchMetrics.wordmark)
                .padding(.bottom, ReffiSpace.s1)
            if let snapshot, snapshot.cook != nil || !upcoming.isEmpty {
                if let cook = snapshot.cook {
                    WatchCookCard(cook: cook, bundle: bundle)
                }
                if !upcoming.isEmpty {
                    WatchEyebrow(text: "USE FIRST", color: ReffiColor.muted,
                                 spoken: String(localized: "Use first", bundle: bundle,
                                                comment: "Widget and watch header above the list of items to use first; also the widget name"))
                        .padding(.top, ReffiSpace.s1)
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, item in
                        WatchItemRow(item: item, now: now, bundle: bundle, seed: index)
                    }
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
    }
}

/// 워치 전용 치수 — 좁은 화면에 맞춘 값만 이름으로 둔다.
private enum WatchMetrics {
    /// 워드마크 높이 — 앱 메인 머리의 비율 그대로 줄인 것(시계 옆 한 줄 높이).
    static let wordmark: CGFloat = 22
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

/// 조리 중 카드 — 메인의 "Cooking now" 카드와 같은 셰입·면(`PaperCutRect` 8각 + 종이 + 결)이다.
/// 아이브로 → 메뉴명 → 단계·경과 → 진행 막대(라이브 액티비티와 같은 `CookStepBar`).
private struct WatchCookCard: View {
    let cook: GlanceSnapshot.Cook
    let bundle: Bundle

    /// 지금 하는 단계(1부터) — 아직 체크 안 한 첫 단계. 라이브 액티비티와 같은 규칙.
    private var current: Int { cook.nextIndex.map { $0 + 1 } ?? cook.stepsTotal }

    var body: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            WatchEyebrow(text: "COOKING NOW", color: ReffiColor.blueDark,
                         spoken: String(localized: "Cooking now", bundle: bundle,
                                        comment: "Watch section header for the recipe being cooked"))
            Text(verbatim: cook.recipeName)
                .reffiType(.badgeLabel)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline) {
                if cook.stepsTotal > 0 {
                    Text(String(localized: "Step \(current) of \(cook.stepsTotal)",
                                bundle: bundle, comment: "Watch step progress, e.g. Step 2 of 5"))
                }
                Spacer(minLength: ReffiSpace.s1)
                Text(timerInterval: cook.startedAt...cook.startedAt.addingTimeInterval(WatchMetrics.timerCap),
                     countsDown: false)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            .reffiType(.metaText)
            .foregroundStyle(ReffiColor.ink2)
            if cook.stepsTotal > 0 {
                CookStepBar(fraction: Double(cook.stepsDone) / Double(cook.stepsTotal))
            }
        }
        .padding(ReffiSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = PaperCutRect(seed: 5)   // 메인 "Cooking now" 카드와 같은 8각
            shape.fill(ReffiColor.paper)
                .overlay(PaperGrain(seed: 27, strength: 0.7).clipShape(shape))
                .paperEdge(shape)
        }
        .accessibilityElement(children: .combine)
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
