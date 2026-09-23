import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

/// 리텐션 프롬프트(§14.9) — 앱이 사용자를 **다시 부를 수단**(아침 알림 · 홈 화면 위젯)을 가장 설득력
/// 있는 순간에 한 번씩 제안한다. 둘 다 설치당 한 번이고, 어느 쪽이든 "나중에"는 그대로 끝이다.
///
/// - **알림 제안** — 첫 재료 등록 직후. 재료가 생긴 순간이 "기한 전에 알려 준다"는 약속이 구체가 되는
///   순간이다(맥락 안에서 묻기 — Apple 알림 권한 문서가 첫 실행 요청보다 낫다고 적는 자리). 그림은 지금
///   재고로 스케줄러가 실제로 짤 첫 아침 알림(`AlertPreview`)이라 받게 될 날짜·시각·문구가 그대로다.
/// - **위젯 제안** — 사용 2일째(설치 당일 = 0일)부터, 홈 탭에서. 하루 쓰고 끝낸 사람이 아니라 다시 온
///   사람에게 묻는다. iOS에는 위젯을 대신 놓아 주는 API가 없어서 1차 행동은 "방법 보기"이고, 둘째 장이
///   Apple 지원 문서와 같은 말로 세 단계를 안내한다. 이미 위젯을 쓰는 사람에게는 묻지 않는다.
///
/// 카피 원칙(근거는 §14.9): 사실형 이득(죄책감·손실 압박 금지) · 빈도 약속(하루 한 번) · 거절의 자유를
/// 말로 명시("나중에" + "언제든 바꾸거나 끌 수 있어요") · 1차 버튼은 이득을 말하는 사용자의 대답이고
/// 권한 낱말("Allow")을 쓰지 않는다.
enum RetentionPrompt {
    /// 제안 단계 — 저장 키 값. 비어 있음 = 아직 때가 안 왔다.
    enum Stage: String {
        /// 조건은 섰고 보여 줄 틈을 기다린다(실행이 끊겨도 다음 실행에서 이어 묻는다).
        case pending
        /// 보여 줬거나 보여 줄 필요가 없다고 판정했다 — 다시 묻지 않는다.
        case done
    }

    enum Key {
        static let firstUseAt = "retention.firstUseAt"
        static let alertAsk = "retention.alertAsk"
        static let widgetAsk = "retention.widgetAsk"
    }

    /// 위젯 제안이 서는 사용 일수(설치 당일 = 0).
    static let widgetDay = 2

    /// 알림 제안을 띄울 수 있는가 — 시스템 권한을 아직 한 번도 묻지 않았고 앱 안 스위치도 꺼져 있을 때만.
    /// 거부·허용이 이미 정해졌으면 이 화면이 할 수 있는 일이 없다(거부는 시스템이 다시 묻지 않는다 —
    /// 그 길은 프로필 스위치의 설정 안내가 맡는다).
    static func canAskAlerts(authorization: UNAuthorizationStatus, alertsEnabled: Bool) -> Bool {
        authorization == .notDetermined && !alertsEnabled
    }

    /// 사용 일수 — 첫 사용일부터 **달력 날짜**(자정 경계)로 센다. 시각 차이로 세면 밤 11시에 설치한
    /// 사람이 이틀째 아침에도 "하루"가 된다.
    static func dayOfUse(firstUse: Date, now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: firstUse),
                                to: calendar.startOfDay(for: now)).day ?? 0
    }

    /// 위젯 제안을 띄울 수 있는가 — 사용 2일째부터, 위젯에 보여 줄 재료가 있고, 아직 위젯이 없을 때.
    /// 빈 위젯을 미리보기로 내밀면 무엇을 얻는지가 안 보인다.
    static func canOfferWidget(firstUse: Date, now: Date, hasUpcoming: Bool, widgetInstalled: Bool,
                               calendar: Calendar = .current) -> Bool {
        hasUpcoming && !widgetInstalled
            && dayOfUse(firstUse: firstUse, now: now, calendar: calendar) >= widgetDay
    }

    /// 첫 사용 시각 — 기록이 없을 때 한 번만 정한다. 이 기능 이전부터 쓰던 사람은 이력의 가장 이른 날이
    /// 오늘보다 앞선다(이력은 판정한 순간에만 생기므로 실제 사용보다 이를 수 없다). 재고의 구매일은
    /// 사용자가 과거로 적을 수 있어 쓰지 않는다.
    static func firstUse(now: Date, history: [RemovalLog]) -> Date {
        min(now, history.map(\.removedAt).min() ?? now)
    }

    /// 이 앱의 위젯이 홈 화면·잠금화면에 이미 있는가. WidgetKit의 이 조회는 최선 노력이라 조회가
    /// 실패하면 "없다"로 본다 — 제안은 설치당 한 번이라, 이미 쓰는 사람에게 한 번 더 묻는 쪽이
    /// 필요한 사람에게 영영 안 묻는 쪽보다 덜 틀린다.
    @MainActor
    static func widgetInstalled() async -> Bool {
        let configurations = (try? await WidgetCenter.shared.currentConfigurations()) ?? []
        return configurations.contains { $0.kind == FridgeGlanceWidget.kind }
    }
}

