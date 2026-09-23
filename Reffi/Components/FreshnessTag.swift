import SwiftUI

/// 신선도 표식 — 인디케이터 바 + 남은 기간(D-N)을 한 묶음으로(§13.5 `IngredientBadge`의 좌측 그룹).
/// 색은 신선도 dark(§2.6 — 면 위 색-as-텍스트는 dark), 글자는 늘 함께(§1 색 단독 금지).
/// 메인 배지와 앱 밖 표면(홈·위젯·워치)이 같은 한 벌을 쓴다 — 표면마다 점·바·도장을 따로 고르면
/// 같은 재료가 화면마다 다른 문법으로 읽힌다.
struct FreshnessTag: View {
    let freshness: Freshness
    /// `DDayLabel.text` 결과(추정이면 ≈ 포함).
    let text: String

    var body: some View {
        HStack(spacing: ReffiSpace.s1) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(freshness.dark)
                .frame(width: 4, height: 14)
            Text(verbatim: text)
                // D-day는 ko에서 "오늘"·"3일"로 흐른다 — 한글 폴백 오버로드(§3.4·42차).
                .font(.reffiNum(.meta, for: text))
                .foregroundStyle(freshness.dark)
        }
    }
}
