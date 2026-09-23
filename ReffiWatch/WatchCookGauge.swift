import SwiftUI

// MARK: - 조리 게이지 (§13.11 예외: 워치 파일 안에만 산다, DS 컴포넌트가 아니다)
//
// 워치 조리 1쪽은 진행 막대 대신 화면 바탕 전체가 게이지다(2026-09-23 오너 지시). 체크한 단계 비율만큼
// `blueLight` 물이 바닥에서 차오르고 손으로 자른 수면이 넘실댄다. 색·모션 토큰은 새로 없다
// (`blueLight`·`ReffiMotion.settle` 재사용). 새로 생긴 것은 아래 기하·속도 상수뿐이다.

/// 물결 치수·속도. 흐름 속도·넘실 주기는 전환 듀레이션이 아니라 주변 루프의 기하라 §7.1 표에 넣지 않는다.
enum WatchLiquid {
    struct Sheet {
        /// 파장 × 화면 폭 — 폭에 비례시켜 케이스 크기가 달라도 같은 모양으로 읽힌다.
        let wavelength: CGFloat
        /// 진폭(pt) — 크기와 무관하게 고정.
        let amplitude: CGFloat
        /// 흐름(pt/s, 음수 = 왼쪽).
        let drift: Double
        /// 넘실(위아래 ±pt)과 그 주기(s).
        let bob: CGFloat
        let bobPeriod: Double
        /// 앞 장 평균선보다 위로(pt).
        let rise: CGFloat
        let seed: Int
    }

    /// 앞 장: 파장 폭×0.62(46mm 129pt) · 진폭 5 · 왼쪽 12pt/s(30fps에서 0.4pt/프레임) · ±2pt 3.6s.
    static let near = Sheet(wavelength: 0.62, amplitude: 5, drift: -12, bob: 2, bobPeriod: 3.6, rise: 0, seed: 0)
    /// 뒤 장: 파장 폭×0.80 · 진폭 6 · 오른쪽 8pt/s · ±2.5pt 5.2s · 5pt 위. 반대로 흐르고 주기가 서로 나눠
    /// 떨어지지 않아 두 장 사이 띠가 부풀었다 가늘어진다(컨베이어가 아니라 넘실).
    static let far = Sheet(wavelength: 0.80, amplitude: 6, drift: 8, bob: 2.5, bobPeriod: 5.2, rise: 5, seed: 1)

    /// 0%: 평균선이 바닥 16pt 위 — 골도 9pt 위에 남아 빈 그릇에서도 수면이 보인다.
    static let floor = ReffiSpace.s4
    /// 100%: 평균선이 위 12pt — 가득 찬 뒤에도 시계 뒤에서 물결이 산다.
    static let brim = ReffiSpace.s3
    /// 도형 안에서 윗변 평균선의 위치 — 가장 큰 진폭(6) + 넘실(2.5)보다 크면 된다.
    static let headroom = ReffiSpace.s4
    static let farOpacity = 0.5
    /// 30fps 상한 — 12pt/s에서 0.4pt/프레임이면 매끈하고, 60Hz 대비 그리는 일이 반이다.
    static let frameInterval: TimeInterval = 1.0 / 30

    /// 평균 수면 y(게이지 자기 좌표, 위가 0). 46mm(높이 248)에서 232 − 220 × 비율.
    static func meanY(_ fraction: Double, height: CGFloat) -> CGFloat {
        (height - floor) - CGFloat(fraction) * (height - floor - brim)
    }
}

/// 화면 전체 물 게이지. 페이지 배경으로 깔려 시계 아래·둥근 모서리까지 닿는다(화면 모서리가 그릇).
/// 진행은 "Step N of M"이 글과 소리로 말하므로 게이지는 접근성에서 숨긴다.
struct WatchCookGauge: View {
    /// 0…1 — 체크한 단계 / 전체(라이브 액티비티 막대와 같은 값).
    let fraction: Double
    /// 이 페이지가 앞에 있는가 — 목록 페이지가 앞이면 멈춘다.
    let isFront: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isLuminanceReduced) private var dimmed
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// 멈춘 시각과 멈춰 있던 누적 시간. 물결 위상은 벽시계가 아니라 "돈 시간"으로 센다 — 벽시계로 세면
    /// 목록을 5초 보고 1쪽으로 돌아올 때 앞 장이 60pt 순간이동한다(멈춘 프레임 → 지금 위상).
    @State private var pausedAt: Date?
    @State private var pausedTotal: TimeInterval = 0

    /// 보이는 동안만 돈다: 모션 줄이기·Always On·저전력·비활성 장면·다른 페이지에서 멈춘다.
    private var still: Bool { reduceMotion || dimmed || lowPower || scenePhase != .active || !isFront }
    /// 수위만 스프링을 탄다(§7.5 settle). 모션 줄이기·Always On이면 즉시 바뀐다.
    private var levelAnimation: Animation? {
        ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion || dimmed)
    }

    var body: some View {
        GeometryReader { geo in
            // 크기가 정해지기 전 0 폭 레이아웃에선 파장이 0이 되어 위상 나눗셈이 NaN이 된다 — 그리지 않는다.
            if geo.size.width > 0, geo.size.height > 0 {
                waves(in: geo.size)
            }
        }
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: still, initial: true) { _, isStill in
            if isStill {
                if pausedAt == nil { pausedAt = .now }
            } else if let pausedAt {
                pausedTotal += Date.now.timeIntervalSince(pausedAt)
                self.pausedAt = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .receive(on: DispatchQueue.main)) { _ in   // 이 알림은 전역 큐에서 온다(헤더 주석)
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func waves(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: WatchLiquid.frameInterval, paused: still)) { timeline in
            // 멈춘 동안은 멈춘 시각에 고정하고, 다시 돌면 멈춰 있던 만큼 빼서 멈춘 프레임에서 이어 간다.
            // 재개 직후 onChange가 누적을 갱신하기 전 한 프레임도 멈춘 시각을 쓰게 `still`로 가르지 않는다.
            let clock = pausedAt ?? timeline.date
            // 모션 줄이기: 고정 위상으로 그린다(물결 모양은 남고 움직임만 없다, §7.4).
            let t = reduceMotion ? 0 : clock.timeIntervalSinceReferenceDate - pausedTotal
            ZStack(alignment: .topLeading) {
                // 뒤 장은 반투명이라 투명도 줄이기·Always On에서 걷는다(§13.2 손그림 반투명 규칙).
                if !dimmed && !reduceTransparency {
                    LiquidSheet(spec: WatchLiquid.far, size: size, fraction: fraction,
                                time: t, levelAnimation: levelAnimation)
                        .foregroundStyle(ReffiColor.blueLight.opacity(WatchLiquid.farOpacity))
                }
                LiquidSheet(spec: WatchLiquid.near, size: size, fraction: fraction,
                            time: t, levelAnimation: levelAnimation)
                    .foregroundStyle(ReffiColor.blueLight)
            }
        }
    }
}