// MARK: - 알림 미리보기

/// 알림 제안의 그림 — 지금 재고로 **스케줄러가 실제로 짤 첫 아침 알림**(`ExpiryNotifier.plan`)이다.
/// 지어낸 예시가 아니라서 받게 될 날짜·시각·문구가 그대로다(추정 기한이면 알림도 포장 확인을 부탁한다).
struct AlertPreview: Equatable {
    let fireDate: Date
    let title: String
    let body: String

    /// 30일 창 안에 알림이 없으면(기한이 먼 재료뿐) 가장 이른 기한의 **전날 아침** 알림이다 — 창에
    /// 들어오는 날 스케줄러가 짤 것과 같은 문구다. 재료가 없거나 그날이 이미 지났으면 nil(그림 없이
    /// 문구만 선다).
    static func make(for items: [Ingredient], now: Date, hour: Int,
                     calendar: Calendar = .current) -> AlertPreview? {
        if let first = ExpiryNotifier.plan(for: items, now: now, hour: hour).first {
            return AlertPreview(fireDate: first.fireDate, title: first.title, body: first.body)
        }
        guard let soonest = items.map(\.effectiveExpiresAt).min(),
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: soonest)),
              let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayBefore),
              fireDate > now else { return nil }
        let due = items.filter { calendar.isDate($0.effectiveExpiresAt, inSameDayAs: soonest) }
        let message = ExpiryNotifier.message(today: [], tomorrow: due, pastDue: [])
        return AlertPreview(fireDate: fireDate, title: message.title, body: message.body)
    }
}

/// 알림 한 장을 앱 안에 그린 것 — 잠금화면에 도착할 배너와 같은 배치(앱 아이콘 · 제목 · 시각 · 본문).
/// 앱 밖 표면의 그림이라 바깥 모양은 **시스템 컨테이너**(매끈한 둥근 사각, 손으로 자른 외곽 없음)를
/// 따른다(§13.11). 면은 종이 카드 위의 `subRaised`(§2.8 — 카드 위에서 `sub`는 다크에서 사라진다).
struct AlertPreviewCard: View {
    let preview: AlertPreview
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: ReffiSpace.s3) {
            if let icon = AppIcon.image {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: Metrics.icon, height: Metrics.icon)
                    .clipShape(RoundedRectangle(cornerRadius: ReffiRadius.sm, style: .continuous))
            }
            VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                    Text(verbatim: preview.title)
                        .reffiType(.badgeLabel)
                        .foregroundStyle(ReffiColor.ink)
                        .lineLimit(1)
                    Spacer(minLength: ReffiSpace.s2)
                    Text(verbatim: time)
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                        .fixedSize()
                }
                Text(verbatim: preview.body)
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ReffiSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: ReffiRadius.lg, style: .continuous)
            .fill(ReffiColor.subRaised))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview of your first alert"))
        .accessibilityValue(Text(verbatim: "\(time). \(preview.title). \(preview.body)"))
        .accessibilityIdentifier("retention.alertPreview")
    }

    /// 요일 + 시각("Thu 9:00 AM" · "(목) 오전 9:00") — 날짜까지 쓰면 한 줄에 제목이 설 자리가 없다.
    /// 첫 알림은 길어야 한 달 안이라 요일로 충분하다.
    private var time: String {
        preview.fireDate.formatted(Date.FormatStyle(locale: locale).weekday(.abbreviated).hour().minute())
    }

    private enum Metrics {
        /// 잠금화면 알림의 앱 아이콘 크기(≈38)에 가까운 값 — 카드 폭이 좁아 한 단 줄였다.
        static let icon: CGFloat = 36
    }
}

