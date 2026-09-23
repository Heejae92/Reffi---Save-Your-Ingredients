import ActivityKit
import SwiftUI
import WidgetKit

/// 조리 세션 라이브 액티비티 — 잠금화면 배너와 다이내믹 아일랜드.
/// 앱의 `CookActivityController`가 발주에 시작하고, 단계 체크마다 갱신하고, 완료·취소에 끝낸다.
/// 경과 시간은 시스템 타이머 텍스트라 갱신 푸시 없이 흐른다.
///
/// 잠금화면 배너는 메인의 "Cooking now" 카드와 같은 문법이다(§13.11): 종이 면, `COOKING NOW`
/// 크롬 아이브로(blueDark), 메뉴명은 티켓과 같은 `menuName`, 진행 막대는 토글과 같은 빈 슬롯
/// (`paperCut` 재단선) + 채움(`blue`).
struct CookLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookActivityAttributes.self) { context in
            CookLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .environment(\.locale, CookText(state: context.state).locale)
                .liveActivityTypeCap()
                .activityBackgroundTint(ReffiColor.paper)
                .activitySystemActionForegroundColor(ReffiColor.ink)
        } dynamicIsland: { context in
            let text = CookText(state: context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CookPot(size: CookMetrics.expandedIcon)
                        .accessibilityHidden(true)   // 옆의 메뉴명이 같은 뜻을 읽는다
                        .padding(.leading, ReffiSpace.s1)
                        .liveActivityTypeCap()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimer(attributes: context.attributes, isStale: context.isStale)
                        .font(.reffiNum(.body))
                        .foregroundStyle(ReffiColor.ink2)
                        .padding(.trailing, ReffiSpace.s1)
                        .liveActivityTypeCap()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: context.attributes.recipeName)
                        .reffiType(.badgeLabel)
                        .foregroundStyle(ReffiColor.ink)
                        .lineLimit(1)
                        .liveActivityTypeCap()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CookProgress(attributes: context.attributes, state: context.state, text: text)
                        .padding(.horizontal, ReffiSpace.s1)
                        .liveActivityTypeCap()
                }
            } compactLeading: {
                CookPot(size: CookMetrics.compactIcon)
                    .accessibilityLabel(Text(verbatim: "\(text.eyebrowSpoken), \(context.attributes.recipeName)"))
            } compactTrailing: {
                if context.state.stepsTotal > 0 {
                    Text(verbatim: text.fraction)
                        .font(.reffiNum(.meta))
                        .foregroundStyle(ReffiColor.ink)
                        .accessibilityLabel(Text(verbatim: text.stepLabel))
                        .liveActivityTypeCap()
                } else {
                    ElapsedTimer(attributes: context.attributes, isStale: context.isStale, showsHours: false)
                        .font(.reffiNum(.meta))
                        .frame(maxWidth: CookMetrics.compactTimer)
                        .liveActivityTypeCap()
                }
            } minimal: {
                CookPot(size: CookMetrics.compactIcon)
                    .accessibilityLabel(Text(verbatim: text.eyebrowSpoken))
            }
            .keylineTint(ReffiColor.blue)
        }
    }
}

/// 이 표면의 문구 — 앱 언어 선택(상태의 `language`)을 따르는 번들로 푼다.
struct CookText {
    let bundle: Bundle
    let state: CookActivityAttributes.ContentState

    init(state: CookActivityAttributes.ContentState) {
        bundle = LanguageBundle.bundle(for: state.language)
        self.state = state
    }

    var locale: Locale { state.language.map(Locale.init(identifier:)) ?? .autoupdatingCurrent }

    /// 지금 하는 단계(1부터) — 아직 체크 안 한 첫 단계. 아래 본문(`nextStep`)과 같은 인덱스에서 나온다.
    /// 다 체크했으면 마지막 단계에 머문다.
    var current: Int { state.nextIndex.map { $0 + 1 } ?? state.stepsTotal }
    var fraction: String { "\(current)/\(state.stepsTotal)" }

