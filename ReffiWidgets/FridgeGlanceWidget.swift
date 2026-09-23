import SwiftUI
import WidgetKit

/// "먼저 쓸 재료" 위젯 — 홈 화면(소·중)과 잠금화면(원형·사각·한 줄)을 한 종류로 낸다.
/// 데이터는 앱이 발행한 `GlanceSnapshot`(App Group)만 읽는다. D-day는 엔트리 날짜로 다시 세므로
/// 자정마다 엔트리를 하나씩 깔아 두면 앱을 안 열어도 숫자가 넘어간다.
///
/// 앱과 같은 문법으로 그린다(§13.11): 종이 면 + 결, 종이컷 재료 그림(`PaperSilhouette`, 시듦 포함),
/// 신선도 표식(`FreshnessTag` — 메인 배지의 바 + D-N), 머리말은 메인 "COOKING NOW"와 같은 크롬 아이브로.
struct FridgeGlanceWidget: Widget {
    static let kind = "FridgeGlance"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlanceProvider()) { entry in
            GlanceWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("Use first"))
        .description(Text("Shows what to use before it goes bad."))
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Timeline

struct GlanceEntry: TimelineEntry {
    let date: Date
    /// nil = 앱이 아직 요약을 한 번도 발행하지 않았다(설치 직후).
    let snapshot: GlanceSnapshot?
    /// 위젯이 뜨기 전 잠깐 그리는 자리표시자 — 글자 없이 행 모양만 그린다(콘텐츠 하드코딩 금지).
    var isPlaceholder = false
}

struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: .now, snapshot: nil, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        completion(GlanceEntry(date: .now, snapshot: GlanceStore.load()))
    }

    /// 지금 + 앞으로 7번의 자정. 그 뒤엔 다시 불러온다(그 사이 앱이 발행하면 즉시 재로드된다 —
    /// 시간대가 바뀌어도 요약에 시간대가 실려 있어 재발행·재로드가 따라온다).
    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        let snapshot = GlanceStore.load()
        let now = Date()
        let cal = Calendar.current
        let midnights = (1...7).compactMap { cal.date(byAdding: .day, value: $0, to: cal.startOfDay(for: now)) }
        let entries = ([now] + midnights).map { GlanceEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - 표시 모델

/// 엔트리 날짜 기준으로 다시 센 행들. 문자열은 앱 언어 선택을 따르는 번들로 푼다.
/// 이미 소비기한이 지난 재료는 싣지 않는다 — "먼저 쓸 것"이 아니라 "확인할 것"이고(다음 날 아침
/// 알림이 한 번 맡는다), 두면 지난 재료가 목록 앞자리를 붙박이로 차지한다.
struct GlanceRows {
    struct Row: Identifiable {
        let id: UUID
        let name: String
        let glyph: FoodGlyph
        let freshness: Freshness
        let dDay: String
        let spokenDDay: String
    }

    let rows: [Row]
    let todayCount: Int
    let bundle: Bundle

    init(_ snapshot: GlanceSnapshot, asOf date: Date) {
        let bundle = LanguageBundle.bundle(for: snapshot.language)
        self.bundle = bundle
        todayCount = snapshot.todayCount(asOf: date)
        rows = snapshot.upcoming(asOf: date).map { item in
            let days = GlanceSnapshot.daysLeft(item, asOf: date)
            return Row(id: item.id, name: item.name, glyph: item.glyph ?? .generic,
                       freshness: Freshness(daysLeft: days),
                       dDay: DDayLabel.text(daysLeft: days, estimated: item.estimated, bundle: bundle),
                       spokenDDay: DDayLabel.spoken(daysLeft: days, estimated: item.estimated, bundle: bundle))
        }
    }

    var todayText: String {
        String(localized: "\(todayCount) to use today", bundle: bundle,
               comment: "Widget count of items whose use-by date is today")
    }

    var title: String {
        String(localized: "Use first", bundle: bundle,
               comment: "Widget and watch header above the list of items to use first; also the widget name")
    }
}

// MARK: - Views

struct GlanceWidgetView: View {
    let entry: GlanceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .environment(\.locale, entry.snapshot?.locale ?? .autoupdatingCurrent)
            // 위젯 크기는 고정이라 큰 글자에서 행이 잘린다 — 앱의 빽빽한 표면과 같은 상한(xLarge).
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .containerBackground(for: .widget) {
                if family.isHome { PaperWidgetSurface() } else { Color.clear }
            }
    }

    @ViewBuilder private var content: some View {
        let model = entry.snapshot.map { GlanceRows($0, asOf: entry.date) }
        switch family {
        case .accessoryCircular:    GlanceCircular(model: model)
        case .accessoryRectangular: GlanceRectangular(model: model)
        case .accessoryInline:      GlanceInline(model: model)
        case .systemMedium:         GlanceMedium(model: model, isPlaceholder: entry.isPlaceholder)
        default:                    GlanceSmall(model: model, isPlaceholder: entry.isPlaceholder)
        }
    }
}