/// 앱 아이콘 — 알림 배너 왼쪽에 서는 그 그림. 번들 Info.plist의 기본 아이콘 파일에서 읽는다(에셋
/// 카탈로그의 단일 크기 아이콘이 빌드 때 `AppIcon60x60`으로 풀린다). 못 찾으면 자리를 비운다.
@MainActor
private enum AppIcon {
    static let image: UIImage? = {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }()
}

// MARK: - 위젯 미리보기

/// 위젯 제안의 그림 — 홈 화면 한 칸(`subRaised` 판) 위에 **실제 위젯 뷰**(`GlanceWidgetPreview`)를 놓는다.
/// 위젯도 종이 면이라 카드(`paper`) 위에 바로 두면 경계가 사라진다 — 판이 홈 화면 자리를 말한다.
private struct WidgetPreviewFigure: View {
    let snapshot: GlanceSnapshot

    var body: some View {
        GlanceWidgetPreview(snapshot: snapshot, date: .now)
            .padding(.vertical, ReffiSpace.s4)
            // §9.4 ③ 글자가 아닌 요소 — 부모(좌측 축)는 두고 이 그림만 스스로 가운데에 선다.
            .frame(maxWidth: .infinity, alignment: .center)
            .background(RoundedRectangle(cornerRadius: ReffiRadius.lg, style: .continuous)
                .fill(ReffiColor.subRaised))
            .accessibilityIdentifier("retention.widgetPreview")
    }
}

// MARK: - 위젯 추가 세 단계

/// 위젯 추가 세 단계 — 종이컷 번호 칩 + 그 옆에 맞춘 문장(2026-09-23 오너 지시). 행은 레시피 전표의
/// 단계 행(`KitchenCopySheet.stepRow`)과 같은 문법이다: 왼쪽에 종이 조각, 문장은 그 오른쪽 열에서 시작해
/// 둘째 줄도 같은 열로 떨어진다. 문구는 Apple 지원 문서의 동작·버튼 이름 그대로다(iOS 18 · 26 공통 경로).
///
/// 뜻을 싣는 본문이라 접근성 글자 크기에서도 걷히지 않는다(`PaperDialog.detail`) — 대신 높이 예산을
/// 스스로 진다: 실측 높이와 상한 중 작은 값 + 넘치면 자체 스크롤(`PaperChecklistDialog.list`와 같은 처방).
private struct WidgetStepsList: View {
    /// 행 사이 — 한 단계가 두 줄로 접혀도 다음 번호가 앞 문장의 꼬리로 읽히지 않는 간격(오너 지시로 넓힘).
    private static let rowGap = ReffiSpace.s4
    /// 목록 높이 상한 — 이 카드엔 스크롤이 없어서(§14.7) 큰 글자에서 목록이 버튼을 화면 밖으로 밀지 않게.
    private static let maxHeight: CGFloat = 320

    @State private var height: CGFloat = 0

    /// `Text("…")` 리터럴로 두는 이유: 카탈로그 검사(`scripts/check-strings.py`)가 이 호출 형태를 잡는다.
    private var steps: [Text] {
        [Text("Touch and hold the Home Screen background until the apps jiggle."),
         Text("Tap **Edit** at the top, then **Add Widget**."),
         Text("Search for **Reffi**, pick a size, then tap **Add Widget**.")]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.rowGap) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s3) {
                        StepNumber(number: index + 1)
                        step
                            .reffiType(.body)
                            .foregroundStyle(ReffiColor.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    // 번호와 문장을 한 번에 읽는다("1, 앱이 흔들릴 때까지…").
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("retention.widgetStep")
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)   // 다 들어가면 바운스도 없다(스크롤 아닌 척)
        .frame(height: min(height > 0 ? height : Self.maxHeight, Self.maxHeight))
    }
}

