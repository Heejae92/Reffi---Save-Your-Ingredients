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
/// 앱·위젯과 같은 문법이다(§13.11): 종이컷 재료 그림, 신선도 표식(바 + D-N), 크롬 아이브로.
/// 이미 소비기한이 지난 재료는 위젯과 같은 이유로 싣지 않는다(확인은 다음 날 아침 알림이 맡는다).
struct GlanceWatchView: View {
    let snapshot: GlanceSnapshot?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                content(asOf: context.date)
            }
            .navigationTitle(Text(verbatim: "Reffi"))
        }
        .environment(\.locale, snapshot?.locale ?? .autoupdatingCurrent)
    }

    @ViewBuilder private func content(asOf now: Date) -> some View {
        let bundle = LanguageBundle.bundle(for: snapshot?.language)
        let upcoming = snapshot?.upcoming(asOf: now) ?? []
        if let snapshot, snapshot.cook != nil || !upcoming.isEmpty {
            List {
                if let cook = snapshot.cook {
                    Section {
                        WatchCookRow(cook: cook, bundle: bundle)
                    } header: {
                        WatchEyebrow(text: "COOKING NOW", color: ReffiColor.blueDark,
                                     spoken: String(localized: "Cooking now", bundle: bundle,
                                                    comment: "Watch section header for the recipe being cooked"))
                    }
                }
                if !upcoming.isEmpty {
                    Section {
                        ForEach(upcoming) { item in
                            WatchItemRow(item: item, now: now, bundle: bundle)
                        }
                    } header: {
                        WatchEyebrow(text: "USE FIRST", color: ReffiColor.muted,
                                     spoken: String(localized: "Use first", bundle: bundle,
                                                    comment: "Widget and watch header above the list of items to use first; also the widget name"))
                    }
                }
            }
        } else {
            ScrollView {
                Text(snapshot == nil
                     ? String(localized: "Open Reffi on your iPhone to see what to use first.",
                              comment: "Watch message before the phone has shared any data")
                     : String(localized: "Nothing to use up right now.", bundle: bundle,
                              comment: "Widget and watch message when there is nothing in the fridge to use"))
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ReffiSpace.s2)
            }
        }
    }
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
    }
}

/// 워치 전용 치수 — 좁은 행에 맞춘 재료 그림 크기(`ReffiFoodIcon.rowMini` 32보다 한 단 작게).
private enum WatchMetrics {
    static let rowIcon: CGFloat = 28
    /// 경과 시계 상한 — 폰의 라이브 액티비티와 같은 8시간(완료를 잊은 세션에서 시계가 끝없이 흐르지 않게).
    static let timerCap: TimeInterval = 8 * 60 * 60
}

private struct WatchItemRow: View {
    let item: GlanceSnapshot.Item
    let now: Date
    let bundle: Bundle

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
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(item.name), \(DDayLabel.spoken(daysLeft: days, estimated: item.estimated, bundle: bundle))"))
    }
}

private struct WatchCookRow: View {
    let cook: GlanceSnapshot.Cook
    let bundle: Bundle

    /// 지금 하는 단계(1부터) — 아직 체크 안 한 첫 단계. 라이브 액티비티와 같은 규칙.
    private var current: Int { cook.nextIndex.map { $0 + 1 } ?? cook.stepsTotal }

    var body: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s0) {
            Text(verbatim: cook.recipeName)
                .reffiType(.subhead)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(2)
            HStack {
                if cook.stepsTotal > 0 {
                    Text(String(localized: "Step \(current) of \(cook.stepsTotal)",
                                bundle: bundle, comment: "Watch step progress, e.g. Step 2 of 5"))
                        .reffiType(.metaText)
                }
                Spacer(minLength: ReffiSpace.s1)
                Text(timerInterval: cook.startedAt...cook.startedAt.addingTimeInterval(WatchMetrics.timerCap),
                     countsDown: false)
                    .font(.reffiNum(.meta))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            .foregroundStyle(ReffiColor.ink2)
        }
    }
}