private extension WidgetFamily {
    var isHome: Bool { self == .systemSmall || self == .systemMedium }
}

/// 홈 위젯 면 — 앱 카드와 같은 종이(`paper`) + 옅은 결. 위젯 자체가 홈 화면 위의 종이 한 장이다.
private struct PaperWidgetSurface: View {
    var body: some View {
        ZStack {
            ReffiColor.paper
            PaperGrain(seed: 31, strength: 0.7)
        }
    }
}

/// 비어 있는 상태 문구 — 앱을 아직 안 열었을 때와 먼저 쓸 재료가 없을 때를 가른다.
private func emptyMessage(_ model: GlanceRows?) -> String {
    guard let model else {
        return String(localized: "Open Reffi to see what to use first.",
                      comment: "Widget message before the app has shared any data")
    }
    return String(localized: "Nothing to use up right now.", bundle: model.bundle,
                  comment: "Widget and watch message when there is nothing in the fridge to use")
}

/// 머리말 — 메인의 "COOKING NOW"와 같은 크롬 아이브로(비번역 라틴 올캡, §3.5 `monoEyebrow`).
/// 소리로는 로컬라이즈된 이름을 읽는다(올캡 영문 약어를 한국어 VoiceOver가 철자로 읽지 않게).
private struct GlanceEyebrow: View {
    let model: GlanceRows?
    var body: some View {
        Text(verbatim: "USE FIRST")
            .reffiType(.monoEyebrow)
            .foregroundStyle(ReffiColor.muted)
            .lineLimit(1)
            .accessibilityLabel(Text(verbatim: model?.title ?? String(localized: "Use first")))
    }
}

/// 재료 행 — 종이컷 그림 + 이름 + 신선도 표식. 냉장고 목록의 문법을 한 줄로 줄인 것.
/// `stacked`면 표식을 이름 아래로 내린다(소형 폭 ≈126pt에서는 한 줄이 이름을 한 글자까지 민다).
private struct GlanceRowView: View {
    let row: GlanceRows.Row
    var stacked = false

    var body: some View {
        Group {
            if stacked {
                HStack(spacing: ReffiSpace.s2) {
                    PaperSilhouette(glyph: row.glyph, fresh: row.freshness)
                        .frame(width: ReffiFoodIcon.rowMini, height: ReffiFoodIcon.rowMini)
                    VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                        name
                        FreshnessTag(freshness: row.freshness, text: row.dDay)
                    }
                }
            } else {
                HStack(spacing: ReffiSpace.s2) {
                    PaperSilhouette(glyph: row.glyph, fresh: row.freshness)
                        .frame(width: GlanceMetrics.rowIcon, height: GlanceMetrics.rowIcon)
                    name
                    Spacer(minLength: ReffiSpace.s2)
                    FreshnessTag(freshness: row.freshness, text: row.dDay).fixedSize()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(row.name), \(row.spokenDDay)"))
    }

    private var name: some View {
        Text(verbatim: row.name)
            .reffiType(.checklistItem)
            .foregroundStyle(ReffiColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(ReffiShrink.chrome)
    }
}

/// 위젯 전용 치수 — 중형의 한 줄 행은 4행이 콘텐츠 높이(≈126pt)에 들어가야 해서 그림을
/// `ReffiFoodIcon.rowMini`(32)보다 줄인다. 한 줄 행 높이 = 그림 높이다.
private enum GlanceMetrics {
    static let rowIcon: CGFloat = 24
    static let leftColumn: CGFloat = 104
    static let soloIcon: CGFloat = 24          // §5 단독 아이콘
    static let placeholderBar: CGFloat = 12    // 자리표시자 막대 — 한 줄 글자 높이쯤
}

/// 자리표시자 행 — 글자 대신 막대(콘텐츠를 지어내지 않는다).
private struct PlaceholderRows: View {
    let count: Int
    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            HStack(spacing: ReffiSpace.s2) {
                Circle().fill(ReffiColor.sub).frame(width: GlanceMetrics.rowIcon, height: GlanceMetrics.rowIcon)
                Capsule().fill(ReffiColor.sub).frame(height: GlanceMetrics.placeholderBar)
            }
        }
    }
}

private struct GlanceList: View {
    let model: GlanceRows?
    let limit: Int
    let isPlaceholder: Bool
    var stacked = false