/// 물 한 장. 도형은 크기마다 고정이고 매 프레임엔 offset만 바뀐다(§7 transform만).
private struct LiquidSheet: View {
    let spec: WatchLiquid.Sheet
    let size: CGSize
    let fraction: Double
    let time: TimeInterval
    let levelAnimation: Animation?

    var body: some View {
        let lambda = size.width * spec.wavelength
        let period = Double(lambda) * 2
        // arm64_32(Series 4~8)에선 CGFloat가 Float다. 기준일 이후 초(≈8e8)를 곱한 값은 Double에서
        // 한 주기 안으로 줄인 뒤에만 CGFloat로 넘긴다 — 아니면 위상이 계단처럼 튄다.
        let travel = (time * spec.drift).truncatingRemainder(dividingBy: period)
        let x = CGFloat(travel <= 0 ? travel : travel - period)          // (−P, 0]
        let cycle = (time / spec.bobPeriod).truncatingRemainder(dividingBy: 1)
        let swell = spec.bob * CGFloat(sin(2 * Double.pi * cycle))
        let mean = WatchLiquid.meanY(fraction, height: size.height) - spec.rise
        WaveEdge(wavelength: lambda, amplitude: spec.amplitude, seed: spec.seed)
            .frame(width: size.width + CGFloat(period), height: size.height + WatchLiquid.headroom)
            .offset(y: mean - WatchLiquid.headroom)
            .animation(levelAnimation, value: fraction)   // 수위 변화만 이 범위 안
            .offset(x: x, y: swell)                       // 흐름·넘실은 매 프레임, 애니메이션 범위 밖
            .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// 손으로 자른 수면 + 그 아래 면. 사인이 아니라 극점 네 개 표(높이·x 지터·핸들 길이)를 되풀이하는
/// 베지어라 물마루마다 기울기가 조금씩 다르고(§13.1 손으로 자른 종이), 표 한 바퀴(2λ)를 밀면 이음매 없이 돈다.
/// 윗변 평균선은 `rect.minY + headroom`이다.
private struct WaveEdge: Shape {
    let wavelength: CGFloat
    let amplitude: CGFloat
    let seed: Int

    private static let heights: [[CGFloat]] = [[1, 0.86, 0.80, 1], [0.90, 1, 1, 0.82]]
    private static let jitters: [[CGFloat]] = [[0, 0.05, -0.04, 0.03], [0, -0.04, 0.05, -0.02]]
    private static let handles: [[CGFloat]] = [[0.34, 0.40, 0.31, 0.38], [0.38, 0.32, 0.40, 0.33]]

    func path(in rect: CGRect) -> Path {
        guard wavelength > 0, rect.width > 0, rect.height > 0 else { return Path() }
        let s = seed % Self.heights.count
        let half = wavelength / 2
        let mean = rect.minY + WatchLiquid.headroom
        func k(_ i: Int) -> Int { (i % 4 + 4) % 4 }
        // 짝수 극점 = 물마루(위), 홀수 = 골(아래).
        func point(_ i: Int) -> CGPoint {
            CGPoint(x: rect.minX + CGFloat(i) * half + Self.jitters[s][k(i)] * wavelength,
                    y: mean + (k(i).isMultiple(of: 2) ? -1 : 1) * amplitude * Self.heights[s][k(i)])
        }
        let n = Int((rect.width / half).rounded(.up)) + 1
        var path = Path()
        path.move(to: CGPoint(x: point(-1).x, y: rect.maxY))
        path.addLine(to: point(-1))
        for i in 0...n {
            let a = point(i - 1), b = point(i)
            let run = b.x - a.x, h = Self.handles[s][k(i - 1)]
            // 극점에서 접선이 수평이라 이어진 마디가 꺾이지 않는다.
            path.addCurve(to: b,
                          control1: CGPoint(x: a.x + run * h, y: a.y),
                          control2: CGPoint(x: b.x - run * h, y: b.y))
        }
        path.addLine(to: CGPoint(x: point(n).x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
