import Foundation

/// 앱 전역의 **유일한** D-day 표기 포맷터(§3.4) — 앱(`Ingredient.dDayText`)·위젯·워치가 전부 여기를 탄다.
/// 화면마다 다른 표기를 손으로 적으면 온보딩이 가르친 표기를 본 앱이 한 번도 쓰지 않는 일이 생긴다
/// (실제로 온보딩만 "D-2"였다). 앱 밖 표면으로 넓어져도 같은 이유로 한 벌만 둔다.
///
/// `bundle`은 앱 언어 선택을 따라야 하는 확장·워치가 `LanguageBundle`로 고른 번들을 넘길 때만 쓴다(기본 `.main`).
enum DDayLabel {
    /// `estimated`면 추정 기한 표시(≈)를 앞에 붙인다.
    static func text(daysLeft: Int, estimated: Bool = false, bundle: Bundle = .main) -> String {
        let label = switch daysLeft {
        case ..<0: String(localized: "Overdue", bundle: bundle, comment: "D-day label when past the use-by date")
        case 0:    String(localized: "Today", bundle: bundle, comment: "D-day label when expiring today")
        default:   String(localized: "\(daysLeft)d", bundle: bundle, comment: "D-day shorthand, e.g. 3d")
        }
        return (estimated ? "≈ " : "") + label
    }

    /// 남은 일수를 **소리로** 읽는 문구 — 화면 표기는 도장·배지 폭에 맞춘 축약이라
    /// 보조기술에는 그대로 쓸 수 없다("3d"는 문자 그대로 "삼디"로 읽히고, 영문 음성은 3D(입체)와 겹친다).
    /// 표기(`text`)와 **같은 쌍**이라 추정 표시도 같이 받는다 — 화면엔 "≈"가 있는데 소리로는 확정 기한처럼
    /// 들리면 냉동·개봉 재료에서 정보가 어긋난다.
    static func spoken(daysLeft: Int, estimated: Bool = false, bundle: Bundle = .main) -> String {
        let value = switch daysLeft {
        case ..<0: String(localized: "Past use-by date", bundle: bundle, comment: "Spoken D-day label when past the use-by date")
        case 0:    String(localized: "Expires today", bundle: bundle, comment: "Spoken D-day label when expiring today")
        default:   String(localized: "\(daysLeft) days left", bundle: bundle, comment: "Spoken D-day label, e.g. 3 days left")
        }
        return estimated ? String(localized: "Estimated: \(value)", bundle: bundle) : value
    }
}