    var body: some View {
        if isPlaceholder {
            PlaceholderRows(count: limit)
        } else if let model, !model.rows.isEmpty {
            ForEach(model.rows.prefix(limit)) { GlanceRowView(row: $0, stacked: stacked) }
        } else {
            Text(emptyMessage(model))
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GlanceSmall: View {
    let model: GlanceRows?
    let isPlaceholder: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            GlanceEyebrow(model: model)
            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                GlanceList(model: model, limit: 2, isPlaceholder: isPlaceholder, stacked: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GlanceMedium: View {
    let model: GlanceRows?
    let isPlaceholder: Bool
    var body: some View {
        HStack(alignment: .top, spacing: ReffiSpace.s4) {
            VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                GlanceEyebrow(model: model)
                Spacer(minLength: 0)
                if let model, !isPlaceholder {
                    Text(model.todayCount.formatted())
                        .font(.reffiNum(.hero))
                        .foregroundStyle(ReffiColor.ink)
                    Text(String(localized: "to use today", bundle: model.bundle,
                                comment: "Widget label under the count of items whose use-by date is today"))
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                        .lineLimit(2)
                }
            }
            .frame(width: GlanceMetrics.leftColumn, alignment: .leading)
            .modifier(CombinedLabel(label: model.map { "\($0.title), \($0.todayText)" }))

            VStack(alignment: .leading, spacing: ReffiSpace.s1) {
                GlanceList(model: model, limit: 4, isPlaceholder: isPlaceholder)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 요약 칸을 한 문장으로 읽힌다 — 요약이 없으면(설치 직후) 자식 그대로 둔다(빈 라벨 금지).
private struct CombinedLabel: ViewModifier {
    let label: String?
    func body(content: Content) -> some View {
        if let label {
            content.accessibilityElement(children: .ignore).accessibilityLabel(Text(verbatim: label))
        } else {
            content
        }
    }
}

// MARK: - 앱 안 미리보기 (§14.9 위젯 제안)

/// 소형 위젯을 앱 안에서 **같은 뷰**(`GlanceSmall`)로 그린다 — 위젯 제안 다이얼로그의 그림이다.
/// 모양의 정본을 둘로 나누지 않으려고 이 파일을 앱 타깃에도 컴파일한다(project.yml). 시스템이 그리는
/// 컨테이너(콘텐츠 여백 · 모서리 · 종이 면)만 여기서 따라 그린다 — 치수는 `PreviewMetrics`.
struct GlanceWidgetPreview: View {
    let snapshot: GlanceSnapshot
    let date: Date

    var body: some View {
        GlanceSmall(model: GlanceRows(snapshot, asOf: date), isPlaceholder: false)
            .environment(\.locale, snapshot.locale)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)   // 위젯과 같은 상한(`GlanceWidgetView`)
            .padding(PreviewMetrics.contentMargin)
            .frame(width: PreviewMetrics.side, height: PreviewMetrics.side)
            .background { PaperWidgetSurface() }
            .clipShape(RoundedRectangle(cornerRadius: PreviewMetrics.corner, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    /// 6.1인치급 iPhone(393pt 폭)의 소형 위젯 — 한 변 158 · 모서리 ≈22 · 시스템 콘텐츠 여백 16.
    /// 기기마다 조금씩 다르지만(141~170) 미리보기는 크기를 약속하지 않고 모양을 보여 준다.
    private enum PreviewMetrics {
        static let side: CGFloat = 158
        static let corner: CGFloat = 22
        static let contentMargin: CGFloat = 16
    }
}

// MARK: - 잠금화면 (시스템이 단색 비브런트로 칠한다 — 그림·색 대신 글자와 형태로)

private struct GlanceCircular: View {
    let model: GlanceRows?
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let model {
                VStack(spacing: 0) {
                    Text(model.todayCount.formatted())
                        .font(.reffiNum(.hero))
                        .minimumScaleFactor(ReffiShrink.chrome)
                        .widgetAccentable()
                    Text(DDayLabel.text(daysLeft: 0, bundle: model.bundle))
                        .reffiType(.groupLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(ReffiShrink.chrome)
                }
                .padding(ReffiSpace.s1)
            } else {
                // 앱을 아직 안 열었을 때 빈 원만 남지 않게 — 앱의 냉장고 기호.
                ReffiIcon.fridge.reffi(GlanceMetrics.soloIcon, .bold)
                    .widgetAccentable()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: model?.todayText ?? emptyMessage(model)))
    }
}

private struct GlanceRectangular: View {
    let model: GlanceRows?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let model, !model.rows.isEmpty {
                Text(verbatim: model.todayText)
                    .reffiType(.metaText)
                    .widgetAccentable()
                    .lineLimit(1)
                ForEach(model.rows.prefix(2)) { row in
                    HStack(spacing: ReffiSpace.s1) {
                        Text(verbatim: row.name).lineLimit(1)
                        Spacer(minLength: ReffiSpace.s1)
                        Text(verbatim: row.dDay).font(.reffiNum(.meta, for: row.dDay)).fixedSize()
                    }
                    .reffiType(.metaText)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "\(row.name), \(row.spokenDDay)"))
                }
            } else {
                Text(emptyMessage(model))
                    .reffiType(.metaText)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GlanceInline: View {
    let model: GlanceRows?
    var body: some View {
        if let model, model.todayCount > 0 {
            Text(verbatim: model.todayText)
        } else if let model, let first = model.rows.first {
            Text(verbatim: "\(first.name) · \(first.dDay)")
                .accessibilityLabel(Text(verbatim: "\(first.name), \(first.spokenDDay)"))
        } else {
            Text(emptyMessage(model))
        }
    }
}
