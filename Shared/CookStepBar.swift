import SwiftUI

/// 조리 단계 진행 막대 — 라이브 액티비티와 워치가 같은 한 벌을 쓴다.
/// 토글(`PaperToggle`)과 같은 문법: 빈 슬롯은 면 없이 `paperCut` 재단선, 채운 몫만 `blue` 면.
/// (`PaperToggle` 실측: 카드 위 `sub` 면 트랙은 라이트 1.18·다크 1.06으로 보이지 않았다.)
/// 외곽은 매끈한 캡슐이다 — 손으로 자른 `PaperRect`의 꼭짓점 지터는 30pt 토글에선 결로 읽히지만
/// 8pt 막대에선 양 끝을 화살촉처럼 뾰족하게 만들었다(시뮬레이터 캡처).
struct CookStepBar: View {
    /// 0…1 — 체크한 단계 수 / 전체 단계 수.
    let fraction: Double

    static let height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().strokeBorder(ReffiColor.paperCut, lineWidth: 1)
                Capsule()
                    .fill(ReffiColor.blue)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: Self.height)
        .accessibilityHidden(true)
    }
}