/// 단계 번호 — 종이컷 칩(`PaperChipCut`: 정사각에 가까운 소형 칩의 정본 윤곽, §13.1). 면은 `blueLight`,
/// 숫자는 `blueDark`(§3.4 숫자 서체) — **파랑 솔리드는 이 카드의 1차 버튼 하나뿐이어야 한다**(§2.4):
/// 번호 셋까지 채우면 버튼과 무게를 겨룬다. 대비 실측 `blueDark`/`blueLight` 라이트 7.46 · 다크 6.37.
/// 크기는 본문 글자를 따라 커진다(`ScaledMetric`) — 큰 글자에서 숫자가 칩 밖으로 넘치지 않게.
private struct StepNumber: View {
    let number: Int
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 28

    var body: some View {
        Text(number, format: .number)
            .font(.reffiNum(.body))
            .foregroundStyle(ReffiColor.blueDark)
            .frame(width: side, height: side)
            .background {
                let shape = PaperChipCut(seed: number &* 7)
                shape.fill(ReffiColor.blueLight)
                    .overlay(PaperGrain(seed: UInt64(number) &+ 41, strength: 0.6).clipShape(shape))
                    .paperEdge(shape, tint: ReffiColor.paperEdgeAccent(ReffiColor.blueDark))
            }
    }
}

// MARK: - 호스트

/// 두 제안을 루트(`RootTabView`)에 얹는다 — 캡슐 네비까지 덮는 자리라야 모달이 온전하다(§14.7).
///
/// **언제 띄우나.** 시트·커버가 떠 있는 동안은 기다린다(`PresentationGate`) — 첫 등록은 추가 시트 안의
/// 저장에서 일어나므로 시트가 내려가고, 방금 넣은 재료가 더미로 떨어져 앉은 뒤(`alertSettle`)에 묻는다.
/// 한 실행에 제안은 하나뿐이다. 앱이 뒤로 가거나 탭이 바뀌면 기다리던 시도는 거둔다(단계는 그대로라
/// 다음 활성화에서 다시 본다).
struct RetentionPromptHost: ViewModifier {
    /// 홈 탭이 보이는가 — 위젯 제안은 홈에서만 선다(냉장고 편집·프로필 설정 중에 끼어들지 않게).
    let homeVisible: Bool