    /// 아이브로는 화면에선 비번역 크롬(`COOKING NOW`), 소리로는 로컬라이즈된 말.
    var eyebrowSpoken: String {
        String(localized: "Cooking now", bundle: bundle, comment: "Live Activity label while a recipe is being cooked")
    }
    var stepLabel: String {
        String(localized: "Step \(current) of \(state.stepsTotal)", bundle: bundle,
               comment: "Live Activity step progress, e.g. Step 2 of 5")
    }
    /// 다음 단계 본문, 다 체크했으면 앱의 실제 버튼 이름(요리 완료)으로 마무리를 안내한다.
    var detail: String? {
        if let next = state.nextStep { return next }
        guard state.stepsTotal > 0 else { return nil }
        return String(localized: "All steps checked. Tap Finish cooking in Reffi.", bundle: bundle,
                      comment: "Live Activity message after every step is checked; Finish cooking is the in-app button")
    }
}

/// 라이브 액티비티 전용 치수 — 아이콘은 §5 크기 규칙(본문 옆 16·단독 24), 축소 타이머 폭은
/// GSF 12 tabular "MM:SS"(≈32pt)에 한 자리 여유를 둔 값(시·분·초 표기면 44pt를 넘었다).
private enum CookMetrics {
    static let compactIcon: CGFloat = 16
    static let expandedIcon: CGFloat = 24
    static let compactTimer: CGFloat = 52
}

private struct CookLockScreenView: View {
    let attributes: CookActivityAttributes
    let state: CookActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let text = CookText(state: state)
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                Text(verbatim: "COOKING NOW")
                    .reffiType(.monoEyebrow)
                    .foregroundStyle(ReffiColor.blueDark)
                    .accessibilityLabel(Text(verbatim: text.eyebrowSpoken))
                Spacer(minLength: ReffiSpace.s2)
                ElapsedTimer(attributes: attributes, isStale: isStale)
                    .reffiType(.metaText)
                    .foregroundStyle(ReffiColor.ink2)
            }
            Text(verbatim: attributes.recipeName)
                .reffiType(.menuName)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1)
            CookProgress(attributes: attributes, state: state, text: text)
        }
        .padding(ReffiSpace.s4)
    }
}

/// 다음 단계 한두 줄 + 진행 막대. 단계가 없으면 조리 시간 기준 막대(시스템 타이머)로 대신한다.
private struct CookProgress: View {
    let attributes: CookActivityAttributes
    let state: CookActivityAttributes.ContentState
    let text: CookText

    var body: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            if let detail = text.detail {
                Text(verbatim: detail)
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                    .lineLimit(2)
            }
            if state.stepsTotal > 0 {
                HStack(spacing: ReffiSpace.s2) {
                    CookStepBar(fraction: Double(state.stepsDone) / Double(state.stepsTotal))
                    Text(verbatim: text.stepLabel)
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: text.stepLabel))
            } else if let end = attributes.expectedEnd, end > attributes.startedAt {
                // 시간 기준 막대는 시스템이 스스로 흘려 그리는 기본 스타일만 가능하다(커스텀 스타일은 멈춘다).
                ProgressView(timerInterval: attributes.startedAt...end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(ReffiColor.blue)
            }
        }
    }
}

/// 발주 시각부터 흐르는 경과 시간 — 시스템이 그리는 타이머라 갱신 없이 초 단위로 움직인다.
/// 상한은 시스템이 액티비티를 끝내는 시각(8시간)이라, 끝난 뒤 잠금화면에 남는 동안 시계가
/// 계속 흐르지 않는다. stale이면(시스템이 끝냄) 멈춘 시계 대신 아예 숨긴다.
private struct ElapsedTimer: View {
    let attributes: CookActivityAttributes
    let isStale: Bool
    var showsHours = true

    var body: some View {
        if !isStale {
            Text(timerInterval: attributes.startedAt...attributes.endOfLife, countsDown: false,
                 showsHours: showsHours)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}

private extension View {
    /// 라이브 액티비티의 글자 크기 상한 — 잠금화면 배너(시스템 높이 상한 160pt)와 다이내믹 아일랜드
    /// (펼침 영역·축소 폭이 모두 고정)는 크기가 정해진 틀이라, 큰 글자에서 진행 막대·단계 줄이 잘린다.
    /// 기본 크기(`large`)에서 멈춘다.
    func liveActivityTypeCap() -> some View { dynamicTypeSize(...DynamicTypeSize.large) }
}

/// 조리 표식 — 앱의 레시피 아이콘(`ReffiIcon.recipe`), 브랜드 blue 잉크(§5 — 면 위 아이콘은 dark 변형).
private struct CookPot: View {
    let size: CGFloat
    var body: some View {
        ReffiIcon.recipe.reffi(size, .bold)
            .foregroundStyle(ReffiColor.blueDark)
    }
}
