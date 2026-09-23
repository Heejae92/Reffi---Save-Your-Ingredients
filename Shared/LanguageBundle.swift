import Foundation

/// 앱 언어 선택(`AppLanguage` raw: "en"/"ko")에 맞는 문자열 번들 — 앱(`AppLanguage.localizedNow`)과
/// 앱 밖 표면(위젯·워치)이 같은 규칙으로 조회한다. `String(localized:)`는 `Bundle.main`(다음 실행 기준)에
/// 굳지만, 그 언어의 `.lproj`를 직접 지정하면 곧바로 그 언어로 리졸브된다.
/// nil이거나 번들을 못 찾으면 `.main`(기기 언어)으로 폴백한다.
enum LanguageBundle {
    static func bundle(for language: String?) -> Bundle {
        guard let language, let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