    @Environment(FridgeStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @AppStorage(ExpiryNotifier.enabledKey) private var alertsEnabled = false
    @AppStorage(ExpiryNotifier.hourKey) private var alertHour = ExpiryNotifier.defaultHour
    /// 홈 알림 배너(`MainView`)의 "제안했음" 키 — 이 다이얼로그가 질문을 맡는 순간 배너를 물린다.
    @AppStorage("expiryAlertPromptSeen") private var alertBannerSeen = false
    @AppStorage(RetentionPrompt.Key.alertAsk) private var alertAsk = ""
    @AppStorage(RetentionPrompt.Key.widgetAsk) private var widgetAsk = ""
    @AppStorage(RetentionPrompt.Key.firstUseAt) private var firstUseAt: Double = 0

    private enum Showing { case alerts, widget, widgetSteps }
    @State private var showing: Showing?
    @State private var alertPreview: AlertPreview?
    @State private var widgetSnapshot: GlanceSnapshot?
    /// 이번 실행에서 이미 하나를 물었다 — 한 실행에 제안은 하나만.
    @State private var askedThisRun = false
    @State private var attempt: Task<Void, Never>?

    /// 추가 시트가 내려간 뒤, 방금 넣은 재료가 화면 위 바깥에서 떨어져 더미에 앉기까지의 여유 —
    /// 받은 것을 보고 나서 묻는다. 0.9초에서는 재료가 아직 떨어지는 중에 딤이 깔렸다(UI 테스트 캡처).
    private static let alertSettle: Duration = .milliseconds(1600)
    /// 앱을 연 직후 스플래시가 빠지고 홈이 자리 잡을 때까지의 여유 — 여는 순간 모달이 가로막지 않게.
    private static let widgetSettle: Duration = .milliseconds(1200)

    func body(content: Content) -> some View {
        content
            // 세 장 모두 글이 가운데에 선다(§14.9, 2026-09-23 오너 지시) — 그림·단계 목록이 축을 세우는
            // 표지형 다이얼로그라서다(§9.4 ②). 두 문장짜리 메시지는 문장마다 줄을 연다(가운데 정렬에서
            // 한 문장이 두 줄에 걸쳐 흔들리지 않게 — xcstrings en 키와 ko 값 양쪽, §9.4).
            .paperDialog(isPresented: presented(.alerts),
                         title: "Want a heads-up before food turns?",
                         message: "One alert at \(alertTime), only on days something is near its use-by date.\nYou can change or turn it off anytime in Profile.",
                         seed: 7,
                         centered: true,
                         backdropDismisses: true,
                         primary: PaperDialogAction("Remind me") { acceptAlerts() },
                         secondary: PaperDialogAction("Not now") {}) {
                if let alertPreview { AlertPreviewCard(preview: alertPreview) }
            }
            .paperDialog(isPresented: presented(.widget),
                         title: "Keep what to use first on your Home Screen?",
                         message: "It updates with your fridge, so you can check at a glance without opening the app.",
                         seed: 11,
                         centered: true,
                         backdropDismisses: true,
                         primary: PaperDialogAction("See how") { showing = .widgetSteps },
                         secondary: PaperDialogAction("Not now") {}) {
                if let widgetSnapshot { WidgetPreviewFigure(snapshot: widgetSnapshot) }
            }
            // 둘째 장 — 알림형(행동 하나)이라 딤 탭은 무시한다(§14.7). 단계는 본문 슬롯의 번호 목록이다.
            .paperDialog(isPresented: presented(.widgetSteps),
                         title: "Add it in 3 steps",
                         seed: 13,
                         centered: true,
                         primary: PaperDialogAction("Got it") {},
                         figure: { EmptyView() },
                         detail: { WidgetStepsList() })
            .onAppear {
                #if DEBUG
                resetForUITestsIfNeeded()
                #endif
                if firstUseAt == 0 {
                    firstUseAt = RetentionPrompt.firstUse(now: .now, history: store.history).timeIntervalSince1970
                }
                #if DEBUG
                if previewFromLaunchArguments() { return }
                #endif
                resume()
            }
            .onChange(of: store.firstRegisteredAt) { _, registered in
                guard !Self.suppressed, registered != nil, alertAsk.isEmpty else { return }
                alertAsk = RetentionPrompt.Stage.pending.rawValue
                alertBannerSeen = true   // 이 다이얼로그가 질문을 맡는다 — 배너는 다시 묻지 않는다
                start { await askForAlerts() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { resume() } else { cancelAttempt() }
            }
            .onChange(of: homeVisible) { _, _ in
                cancelAttempt()
                resume()
            }
    }

    // MARK: 흐름

    /// 기다리던 제안을 이어 간다 — 알림이 먼저다(첫 등록을 마친 사람에게 이미 예약된 질문이다).
    private func resume() {
        guard !Self.suppressed, scenePhase == .active, showing == nil, !askedThisRun else { return }
        if alertAsk == RetentionPrompt.Stage.pending.rawValue {
            start { await askForAlerts() }
        } else if widgetAsk.isEmpty, homeVisible, widgetIsDue(now: .now) {
            start { await offerWidget() }
        }
    }

    private func askForAlerts() async {
        guard await PresentationGate.waitUntilClear(settle: Self.alertSettle),
              alertAsk == RetentionPrompt.Stage.pending.rawValue else { return }
        let status = await notificationStatus()
        guard !Task.isCancelled, showing == nil else { return }
        alertAsk = RetentionPrompt.Stage.done.rawValue
        alertBannerSeen = true
        guard RetentionPrompt.canAskAlerts(authorization: status, alertsEnabled: alertsEnabled) else { return }
        alertPreview = AlertPreview.make(for: store.available, now: .now, hour: alertHour)
        askedThisRun = true
        showing = .alerts
    }

    /// 알림 받기 — 시스템 권한 요청 후 허락되면 스위치를 켜고 바로 스케줄한다(프로필 스위치와 같은 배선).
    /// 거부하면 아무것도 더 묻지 않는다 — 켜는 길은 프로필에 늘 있다.
    private func acceptAlerts() {
        Task {
            guard await ExpiryNotifier.requestAuthorization() else { return }
            alertsEnabled = true
            ExpiryNotifier.reschedule(for: store.available)
            Analytics.shared.track(.alertsToggled(on: true, hour: alertHour))
        }
    }

    /// 싼 조건 먼저(날짜·재고) — 아직 때가 아니면 게이트를 돌리지 않는다.
    private func widgetIsDue(now: Date) -> Bool {
        RetentionPrompt.canOfferWidget(firstUse: Date(timeIntervalSince1970: firstUseAt), now: now,
                                       hasUpcoming: store.available.contains { $0.effectiveDaysLeft >= 0 },
                                       widgetInstalled: false)
    }

    /// 위젯 제안은 특정 순간에 묶인 질문이 아니라서 기다리지 않는다 — 앱을 연 뒤 홈이 조용할 때만 묻고,
    /// 사용자가 벌써 무언가를 열었으면(추천 덱·추가 시트) 이번 실행은 넘긴다. 기다렸다 묻으면 덱을 닫고
    /// 돌아오는 순간에 끼어든다.
    private func offerWidget() async {
        guard await PresentationGate.staysClear(for: Self.widgetSettle) else { return }
        // 개봉 확인이 이번 실행에 뜰 차례면 양보한다 — 그 다이얼로그는 홈이 띄우는 오버레이라
        // 게이트가 보지 못하고, 두 장이 겹치면 둘 다 반쯤 읽힌다.
        guard homeVisible, widgetAsk.isEmpty, store.sealedCheckDue.isEmpty, widgetIsDue(now: .now) else { return }
        let installed = await RetentionPrompt.widgetInstalled()
        guard !Task.isCancelled, showing == nil else { return }
        widgetAsk = RetentionPrompt.Stage.done.rawValue
        guard !installed else { return }
        widgetSnapshot = GlancePublisher.snapshot(of: store)
        askedThisRun = true
        showing = .widget
    }

    private func notificationStatus() async -> UNAuthorizationStatus {
        #if DEBUG
        // 라이브 UI 테스트 — 시뮬레이터의 알림 권한은 테스트가 되돌릴 수 없어 '아직 안 물음'으로 본다.
        if Self.isLive { return .notDetermined }
        #endif
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: 보조

    /// 알림 시각("9:00 AM" · "오전 9:00") — 앱 언어의 로케일로 찍는다. 기기 로케일로 찍으면 앱 언어만
    /// 한국어로 바꾼 사람에게 "9:00 AM에 한 번 보내요"처럼 한 문장 안에서 언어가 섞인다.
    private var alertTime: String {
        let date = Calendar.current.date(bySettingHour: alertHour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }

    private func start(_ work: @escaping @MainActor () async -> Void) {
        attempt?.cancel()
        attempt = Task { await work() }
    }

    private func cancelAttempt() {
        attempt?.cancel()
        attempt = nil
    }

    /// 한 장씩만 선다 — 버튼이 먼저 내리고(`isPresented = false`) 행동하므로, "방법 보기"가 둘째 장을
    /// 올리는 것은 같은 업데이트 안의 교대다(§14.7).
    private func presented(_ kind: Showing) -> Binding<Bool> {
        Binding(get: { showing == kind },
                set: { if !$0, showing == kind { showing = nil } })
    }

    #if DEBUG
    /// UI 테스트·QA 하네스(런치 인자)에서는 제안을 끈다 — 시뮬레이터에 남은 첫 사용일·권한 상태가
    /// 실행마다 달라, 제안과 무관한 테스트의 아무 화면에나 다이얼로그가 끼어든다. 켜는 길은 둘이다:
    /// `-retention.live`(실제 조건 · 권한은 '아직 안 물음'으로 간주) ·
    /// `-retention.alerts`/`-retention.widget`/`-retention.widgetSteps`(조건 없이 바로 한 장).
    private static let harnessArguments = ["-skipAuth", "-skipOnboarding", "-onboarding.done",
                                           "-resetOnboarding", "-uiTestEmptyFridge", "-uiTestSampleFridge"]
    private static var isLive: Bool { ProcessInfo.processInfo.arguments.contains("-retention.live") }
    private static var suppressed: Bool {
        !isLive && harnessArguments.contains(where: ProcessInfo.processInfo.arguments.contains)
    }

    /// 데이터를 되돌리는 테스트 인자는 제안 단계도 새 설치처럼 되돌린다 — 앞 실행이 남긴 단계가
    /// 다음 실행의 흐름을 바꾸지 않게.
    private func resetForUITestsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTestEmptyFridge") || args.contains("-uiTestSampleFridge") else { return }
        alertAsk = ""
        widgetAsk = ""
        firstUseAt = Date.now.timeIntervalSince1970
    }

    /// QA·스크린샷용 — 조건과 무관하게 한 장을 바로 띄운다(RUN.md "QA 런치 인자").
    /// 데이터는 그때의 재고다(`-uiTestSampleFridge`와 함께 쓰면 샘플 재고의 실제 첫 알림·위젯) —
    /// 루트의 샘플 시드도 `onAppear`에서 돌아서, 한 박자 뒤에 읽어야 시드가 끝난 재고를 본다.
    private func previewFromLaunchArguments() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        let kind: Showing
        if args.contains("-retention.alerts") { kind = .alerts }
        else if args.contains("-retention.widgetSteps") { kind = .widgetSteps }
        else if args.contains("-retention.widget") { kind = .widget }
        else { return false }
        start {
            try? await Task.sleep(for: .milliseconds(400))
            alertPreview = AlertPreview.make(for: store.available, now: .now, hour: alertHour)
            widgetSnapshot = GlancePublisher.snapshot(of: store)
            showing = kind
        }
        return true
    }
    #else
    private static let suppressed = false
    #endif
}

extension View {
    /// 리텐션 프롬프트(알림 · 위젯 제안)를 얹는다 — 루트 한 곳에서만 쓴다.
    func retentionPrompts(homeVisible: Bool) -> some View {
        modifier(RetentionPromptHost(homeVisible: homeVisible))
    }
}

// MARK: - 프레젠테이션 게이트

/// 지금 시트·풀스크린 커버가 떠 있는가 — SwiftUI의 `.sheet`·`.fullScreenCover`는 키 윈도의 루트
/// 컨트롤러 위에 UIKit 프레젠테이션으로 선다. SwiftUI는 "모든 프레젠테이션이 걷혔다"는 사건을 주지
/// 않아서 짧은 간격으로 확인한다(제안이 기다리는 동안에만 돌고, 설치당 두 번이 전부다).
/// 앱 안 오버레이 다이얼로그(종이 다이얼로그)는 여기 안 잡힌다 — 호출부가 각자 양보 조건을 둔다.
@MainActor
enum PresentationGate {
    static var isClear: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .filter(\.isKeyWindow)
            .allSatisfy { $0.rootViewController?.presentedViewController == nil }
    }

    /// 지금 비어 있고 `settle` 뒤에도 비어 있는가 — 기다리지 않는 쪽(위젯 제안).
    static func staysClear(for settle: Duration) async -> Bool {
        guard isClear else { return false }
        try? await Task.sleep(for: settle)
        return !Task.isCancelled && isClear
    }

    /// 걷힐 때까지 기다리고, 걷힌 뒤 `settle`만큼 더 두고 한 번 더 본다(그 사이 새로 뜬 시트를 가리지
    /// 않게). 취소되거나 `timeout` 안에 안 걷히면 false — 단계는 그대로라 다음 활성화에서 다시 시도한다.
    static func waitUntilClear(settle: Duration, timeout: Duration = .seconds(30)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if Task.isCancelled { return false }
            if isClear {
                try? await Task.sleep(for: settle)
                if Task.isCancelled { return false }
                if isClear { return true }
            } else {
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        return false
    }
}
