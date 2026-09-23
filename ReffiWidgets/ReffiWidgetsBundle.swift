import CoreText
import SwiftUI
import WidgetKit

@main
struct ReffiWidgetsBundle: WidgetBundle {
    init() { HostAppFonts.register() }

    var body: some Widget {
        FridgeGlanceWidget()
        CookLiveActivity()
    }
}

/// 위젯 확장은 앱과 다른 프로세스라 앱이 `UIAppFonts`로 등록한 서체를 보지 못한다. 서체 파일을
/// 확장에 한 벌 더 넣으면 앱이 ~10MB 커지므로, 확장을 담은 앱 번들(`Reffi.app`)의 파일을 이 프로세스
/// 범위로 등록해 함께 쓴다. 등록에 실패하면 `.custom()`이 시스템 서체로 폴백한다(글자는 그대로 보인다).
enum HostAppFonts {
    static let files = ["OkDanDan-Bold.ttf", "Pretendard-Regular.otf", "Pretendard-Medium.otf",
                        "Pretendard-SemiBold.otf", "Pretendard-Bold.otf", "GoogleSansFlex-Regular.ttf"]

    private static let registration: Void = {
        // …/Reffi.app/PlugIns/ReffiWidgets.appex → …/Reffi.app
        let host = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        for file in files {
            CTFontManagerRegisterFontsForURL(host.appendingPathComponent(file) as CFURL, .process, nil)
        }
    }()

    static func register() { _ = registration }
}
