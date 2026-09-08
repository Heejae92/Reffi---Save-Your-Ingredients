import SwiftUI

/// 재료 일러스트(§13.3): 넓고 비대칭인 색면을 겹치는 컷페이퍼.
/// 외곽은 손으로 자른 윤곽이고, 명암은 껍질·단면·접힌 잎 등 실제 구조를 따라간다.
/// 아웃라인 없이 종이 겹침과 잎맥·씨앗으로 재료를 구별한다. 색은 재료의 자연색을 유지한다.
/// 다만 **신선도에 따라 시든다**: 자연색 위에 채도·명도 감쇠(색행렬 1장)와 재질별 처짐·퍼짐·
/// 꼭짓점 라운딩을 얹는다(`WiltStyle`). 강도는 `fresh` 하나에서 파생한다 — 호출부가 따로
/// 플래그를 켤 필요가 없어(= 켜는 걸 잊을 수도 없어) 모든 표시 지점이 자동으로 따라온다.
struct PaperSilhouette: View {
    let glyph: FoodGlyph
    let fresh: Freshness   // 시듦(WiltStyle) 강도 — 색조는 그대로, 채도·명도·자세만 바뀐다
    /// false면 외곽 그림자 필터를 끈다 — 물리 바디용 텍스처는 알파 임계로 모양을 뜨므로
    /// 그림자가 실제 글리프보다 큰 충돌체를 만든다(재료 사이 빈틈). 표시용은 기본값 그대로.
    let shadowed: Bool

    /// 이번 렌더의 시듦 — **저장 프로퍼티**다. `look`은 `poly()`가 면(面)마다 읽으므로
    /// computed로 두면 글리프 하나 그리는 데 수십 번 재계산된다(리스트 행처럼 매 프레임 그리는
    /// SwiftUI 표면에서 특히 비싸다). 생성 시 한 번만 뽑아 둔다.
    private let wilt: WiltStyle
    /// 이번 렌더에 적용할 형태 처리 — 신선하거나 용기류면 nil(좌표계·패스 모두 원본 그대로).
    private let look: WiltStyle.Shape?

    init(glyph: FoodGlyph, fresh: Freshness, shadowed: Bool = true) {
        self.glyph = glyph
        self.fresh = fresh
        self.shadowed = shadowed
        let w = WiltStyle.for(fresh)
        self.wilt = w
        self.look = w.stagedShape(for: glyph)
    }

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.1, dy: size.height * 0.1)
            // 처짐·퍼짐 — 그림자까지 같이 기울도록 그리기 **전에** 좌표계를 접는다.
            // 형태 변환은 여기 한 번뿐이다(라운딩은 패스 단계라 겹치지 않는다).
            if let look {
                // 바닥 앵커(밑변 가운데) — 밑동은 제자리에 두고 윗부분만 숙게 한다.
                // 세로로 눌린 만큼 가로로 아주 살짝 퍼져 "물러서 주저앉은" 인상이 된다.
                ctx.translateBy(x: r.midX, y: r.maxY)
                ctx.rotate(by: .degrees(look.tilt))
                ctx.scaleBy(x: look.spread, y: look.squash)
                ctx.translateBy(x: -r.midX, y: -r.maxY)
            }
            // 배경 분리 — 실루엣 전체를 한 겹으로 합성해 **단일 외곽 그림자**를 준다.
            // 흰색 계열(달걀·버섯 기둥·우유)이 크림 배경에 묻히지 않게 가장자리에 옅은 헤일로.
            var shaded = ctx
            if shadowed {
                shaded.addFilter(.shadow(color: .black.opacity(0.16),
                                         radius: size.width * 0.018, x: 0, y: size.height * 0.015))
            }
            // 색 바램 — **필터 한 장**(hue를 안 건드리는 선형 색행렬 = 채도×명도)만 얹는다.
            // 채도 필터 + 누런 워시를 겹치면 파랑 계열(버터 포일·생선 몸통)이 올리브로 밀려
            // 재료 정체성이 무너진다. 색행렬은 구조적으로 그럴 수 없다.
            if !wilt.isIdentity {
                shaded.addFilter(.colorMatrix(wilt.colorMatrix))
            }
            shaded.drawLayer { layer in
                draw(glyph, in: r, ctx: &layer)
                FoodPaperGrain.overlay(in: r, context: &layer)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Palette (자연색 · 넓은 색면과 종이 겹침)
    private enum C {
        /// 눈·패싯 디테일용 고정 잉크 — 일러스트는 물성(잘라 붙인 종이)이라 다크에서도 재채색하지 않는다.
        /// 적응형 `ReffiColor.ink`를 쓰면 다크에서 크림으로 뒤집혀 실루엣이 망가진다.
        static let inkFixed = ReffiColor.oklch(0.25, 0.012, 80)
        // 초록 계열(잎·줄기·봉오리)
        static let dGreen  = ReffiColor.oklch(0.43, 0.11, 150)
        static let mGreen  = ReffiColor.oklch(0.55, 0.13, 148)
        static let lGreen  = ReffiColor.oklch(0.78, 0.13, 142)
        static let leafHi  = ReffiColor.oklch(0.70, 0.13, 145)
        // 당근·오렌지
        static let carrot  = ReffiColor.oklch(0.70, 0.16, 56)
        static let carrotSh = ReffiColor.oklch(0.60, 0.15, 52)
        static let carrotHi = ReffiColor.oklch(0.79, 0.14, 64)
        // 토마토·빨강
        static let tomato  = ReffiColor.oklch(0.62, 0.18, 32)
        static let tomatoSh = ReffiColor.oklch(0.53, 0.17, 30)
        static let tomatoHi = ReffiColor.oklch(0.71, 0.15, 40)
        // 노랑(레몬·파프리카·옥수수)
        static let yellow  = ReffiColor.oklch(0.85, 0.15, 96)
        static let yellowSh = ReffiColor.oklch(0.77, 0.15, 92)
        static let yellowHi = ReffiColor.oklch(0.91, 0.11, 100)
        // 크림·베이지·갈색
        static let cream   = ReffiColor.oklch(0.95, 0.012, 90)
        static let creamLo = ReffiColor.oklch(0.90, 0.02, 80)
        static let creamHi = ReffiColor.oklch(0.98, 0.008, 90)
        static let onion   = ReffiColor.oklch(0.93, 0.022, 70)
        static let onionSh = ReffiColor.oklch(0.85, 0.03, 66)
        static let tan     = ReffiColor.oklch(0.74, 0.05, 64)
        static let tanSh   = ReffiColor.oklch(0.64, 0.055, 60)
        static let tanDk   = ReffiColor.oklch(0.5, 0.055, 58)
        static let brown   = ReffiColor.oklch(0.44, 0.06, 60)
        // 오프컬러 액센트
        static let purple  = ReffiColor.oklch(0.46, 0.10, 330)
        static let pink    = ReffiColor.oklch(0.72, 0.16, 350)
        // 과일
        static let apple   = ReffiColor.oklch(0.60, 0.17, 30)
        static let appleSh = ReffiColor.oklch(0.51, 0.16, 28)
        static let appleHi = ReffiColor.oklch(0.70, 0.15, 36)
        static let berry   = ReffiColor.oklch(0.60, 0.18, 25)
        static let berrySh = ReffiColor.oklch(0.51, 0.17, 24)
        // 단백질
        static let meat    = ReffiColor.oklch(0.54, 0.14, 22)
        static let meatSh  = ReffiColor.oklch(0.46, 0.13, 20)
        static let fat     = ReffiColor.oklch(0.91, 0.025, 48)
        static let poultry = ReffiColor.oklch(0.78, 0.07, 62)
        static let poultrySh = ReffiColor.oklch(0.68, 0.08, 58)
        static let fish    = ReffiColor.oklch(0.64, 0.07, 240)
        static let fishDk  = ReffiColor.oklch(0.5, 0.08, 244)
        static let fishHi  = ReffiColor.oklch(0.74, 0.06, 238)
        static let shrimp  = ReffiColor.oklch(0.72, 0.15, 38)
        static let shrimpSh = ReffiColor.oklch(0.63, 0.15, 36)
        // 유제품
        static let milkLbl = ReffiColor.oklch(0.55, 0.13, 250)
        static let cheese  = ReffiColor.oklch(0.83, 0.13, 92)
        static let cheeseHl = ReffiColor.oklch(0.72, 0.12, 90)
        // 빵
        static let bread   = ReffiColor.oklch(0.76, 0.07, 66)
        static let breadSh = ReffiColor.oklch(0.68, 0.07, 62)
        static let crust   = ReffiColor.oklch(0.6, 0.08, 56)
        static let neutral = ReffiColor.oklch(0.8, 0.03, 80)
        static let neutralSh = ReffiColor.oklch(0.72, 0.03, 80)
        // 과육·곡류·저장식품
        static let flesh   = ReffiColor.oklch(0.90, 0.05, 138)   // 오이 단면 속살
        static let avoFlesh = ReffiColor.oklch(0.86, 0.10, 110)  // 아보카도 과육(황록)
        static let avoRim  = ReffiColor.oklch(0.74, 0.12, 128)   // 과육 테두리 초록
        static let avoSkin = ReffiColor.oklch(0.36, 0.07, 148)   // 아보카도 껍질(짙은 녹)
        static let pit     = ReffiColor.oklch(0.50, 0.075, 58)   // 씨(밤색)
        static let banana  = ReffiColor.oklch(0.84, 0.15, 92)
        static let bananaSh = ReffiColor.oklch(0.75, 0.14, 88)
        static let bananaTip = ReffiColor.oklch(0.42, 0.06, 64)
        static let bowlB   = ReffiColor.oklch(0.72, 0.06, 246)   // 국수 그릇(도기 블루)
        static let bowlBHi = ReffiColor.oklch(0.81, 0.05, 248)
        static let noodle  = ReffiColor.oklch(0.86, 0.10, 86)    // 면 가닥(밀색)
        static let noodleSh = ReffiColor.oklch(0.78, 0.11, 84)
        static let rice    = ReffiColor.oklch(0.965, 0.006, 96)  // 흰 밥
        static let riceSh  = ReffiColor.oklch(0.90, 0.01, 90)
        static let bottle  = ReffiColor.oklch(0.40, 0.055, 44)   // 소스병(간장/굴소스 갈색)
        static let bottleHi = ReffiColor.oklch(0.50, 0.06, 46)
        static let cap     = ReffiColor.oklch(0.55, 0.14, 30)    // 병뚜껑(레드 액센트)
        static let metal   = ReffiColor.oklch(0.82, 0.008, 250)  // 캔 금속
        static let metalSh = ReffiColor.oklch(0.70, 0.012, 250)
        static let metalHi = ReffiColor.oklch(0.91, 0.006, 250)
        static let cabbageVein = ReffiColor.oklch(0.94, 0.04, 130)
        // 김밥의 김 단면
        static let seaweedDk = ReffiColor.oklch(0.33, 0.055, 156) // 김/미역(진초록)
        static let seaweedShd = ReffiColor.oklch(0.26, 0.05, 155)
        static let seaweedGloss = ReffiColor.oklch(0.45, 0.07, 158)
    }

    // MARK: Helpers
    private func fill(_ ctx: inout GraphicsContext, _ p: Path, _ color: Color) { ctx.fill(p, with: .color(color)) }

    /// 종이 그림자(아래로 옅게).
    private func shadow(_ ctx: inout GraphicsContext, _ p: Path, _ r: CGRect) {
        ctx.fill(p.applying(.init(translationX: 0, y: r.height * 0.02)), with: .color(.black.opacity(0.08)))
    }
    /// 닫힌 다각형(직선 면). **모든 글리프의 면이 이 한 곳을 지난다**(`facet`도 여기로
    /// 모인다) — 그래서 시든 재료의 "각이 무뎌짐"을 53종 draw 함수를 건드리지 않고 여기서 일괄 적용한다.
    private func poly(_ pts: [CGPoint]) -> Path {
        if let look, look.rounding > 0, pts.count >= 3 {
            return roundedPoly(pts, look.rounding)
        }
        var p = Path()
        guard let f = pts.first else { return p }
        p.move(to: f)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        p.closeSubpath()
        return p
    }

    /// 꼭짓점을 깎은 닫힌 다각형 — 각 꼭짓점에서 인접 두 변으로 물러난 지점을 2차 베지에로 잇는다
    /// (제어점 = 원래 꼭짓점).
    ///
    /// 물러나는 거리는 **그 도형 자신의 짧은 변(바운딩 박스) 비율**이다. 변 길이 비율로 잡으면
    /// 마름모(잎)처럼 변이 긴 도형만 통째로 뭉개져 정체불명의 블롭이 되고, 12각형처럼 변이 짧은
    /// 도형은 거의 안 변한다 — 같은 글리프 안에서도 처리 강도가 제각각이 된다. 도형 크기 기준이면
    /// 모든 면이 비슷한 만큼 무뎌지고, 잎맥·씨앗 같은 **가느다란 조각은 자기 폭에 비례해 거의 그대로**
    /// 남아 몸통 밖으로 삐져나오지 않는다.
    ///
    /// 꼭짓점당 물러나는 거리는 짧은 인접 변의 42%로 한 번 더 조인다 — 이웃한 라운딩끼리 한 변에서
    /// 소비하는 길이의 합이 최대 84%라 서로 겹치지 않는다.
    private func roundedPoly(_ pts: [CGPoint], _ frac: CGFloat) -> Path {
        // 바운딩 박스는 한 번만 훑는다 — 시든 글리프의 **모든 면**이 여기를 지나므로(위 `poly` 주석)
        // 면마다 임시 배열 둘을 힙에 만들면 한 번의 Canvas 재드로우가 수백 개를 태운다.
        guard let f = pts.first else { return Path() }   // 호출부(`poly`)가 3점 이상을 보장하지만 방어
        var minX = f.x, maxX = f.x, minY = f.y, maxY = f.y
        for p in pts.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let radius = min(maxX - minX, maxY - minY) * frac
        let n = pts.count
        var p = Path()
        var started = false
        func step(to pt: CGPoint) {
            if started { p.addLine(to: pt) } else { p.move(to: pt); started = true }
        }
        for i in 0..<n {
            let cur = pts[i], prev = pts[(i + n - 1) % n], next = pts[(i + 1) % n]
            let (dxA, dyA) = (prev.x - cur.x, prev.y - cur.y)
            let (dxB, dyB) = (next.x - cur.x, next.y - cur.y)
            let lenA = hypot(dxA, dyA), lenB = hypot(dxB, dyB)
            // 길이 0인 변(중복 점)은 깎을 방향이 없다 — 원래 꼭짓점을 그대로 통과시킨다.
            guard lenA > 0.0001, lenB > 0.0001 else { step(to: cur); continue }
            let back = min(radius, 0.42 * min(lenA, lenB))
            step(to: CGPoint(x: cur.x + dxA / lenA * back, y: cur.y + dyA / lenA * back))
            p.addQuadCurve(to: CGPoint(x: cur.x + dxB / lenB * back, y: cur.y + dyB / lenB * back),
                           control: cur)
        }
        p.closeSubpath()
        return p
    }

    /// 각진 N각형(타원 근사) — 곡선 대신 직선 면으로 종이 컷 느낌. phase로 첫 정점 각도 조절.
    private func facet(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat,
                              _ sides: Int, phase: CGFloat = -.pi / 2) -> Path {
        var pts: [CGPoint] = []
        for i in 0..<sides {
            let a = phase + CGFloat(i) / CGFloat(sides) * 2 * .pi
            pts.append(CGPoint(x: cx + cos(a) * w / 2, y: cy + sin(a) * h / 2))
        }
        return poly(pts)
    }

    /// 몸통 면분할(2~3톤) — body로 클립하고 우하 어두운 면 + 좌상 밝은 면을 얹는다.
    /// 대각선 직선 경계라 "잘라 붙인 면" 느낌이 난다.
    private func shadeBody(_ ctx: inout GraphicsContext, _ body: Path,
                                  dark: Color, light: Color? = nil, split: CGFloat = 0.42) {
        let b = body.boundingRect
        guard b.width > 0, b.height > 0 else { return }
        var c = ctx
        c.clip(to: body)
        let d = poly([CGPoint(x: b.minX - 2, y: b.maxY + 2),
                      CGPoint(x: b.maxX + 2, y: b.minY + b.height * split),
                      CGPoint(x: b.maxX + 2, y: b.maxY + 2)])
        c.fill(d, with: .color(dark))
        if let light {
            let l = poly([CGPoint(x: b.minX - 2, y: b.minY - 2),
                          CGPoint(x: b.minX + b.width * 0.6, y: b.minY - 2),
                          CGPoint(x: b.minX - 2, y: b.minY + b.height * 0.64)])
            c.fill(l, with: .color(light))
        }
    }

    // MARK: Dispatch
    func draw(_ glyph: FoodGlyph, in r: CGRect, ctx: inout GraphicsContext) {
        switch glyph {
        // 채소
        case .root:      carrot(r, &ctx)
        case .tomato:    tomato(r, &ctx)
        case .pepper:    pepper(r, &ctx)
        case .squash:    zucchini(r, &ctx)
        case .leaf:      greens(r, &ctx)
        case .onion:     onion(r, &ctx)
        case .mushroom:  mushroom(r, &ctx)
        case .broccoli:  broccoli(r, &ctx)
        case .potato:    potato(r, &ctx)
        case .garlic:    garlic(r, &ctx)
        case .cucumber:  cucumber(r, &ctx)
        case .pea:       pea(r, &ctx)
        case .cabbage:   cabbage(r, &ctx)
        case .chili:     chili(r, &ctx)
        case .pumpkin:   pumpkin(r, &ctx)
        case .corn:      corn(r, &ctx)
        case .eggplant:  eggplant(r, &ctx)
        case .sweetPotato: sweetPotato(r, &ctx)
        case .ginger:    ginger(r, &ctx)
        case .seaweed:   seaweed(r, &ctx)
        // 과일
        case .apple:     apple(r, &ctx)
        case .citrus:    lemon(r, &ctx)
        case .berry:     berry(r, &ctx)
        case .avocado:   avocado(r, &ctx)
        case .banana:    banana(r, &ctx)
        case .grape:     grape(r, &ctx)
        case .watermelon: watermelon(r, &ctx)
        case .pineapple: pineapple(r, &ctx)
        case .mango:     mango(r, &ctx)
        // 단백질
        case .egg:       egg(r, &ctx)
        case .tofu:      tofu(r, &ctx)
        case .meat:      meat(r, &ctx)
        case .poultry:   drumstick(r, &ctx)
        case .fish:      fish(r, &ctx)
        case .shrimp:    shrimp(r, &ctx)
        case .sausage:   sausage(r, &ctx)
        case .bacon:     bacon(r, &ctx)
        case .crab:      crab(r, &ctx)
        case .squid:     squid(r, &ctx)
        case .clam:      clam(r, &ctx)
        // 유제품·곡류·저장식품
        case .milk:      milk(r, &ctx)
        case .cheese:    cheese(r, &ctx)
        case .bread:     bread(r, &ctx)
        case .yogurt:    yogurt(r, &ctx)
        case .butter:    butter(r, &ctx)
        case .rice:      rice(r, &ctx)
        case .noodles:   noodles(r, &ctx)
        case .sauceBottle: sauceBottle(r, &ctx)
        case .can:       can(r, &ctx)
        case .honey:     honey(r, &ctx)
        case .dumpling:  dumpling(r, &ctx)
        case .gimbap:    gimbap(r, &ctx)
        case .scallion, .radish, .beet, .lotusRoot, .burdock, .enoki, .napa,
             .sprout, .bokChoy, .asparagus, .celery, .cauliflower, .pear, .peach,
             .blueberry, .cherry, .kiwi, .melon, .orange, .lime, .salmon,
             .octopus, .fishCake, .kimchi, .riceCake, .flour, .grains, .spice,
             .beans, .nuts, .walnut, .jar, .oil, .water, .coffee,
             .tea, .juice, .chocolate, .olive, .driedFruit, .cornDog, .ricePaper,
             .iceCream:
            additional(glyph, in: r, ctx: &ctx)
        case .salt, .peppercorn, .curryPowder, .cinnamon, .starAnise, .wasabi:
            additional(glyph, in: r, ctx: &ctx)
        case .generic:   blob(r, &ctx)
        }
    }

    // MARK: - Vegetables

    private func carrot(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(36,38),(27,5),(36,4),(45,35),(45,2),(55,3),(53,35),(66,7),(75,8),(60,42)],C.dGreen)
        cut(&c,[(47,36),(46,4),(52,4),(53,37)],C.mGreen)
        layeredCut(&c,[(27,35),(37,29),(67,32),(73,40),(57,92),(50,99),(43,96),(32,62)],C.carrot)
        cut(&c,[(66,34),(73,40),(57,92),(50,99),(54,76),(62,51)],C.carrotSh.opacity(0.45))
        seam(&c,31,49,43,51,1.8,C.carrotHi)
        seam(&c,58,64,64,62,1.5,C.carrotSh)
        seam(&c,41,77,48,78,1.4,C.carrotHi)
    }

    private func tomato(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(52,25),(48,7),(54,4),(58,24),(73,9),(80,13),(65,30)],C.dGreen)
        cut(&c,[(17,38),(26,26),(40,20),(53,23),(64,21),(77,28),(86,40),(89,56),
                (85,73),(75,84),(60,91),(42,92),(27,87),(15,77),(10,62),(11,49)],C.tomato)
        cut(&c,[(75,84),(60,91),(42,92),(27,87),(15,77),(10,62),(18,73),(32,81),(50,85),(67,84)],C.tomatoSh.opacity(0.48))
        layeredCut(&c,[(52,29),(33,20),(44,32),(29,36),(49,36),(54,46),(59,33),(75,28),(62,27),(65,17)],C.dGreen)
    }

    private func pepper(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(43,30),(51,17),(50,3),(64,4),(70,29)],C.mGreen)
        layeredCut(&c,[(16,34),(22,23),(34,21),(43,28),(54,27),(67,23),(80,28),(85,40),
                (81,63),(72,87),(61,91),(48,88),(36,91),(21,81),(16,59)],C.yellow)
        cut(&c,[(67,27),(80,28),(85,40),(81,63),(72,87),(61,91),(65,74),(70,48)],C.yellowSh.opacity(0.5))
        cut(&c,[(22,30),(30,26),(37,28),(31,43),(29,68),(24,76),(20,57)],C.yellowHi.opacity(0.55))
    }

    private func zucchini(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(34,22),(25,10),(32,5),(45,18)],C.dGreen)
        layeredCut(&c,[(30,19),(42,15),(53,21),(65,40),(76,65),(75,79),(65,87),(51,82),
                (41,68),(29,41),(26,27)],C.leafHi)
        cut(&c,[(44,19),(53,21),(65,40),(76,65),(75,79),(65,87),(64,72),(53,44)],C.mGreen)
        seam(&c,33,27,54,74,3,C.lGreen)
        oval(&c,35,74,40,35,C.mGreen)
        oval(&c,34,72,34,29,C.flesh)
        for (x,y,a) in [(CGFloat(28),CGFloat(69),-30.0),(40,69,30.0),(34,79,0.0)] {
            seed(&c,x,y,3.5,7,C.lGreen,angle:a)
        }
    }

    private func greens(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        var left=c; left.translateBy(x:43,y:90); left.rotate(by:.degrees(-22))
        cut(&left,[(0,0),(-4,-14),(-22,-25),(-27,-39),(-23,-48),(-27,-61),(-21,-74),
                   (-7,-82),(5,-80),(16,-70),(16,-60),(23,-47),(20,-31),(7,-16),(5,0)],C.dGreen)
        seam(&left,1,-4,-4,-71,2.2,C.leafHi)
        for y in [CGFloat(-29),-45,-60] { seam(&left,0,y,-16,y-12,1,C.mGreen); seam(&left,0,y,12,y-11,1,C.mGreen) }
        var right=c; right.translateBy(x:54,y:92); right.rotate(by:.degrees(22))
        cut(&right,[(0,0),(-3,-13),(-16,-24),(-21,-36),(-18,-46),(-22,-55),(-16,-70),
                    (-3,-80),(10,-77),(21,-65),(20,-50),(25,-40),(19,-25),(6,-12),(5,0)],C.mGreen)
        cut(&right,[(2,-74),(10,-77),(21,-65),(20,-50),(25,-40),(19,-25),(4,-13)],C.leafHi.opacity(0.46))
        seam(&right,2,-3,1,-73,2.2,C.lGreen)
        for y in [CGFloat(-28),-44,-60] { seam(&right,2,y,-12,y-10,1,C.lGreen); seam(&right,2,y,17,y-10,1,C.lGreen) }
    }

    private func onion(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(44,28),(42,17),(44,7),(50,14),(57,9),(55,25)],C.tanSh)
        for i in 0..<4 { seam(&c,42+CGFloat(i)*4,84,36+CGFloat(i)*8,96,1.5,C.purple) }
        layeredCut(&c,[(43,24),(55,25),(60,32),(73,39),(82,51),(85,65),(79,79),(65,89),
                       (47,91),(31,86),(20,77),(15,63),(18,48),(28,36),(39,30)],C.tan)
        cut(&c,[(44,28),(49,27),(40,40),(33,55),(33,73),(42,88),(31,84),(23,73),(21,59),(26,44)],C.bread)
        cut(&c,[(59,32),(73,39),(82,51),(85,65),(79,79),(65,89),(56,90),(70,78),(75,63),(70,47)],C.tanSh)
        cut(&c,[(48,33),(53,31),(59,44),(62,61),(58,79),(51,88),(43,77),(40,62),(43,45)],C.onion)
        seam(&c,50,41,49,77,1.3,C.onionSh)
    }

    private func mushroom(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(39,42),(60,43),(63,65),(72,80),(67,88),(52,92),(39,87),(37,76)],C.onionSh)
        cut(&c,[(39,43),(52,44),(51,65),(58,87),(46,88),(39,82),(37,73)],C.cream)
        cut(&c,[(10,48),(20,32),(40,24),(63,24),(80,35),(91,51),(81,59),(58,64),(35,61),(16,56)],C.tanDk)
        for (x,y) in [(CGFloat(22),CGFloat(53)),(36,57),(62,59),(77,55)] { seam(&c,50,49,x,y,1,C.tan) }
        layeredCut(&c,[(10,48),(13,37),(21,26),(33,19),(48,16),(65,18),(78,25),(86,35),(91,48),
                       (78,51),(60,49),(43,53),(27,49)],C.tan)
        cut(&c,[(14,38),(21,28),(35,21),(49,19),(41,24),(28,31),(21,42)],C.bread)
        seam(&c,39,70,42,81,1.4,C.tan.opacity(0.45))
    }

    private func broccoli(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(39,92),(43,68),(24,45),(32,40),(50,60),(66,39),(76,45),(59,67),(62,93)],C.leafHi)
        cut(&c,[(49,65),(54,59),(59,67),(62,93),(51,94)],C.mGreen)
        for (x,y,w,h,col) in [(CGFloat(28),CGFloat(44),CGFloat(39),CGFloat(35),C.dGreen),
                              (67,42,43,37,C.dGreen),(45,27,39,35,C.mGreen),
                              (25,31,29,29,C.mGreen),(74,30,29,27,C.mGreen),(47,47,42,34,C.dGreen)] {
            oval(&c,x,y,w,h,col,sides:12)
        }
        for (x,y,w) in [(CGFloat(19),CGFloat(35),CGFloat(13)),(35,22,15),(53,18,13),(69,25,14),(80,37,11),(42,39,15),(56,45,12)] {
            cut(&c,[(x-w/2,y+2),(x-w/2+2,y-4),(x-2,y-7),(x+5,y-5),(x+w/2,y),(x+2,y-1),(x-3,y+3)],C.leafHi.opacity(0.65))
        }
    }

    private func potato(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(17,39),(27,27),(47,23),(61,28),(67,43),(63,63),(50,74),(28,72),(15,59)],C.tanSh)
        layeredCut(&c,[(29,57),(37,42),(52,35),(70,34),(85,42),(92,55),(88,71),(78,84),
                       (61,88),(44,83),(31,72)],C.tan)
        cut(&c,[(35,57),(41,45),(54,40),(69,38),(58,43),(47,51),(42,63)],C.bread)
        for (x,y) in [(CGFloat(29),CGFloat(44)),(43,32),(57,59),(75,48),(78,71),(48,77)] {
            seed(&c,x,y,3,4,C.tanDk,angle:35)
            seam(&c,x-2,y+3,x+3,y+2,1,C.bread)
        }
    }

    private func garlic(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(43,32),(46,8),(54,6),(53,23),(58,34)],C.onionSh)
        for i in 0..<4 { seam(&c,43+CGFloat(i)*4,84,37+CGFloat(i)*7,95,1.5,C.tanSh) }
        cut(&c,[(43,28),(55,29),(63,39),(75,46),(82,60),(79,77),(66,86),(50,87),(33,87),
                (20,77),(18,63),(24,48),(36,39)],C.onionSh)
        layeredCut(&c,[(39,38),(44,31),(43,48),(38,65),(43,85),(32,82),(23,72),(22,61),(29,46)],C.cream)
        layeredCut(&c,[(54,32),(63,39),(74,48),(79,63),(74,79),(62,85),(58,66)],C.onion)
        layeredCut(&c,[(48,30),(53,32),(57,49),(60,66),(55,83),(49,89),(40,81),(38,67),(42,47)],C.creamHi)
        seam(&c,49,46,46,73,1,C.onionSh.opacity(0.65))
    }

    private func cucumber(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        let rim:[(CGFloat,CGFloat)]=[(22,20),(42,11),(64,14),(82,25),(90,44),(86,66),(75,82),(55,90),(34,86),(17,72),(11,53),(14,34)]
        cut(&c,rim,C.dGreen)
        layeredCut(&c,[(25,25),(43,18),(62,20),(77,30),(83,45),(80,62),(70,76),(54,83),(36,79),(23,68),(18,52),(20,36)],C.lGreen)
        for i in 0..<5 {
            var s=c; s.translateBy(x:50,y:51); s.rotate(by:.degrees(Double(i)*72-15))
            cut(&s,[(-3,-5),(-13,-13),(-14,-22),(-10,-28),(-3,-29),(3,-24),(5,-16)],C.dGreen)
        }
    }

    private func pea(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(37,83),(27,70),(24,52),(27,33),(38,15),(56,5),(59,31),(57,57),(50,79),(42,92)],C.dGreen)
        cut(&c,[(42,89),(32,71),(31,53),(34,34),(45,17),(50,14),(47,39),(44,64)],C.mGreen)
        for (x,y,w) in [(CGFloat(43),CGFloat(33),CGFloat(17)),(40,54,19),(40,74,16)] { oval(&c,x,y,w,w,C.lGreen,sides:12) }
        layeredCut(&c,[(55,89),(61,62),(70,40),(86,25),(86,48),(80,70),(68,89),(58,96)],C.dGreen)
        for (x,y,w) in [(CGFloat(77),CGFloat(48),CGFloat(14)),(70,65,15),(62,82,13)] { oval(&c,x,y,w,w,C.leafHi,sides:11) }
    }

    private func cabbage(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(12,38),(22,25),(31,22),(41,14),(59,12),(70,20),(81,24),(91,41),
                (92,61),(82,78),(65,90),(42,91),(23,81),(12,64)],C.mGreen)
        layeredCut(&c,[(21,30),(37,23),(55,29),(62,47),(54,65),(40,75),(24,67),(16,50)],C.leafHi)
        layeredCut(&c,[(75,27),(59,26),(45,38),(43,55),(53,72),(69,79),(84,64),(87,45)],C.lGreen)
        layeredCut(&c,[(28,70),(31,51),(41,40),(55,38),(66,46),(71,60),(67,77),(55,86),(39,84)],C.flesh)
        cut(&c,[(28,70),(38,63),(46,66),(53,79),(55,86),(39,84)],C.lGreen)
        seam(&c,52,82,49,48,1.8,C.cream)
        seam(&c,49,64,37,55,1.2,C.cream)
        seam(&c,51,73,64,59,1.2,C.cream)
        seam(&c,27,36,34,61,1.2,C.lGreen)
        seam(&c,77,38,70,62,1.2,C.flesh)
    }

    private func chili(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(35,25),(38,9),(48,4),(58,7),(53,12),(46,13),(44,27)],C.dGreen)
        layeredCut(&c,[(31,26),(43,21),(55,27),(64,43),(66,58),(60,73),(50,85),(35,94),
                       (19,97),(35,84),(44,69),(45,54),(39,40)],C.tomato)
        cut(&c,[(55,27),(64,43),(66,58),(60,73),(50,85),(35,94),(19,97),(42,82),(54,64),(57,47)],C.tomatoSh)
        cut(&c,[(31,26),(35,22),(43,21),(51,25),(51,32),(43,28),(38,33)],C.mGreen)
        seam(&c,39,37,48,55,2.5,C.tomatoHi)
    }

    private func pumpkin(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(44,30),(45,16),(52,11),(59,14),(55,24),(59,32)],C.dGreen)
        cut(&c,[(17,37),(29,28),(45,30),(56,28),(75,31),(88,44),(91,61),(86,75),
                (72,84),(53,88),(33,86),(19,79),(10,65),(10,49)],C.carrotSh)
        layeredCut(&c,[(31,31),(42,31),(34,44),(31,61),(35,80),(28,82),(17,72),(13,60),(15,46)],C.carrot)
        layeredCut(&c,[(58,31),(71,31),(82,42),(87,59),(81,74),(71,81),(67,74),(69,57),(63,41)],C.carrot)
        layeredCut(&c,[(47,29),(58,32),(65,47),(66,68),(59,84),(48,89),(39,82),(34,66),(36,46)],C.carrotHi)
        seam(&c,49,39,47,77,1.5,C.carrot)
    }

    private func corn(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(43,91),(25,78),(15,52),(22,56),(35,70),(37,36),(45,69)],C.dGreen)
        cut(&c,[(37,25),(42,13),(53,8),(63,14),(69,28),(68,65),(58,82),(45,83),(35,69)],C.yellowSh)
        for row in 0..<8 { for col in 0..<3 {
            let x=CGFloat(40+col*8)+CGFloat(row%2),y=CGFloat(22+row*7)
            cut(&c,[(x,y),(x+6,y-1),(x+7,y+4),(x+2,y+6),(x-1,y+4)],(row+col)%3 == 0 ? C.yellowHi : C.yellow)
        } }
        layeredCut(&c,[(41,88),(52,74),(68,56),(86,42),(79,65),(68,83),(52,96)],C.mGreen)
        cut(&c,[(49,89),(60,72),(75,57),(68,74),(56,92)],C.leafHi)
    }

    // MARK: - Fruit

    private func apple(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(46,28),(48,10),(54,7),(56,10),(52,29)],C.brown)
        cut(&c,[(54,20),(62,9),(74,8),(83,12),(73,21),(62,24)],C.dGreen)
        layeredCut(&c,[(17,36),(27,27),(40,27),(50,33),(60,26),(74,27),(85,37),(89,51),
                       (86,67),(78,83),(67,92),(56,91),(49,86),(40,92),(28,87),(18,74),(12,57),(12,46)],C.apple)
        cut(&c,[(85,37),(89,51),(86,67),(78,83),(67,92),(56,91),(49,86),(61,86),(72,77),(80,62)],C.appleSh)
        cut(&c,[(20,45),(27,36),(36,33),(40,37),(31,40),(24,50),(21,61)],C.appleHi)
    }

    private func lemon(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(13,43),(18,33),(35,24),(53,23),(71,32),(79,44),(87,48),(83,56),
                (72,59),(63,69),(43,75),(26,69),(14,58),(7,53)],C.yellow)
        cut(&c,[(83,56),(72,59),(63,69),(43,75),(26,69),(14,58),(29,64),(46,66),(65,58),(77,49)],C.yellowSh)
        layeredCut(&c,[(43,78),(47,60),(59,49),(73,47),(86,56),(92,70),(88,84),(76,94),(61,94),(49,88)],C.yellow)
        oval(&c,68,72,41,40,C.cream,sides:14)
        for i in 0..<7 {
            var q=c;q.translateBy(x:68,y:72);q.rotate(by:.degrees(Double(i)*360/7))
            let a: CGFloat = 0.12, b: CGFloat = 2 * .pi / 7 - 0.12
            cut(&q,[(3*cos(a),3*sin(a)),(17*cos(a),17*sin(a)),
                    (17*cos((a+b)/2),17*sin((a+b)/2)),(17*cos(b),17*sin(b)),
                    (3*cos(b),3*sin(b))],C.yellow)
        }
    }

    private func berry(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(44,24),(46,10),(53,8),(52,25)],C.dGreen)
        layeredCut(&c,[(21,30),(32,24),(46,28),(57,24),(72,27),(82,36),(83,50),(76,65),
                       (62,84),(50,94),(40,90),(26,76),(16,59),(13,44)],C.berry)
        cut(&c,[(80,38),(83,50),(76,65),(62,84),(50,94),(40,90),(53,81),(66,65),(74,47)],C.berrySh)
        layeredCut(&c,[(24,24),(39,29),(40,18),(50,27),(63,16),(62,29),(78,25),(65,38),(52,33),(41,41),(37,32)],C.dGreen)
        for (x,y,a) in [(CGFloat(26),CGFloat(45),-20.0),(45,47,0.0),(65,44,25.0),(29,61,-25.0),
                        (49,64,0.0),(67,60,20.0),(41,79,-12.0),(57,78,16.0)] {
            seed(&c,x,y,2.5,4.8,C.yellowHi,angle:a)
        }
    }

    private func avocado(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        let outline:[(CGFloat,CGFloat)]=[(45,8),(53,9),(63,20),(68,34),(78,53),(83,68),(80,82),(69,92),(52,98),(34,94),(22,85),(17,71),(20,57),(30,39),(36,21)]
        cut(&c,outline,C.avoSkin)
        layeredCut(&c,[(45,14),(52,15),(58,25),(62,39),(73,57),(77,70),(73,82),(62,90),
                       (50,93),(36,89),(26,81),(23,70),(26,58),(35,42),(40,25)],C.avoRim)
        cut(&c,[(46,19),(51,20),(56,32),(58,42),(68,59),(72,71),(68,81),(58,86),(46,88),
                (34,82),(29,72),(32,59),(40,42)],C.avoFlesh)
        oval(&c,49,70,32,34,C.pit,sides:15)
        cut(&c,[(38,64),(43,56),(53,55),(60,61),(57,69),(48,71),(41,68)],C.tanSh)
    }

    private func banana(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(71,18),(77,6),(84,10),(79,23)],C.bananaTip)
        layeredCut(&c,[(75,20),(81,22),(84,40),(80,60),(69,76),(52,87),(33,91),(19,86),(9,77),
                       (11,71),(25,77),(40,74),(56,61),(67,43)],C.bananaSh)
        layeredCut(&c,[(70,18),(78,22),(75,42),(66,59),(50,71),(32,76),(18,72),(8,63),(9,56),
                       (24,63),(39,59),(52,47),(61,30)],C.banana)
        cut(&c,[(72,23),(69,39),(60,54),(46,65),(31,69),(19,65),(32,64),(46,58),(57,46),(65,27)],C.yellowHi)
        cut(&c,[(9,56),(13,59),(10,65),(5,62)],C.bananaTip)
        cut(&c,[(10,73),(14,76),(10,81),(6,78)],C.bananaTip)
    }

    // MARK: - Protein

    private func egg(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        layeredCut(&c,[(24,28),(34,21),(48,24),(58,18),(73,22),(80,32),(78,44),(88,56),
                       (88,67),(79,75),(77,87),(64,92),(52,87),(38,92),(25,87),(24,77),(14,72),
                       (11,60),(17,49),(16,37)],C.creamHi)
        cut(&c,[(77,87),(64,92),(52,87),(38,92),(25,87),(24,77),(32,82),(42,84),(53,80),(65,85)],C.creamLo.opacity(0.48))
        oval(&c,51,57,39,41,C.yellowSh,sides:17)
        oval(&c,50,55,39,39,C.yellow,sides:17)
    }

    private func tofu(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(14,40),(66,36),(87,48),(84,82),(33,90),(15,77)],C.creamLo)
        cut(&c,[(15,40),(35,49),(33,90),(15,77)],C.onionSh)
        layeredCut(&c,[(14,40),(65,32),(87,44),(35,53)],C.creamHi)
        cut(&c,[(35,53),(87,44),(84,82),(33,90)],C.cream)
        layeredCut(&c,[(26,21),(60,17),(76,26),(75,44),(40,49),(26,41)],C.creamLo)
        cut(&c,[(26,21),(60,17),(76,26),(40,32)],C.creamHi)
        cut(&c,[(40,32),(76,26),(75,44),(40,49)],C.cream)
        for (x,y) in [(CGFloat(47),CGFloat(64)),(71,62),(58,79),(47,38),(62,24),(23,39)] {
            oval(&c,x,y,1.8,1.3,C.onionSh,sides:6)
        }
    }

    private func meat(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        let shape:[(CGFloat,CGFloat)]=[(14,39),(24,29),(40,23),(56,17),(72,20),(85,30),(92,47),
                (89,64),(78,78),(64,85),(49,82),(35,87),(22,79),(12,63),(10,50)]
        cut(&c,shape,C.meatSh)
        layeredCut(&c,shape.map{($0.0,$0.1-3)},C.fat)
        cut(&c,[(17,42),(27,32),(42,28),(54,30),(59,39),(56,49),(45,56),(36,65),(30,77),
                (24,73),(17,62),(14,51)],C.meat)
        cut(&c,[(58,23),(70,23),(81,31),(88,45),(86,56),(76,62),(64,53),(61,42),(63,33)],C.meat)
        cut(&c,[(57,54),(66,58),(76,67),(82,66),(75,76),(63,80),(50,77),(38,81),(41,69),(48,61)],C.meat)
        seam(&c,23,48,41,38,1.5,C.fat.opacity(0.65))
        seam(&c,24,62,32,56,1.2,C.fat.opacity(0.6))
        seam(&c,71,32,78,45,1.3,C.fat.opacity(0.6))
    }

    private func drumstick(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(60,47),(69,25),(67,19),(71,12),(77,11),(81,16),(84,12),(91,15),(93,21),
                (88,27),(82,28),(71,53)],C.creamLo)
        cut(&c,[(62,45),(73,25),(71,20),(73,15),(78,16),(81,21),(87,17),(89,21),(84,25),(77,27),(68,48)],C.creamHi)
        layeredCut(&c,[(55,39),(67,43),(74,53),(73,68),(64,82),(51,91),(35,91),(23,83),(16,69),
                       (18,55),(29,43),(42,38)],C.poultry)
        cut(&c,[(72,54),(73,68),(64,82),(51,91),(35,91),(23,83),(34,84),(48,81),(60,71)],C.poultrySh)
        cut(&c,[(24,59),(31,49),(44,44),(53,45),(45,49),(35,54),(29,65)],C.bread.opacity(0.65))
    }

    private func fish(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        c.translateBy(x:50,y:50); c.rotate(by:.degrees(-25)); c.translateBy(x:-50,y:-50)
        cut(&c,[(72,46),(91,33),(86,49),(94,63),(72,56)],C.fish)
        cut(&c,[(37,41),(48,27),(60,42)],C.fish)
        cut(&c,[(44,61),(57,73),(62,61)],C.fish)
        layeredCut(&c,[(4,51),(14,43),(29,37),(45,36),(63,41),(79,49),(73,56),
                       (57,63),(38,66),(23,63),(10,57)],C.creamLo)
        cut(&c,[(4,51),(14,43),(29,37),(45,36),(63,41),(79,49),(59,44),(40,42),(23,46)],C.fishHi)
        cut(&c,[(10,55),(25,59),(42,61),(60,57),(74,51),(73,56),(57,63),(38,66),(23,63)],C.creamHi)
        layeredCut(&c,[(36,46),(49,49),(54,57),(47,59),(37,53)],C.fishHi)
        cut(&c,[(26,43),(29,46),(30,53),(27,60),(25,59),(27,52)],C.fish)
        oval(&c,17,49,7,7,C.creamHi,sides:16)
        oval(&c,17.5,49,4.5,4.5,C.inkFixed,sides:14)
        seam(&c,82,47,89,38,1.1,C.fishHi)
        seam(&c,82,52,90,59,1.1,C.fishHi)
    }

    private func shrimp(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(30,22),(47,16),(63,20),(77,30),(84,44),(86,58),(82,72),(72,84),(55,90),
                (40,86),(30,78),(27,67),(33,56),(44,52),(47,60),(41,66),(44,73),(53,77),
                (64,73),(68,64),(68,52),(61,40),(48,35),(34,36)],C.shrimpSh)
        layeredCut(&c,[(31,21),(47,16),(62,20),(71,29),(66,42),(57,36),(45,32),(32,34)],C.shrimp)
        layeredCut(&c,[(71,30),(80,40),(84,52),(71,57),(68,46),(64,40)],C.shrimp)
        layeredCut(&c,[(85,53),(86,63),(80,76),(68,69),(70,58)],C.shrimp)
        layeredCut(&c,[(80,77),(70,85),(56,89),(54,77),(63,74),(68,70)],C.shrimp)
        layeredCut(&c,[(54,89),(42,86),(34,79),(43,71),(47,76),(54,77)],C.shrimp)
        layeredCut(&c,[(32,78),(26,69),(30,59),(38,54),(44,57),(41,67),(43,72)],C.shrimp)
        cut(&c,[(34,34),(17,32),(10,18),(21,21),(23,9),(35,19),(39,28)],C.tomato)
        seam(&c,42,24,57,28,2,C.fat.opacity(0.7))
        seam(&c,72,39,76,47,1.7,C.fat.opacity(0.7))
    }

    // MARK: - Dairy / grain / pantry / other

    private func milk(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(27,31),(45,14),(66,13),(79,29),(78,90),(27,95)],C.milkLbl)
        cut(&c,[(27,31),(45,14),(45,29),(61,39),(60,95),(27,95)],C.creamHi)
        cut(&c,[(61,39),(79,29),(78,90),(60,95)],C.bowlBHi)
        layeredCut(&c,[(27,31),(45,14),(66,13),(49,32)],C.cream)
        cut(&c,[(45,14),(45,8),(65,7),(66,13)],C.milkLbl)
        cut(&c,[(27,54),(60,55),(60,79),(27,79)],C.milkLbl)
        cut(&c,[(60,55),(79,47),(78,72),(60,79)],C.fishDk)
        seed(&c,44,67,11,16,C.creamHi)
        seam(&c,32,87,51,87,1.3,C.onionSh)
    }

    private func cheese(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(12,46),(65,29),(89,56),(85,78),(31,91),(12,73)],C.cheeseHl)
        layeredCut(&c,[(12,46),(65,23),(89,51),(31,65)],C.cheese)
        cut(&c,[(12,46),(31,65),(31,91),(12,73)],C.yellowSh)
        cut(&c,[(31,65),(89,51),(85,78),(31,91)],C.yellow)
        for (x,y,w,h) in [(CGFloat(43),CGFloat(45),CGFloat(12),CGFloat(8)),(64,37,8,6),(67,51,10,6),
                          (47,77,10,12),(75,66,7,9),(20,65,6,9)] {
            oval(&c,x,y,w,h,C.cheeseHl,sides:12)
            seam(&c,x-w*0.3,y+h*0.28,x+w*0.25,y+h*0.33,1,C.yellowHi)
        }
    }

    private func bread(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(21,32),(26,20),(38,14),(60,12),(75,18),(83,30),(82,42),(76,49),(79,86),(69,91),(28,91),(20,84),(22,49),(17,42)],C.crust)
        layeredCut(&c,[(16,37),(20,26),(31,19),(51,17),(66,20),(76,30),(77,40),(70,49),
                       (73,85),(67,93),(22,93),(14,86),(17,50),(11,43)],C.breadSh)
        cut(&c,[(21,38),(25,29),(35,25),(52,23),(64,26),(70,33),(71,40),(63,47),
                (67,83),(63,87),(25,87),(21,82),(24,47),(18,42)],C.bread)
        cut(&c,[(26,38),(31,32),(44,29),(58,29),(64,34),(62,41),(55,46),(58,78),(28,79),(30,45),(24,41)],C.creamLo)
        for (x,y,w) in [(CGFloat(38),CGFloat(39),CGFloat(3)),(54,53,2.5),(37,65,3),(49,73,2),(29,51,2)] {
            oval(&c,x,y,w,w*0.7,C.breadSh.opacity(0.6),sides:7)
        }
    }

    private func rice(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(37,82),(65,82),(69,91),(62,95),(39,95),(33,90)],C.bowlB)
        cut(&c,[(11,48),(90,47),(83,68),(71,83),(53,88),(32,83),(18,67)],C.bowlB)
        oval(&c,50,47,80,27,C.fishDk,sides:18)
        layeredCut(&c,[(14,44),(20,35),(29,31),(35,25),(47,23),(54,25),(64,23),(73,30),(79,32),
                       (86,44),(82,53),(68,59),(48,62),(30,57),(17,51)],C.rice)
        for (x,y,a) in [(CGFloat(27),CGFloat(41),-40.0),(39,32,45.0),(53,36,-25.0),(67,32,30.0),
                        (75,45,65.0),(39,49,-60.0),(58,50,30.0),(52,28,0.0),(22,48,15.0)] {
            seed(&c,x,y,2.6,5.5,C.riceSh,angle:a)
        }
        cut(&c,[(12,50),(30,60),(51,65),(72,60),(89,50),(83,68),(71,83),(53,88),(32,83),(18,67)],C.bowlBHi)
        cut(&c,[(74,60),(89,50),(83,68),(71,83),(53,88),(36,84),(53,82),(68,74)],C.bowlB)
    }

    private func noodles(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(35,83),(67,82),(70,91),(60,95),(39,95),(32,91)],C.bowlB)
        cut(&c,[(10,49),(90,49),(84,68),(71,84),(51,89),(30,82),(17,67)],C.bowlB)
        oval(&c,50,48,81,30,C.fishDk,sides:18)
        cut(&c,[(15,47),(24,37),(35,31),(48,33),(56,26),(67,29),(76,39),(84,41),(87,51),
                (71,60),(46,65),(25,59)],C.noodleSh)
        for i in 0..<5 {
            let x=CGFloat(23+i*11), y=CGFloat(i%2)*5
            cut(&c,[(x,52),(x-4,45-y),(x-2,35-y),(x+4,31-y),(x+10,33-y),(x+13,40-y),
                    (x+8,49),(x+9,58),(x+5,59),(x+4,49),(x+9,40-y),(x+7,36-y),(x+3,35-y),(x+1,39-y),(x+1,46-y),(x+4,51)],C.noodle)
        }
        cut(&c,[(11,51),(29,62),(49,67),(73,62),(90,51),(84,68),(71,84),(51,89),(30,82),(17,67)],C.bowlBHi)
        cut(&c,[(75,61),(90,51),(84,68),(71,84),(51,89),(37,84),(57,82),(70,74)],C.bowlB)
    }

    private func sauceBottle(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(38,17),(60,16),(61,34),(72,42),(73,87),(66,94),(34,94),(27,87),(29,42),(39,34)],C.bottle)
        cut(&c,[(39,22),(45,22),(44,37),(36,46),(35,83),(32,87),(32,43),(41,36)],C.bottleHi)
        layeredCut(&c,[(35,8),(63,7),(65,20),(35,22)],C.cap)
        for x in [CGFloat(40),46,52,58] { seam(&c,x,10,x,18,0.8,C.tomatoSh) }
        cut(&c,[(28,52),(73,51),(72,79),(28,80)],C.cream)
        oval(&c,50,65,20,21,C.cap,sides:14)
        cut(&c,[(49,57),(55,63),(54,68),(50,73),(45,69),(44,64)],C.cream)
    }

    private func can(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(19,32),(82,32),(82,80),(72,87),(49,91),(28,86),(18,79)],C.metal)
        cut(&c,[(70,36),(82,32),(82,80),(72,87),(60,89),(71,82)],C.metalSh)
        cut(&c,[(19,47),(81,47),(81,74),(71,81),(48,84),(19,74)],C.tomato)
        cut(&c,[(69,47),(81,47),(81,74),(71,81),(65,82)],C.tomatoSh)
        oval(&c,50,32,65,24,C.metalSh,sides:18)
        oval(&c,50,29,65,23,C.metalHi,sides:18)
        oval(&c,50,29,51,15,C.metal,sides:16)
        oval(&c,55,27,19,9,C.metalSh,sides:12)
        oval(&c,51,26,14,7,C.metalHi,sides:12)
        oval(&c,51,26,7,3.5,C.metalSh,sides:10)
        cut(&c,[(39,57),(46,53),(56,55),(61,62),(58,70),(49,74),(40,69),(36,63)],C.cream)
        cut(&c,[(46,55),(48,49),(51,52),(56,50),(54,56)],C.dGreen)
    }

    // MARK: - v2 신규 17종

    private func eggplant(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(52,22),(54,8),(61,3),(68,6),(65,11),(60,12),(61,25)],C.dGreen)
        layeredCut(&c,[(48,21),(63,24),(70,39),(75,59),(72,76),(62,89),(45,95),(29,91),
                       (19,80),(17,64),(24,49),(37,36)],C.purple)
        cut(&c,[(65,35),(70,39),(75,59),(72,76),(62,89),(45,95),(29,91),(22,83),(38,87),(55,79),(64,61)],C.avoSkin.opacity(0.48))
        cut(&c,[(48,21),(58,18),(65,23),(68,36),(60,31),(56,41),(51,30),(39,36),(44,28)],C.mGreen)
        cut(&c,[(38,42),(44,36),(42,47),(30,66),(30,77),(25,70),(27,56)],C.pink.opacity(0.26))
    }

    private func sweetPotato(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(9,58),(18,43),(37,32),(60,25),(76,28),(89,36),(85,46),(74,57),(53,65),(31,71),(15,70),(6,76)],C.purple)
        cut(&c,[(15,65),(31,63),(56,54),(79,36),(89,36),(85,46),(74,57),(53,65),(31,71)],C.berrySh)
        layeredCut(&c,[(41,69),(48,52),(63,45),(78,48),(87,60),(88,74),(78,85),(62,90),(48,83)],C.purple)
        cut(&c,[(46,69),(52,56),(64,51),(75,53),(82,62),(82,73),(74,81),(62,85),(52,79)],C.yellowHi)
        cut(&c,[(53,69),(58,59),(66,56),(75,61),(77,70),(71,78),(60,78)],C.yellow.opacity(0.6))
        for (x,y) in [(CGFloat(25),CGFloat(49)),(45,38),(59,51)] { seam(&c,x,y,x+5,y-2,1.5,C.pink.opacity(0.65)) }
    }

    private func ginger(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        let body:[(CGFloat,CGFloat)]=[(16,59),(12,46),(18,37),(28,38),(35,47),(39,37),(35,24),(40,15),(50,14),(56,23),(54,39),
              (65,41),(67,27),(74,22),(82,27),(83,38),(75,53),(88,61),(89,72),(81,79),(68,76),(57,65),(48,74),(47,84),(38,90),(28,87),(26,77),(32,65)]
        cut(&c,body,C.tanSh)
        layeredCut(&c,body.map { ($0.0-1,$0.1-2) },C.tan)
        for (x,y,a) in [(CGFloat(23),CGFloat(47),-25.0),(45,27,0.0),(74,34,24.0),(76,67,-55.0),(37,79,12.0)] {
            var n=c;n.translateBy(x:x,y:y);n.rotate(by:.degrees(a))
            seam(&n,-5,-2,5,-3,1.4,C.bread)
            seam(&n,-5,2,4,1,1,C.tanDk.opacity(0.6))
        }
    }

    private func seaweed(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(18,19),(70,11),(89,72),(34,88)],C.dGreen)
        layeredCut(&c,[(11,28),(66,19),(80,84),(25,95)],C.avoSkin)
        cut(&c,[(15,33),(30,30),(44,88),(28,91)],C.dGreen.opacity(0.48))
        for i in 0..<6 {
            let x=CGFloat(23+i*7)
            seam(&c,x,31,x+13,80,0.6,C.leafHi.opacity(0.22))
        }
        for i in 0..<6 { let y=CGFloat(39+i*8);seam(&c,24,y,65,y-7,0.7,C.mGreen.opacity(0.35)) }
    }

    // MARK: v2 과일

    private func grape(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(48,29),(48,9),(54,6),(57,10),(54,28)],C.brown)
        cut(&c,[(52,20),(66,9),(77,10),(84,18),(73,25),(60,26)],C.dGreen)
        let grapes:[(CGFloat,CGFloat,CGFloat,Color)]=[(31,35,25,C.purple),(55,32,26,C.purple),(73,42,25,C.purple),
            (28,55,26,C.purple),(51,53,28,C.purple),(68,64,24,C.purple),(40,73,25,C.purple),(52,87,23,C.purple)]
        for (x,y,w,col) in grapes {
            oval(&c,x,y+1.5,w,w,C.avoSkin.opacity(0.5),sides:13)
            oval(&c,x,y,w,w,col,sides:13)
            cut(&c,[(x-w*0.32,y),(x-w*0.30,y-w*0.25),(x-w*0.07,y-w*0.38),
                    (x+w*0.12,y-w*0.29),(x-w*0.09,y-w*0.23)],C.pink.opacity(0.35))
        }
    }

    private func watermelon(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(8,46),(27,30),(45,24),(64,26),(80,34),(94,46),(57,94),(46,96)],C.dGreen)
        layeredCut(&c,[(11,45),(28,33),(45,28),(64,30),(80,37),(90,47),(52,91)],C.flesh)
        cut(&c,[(15,47),(30,37),(46,32),(63,34),(78,41),(85,48),(52,86)],C.pink)
        cut(&c,[(46,32),(63,34),(78,41),(85,48),(52,86),(54,55)],C.tomato.opacity(0.4))
        for (x,y,a) in [(CGFloat(32),CGFloat(47),-40.0),(49,43,-8.0),(67,48,35.0),(43,60,-28.0),(61,61,25.0),(52,74,0.0)] {
            seed(&c,x,y,3,5,C.inkFixed,angle:a)
        }
    }

    private func pineapple(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(39,39),(20,14),(37,23),(32,3),(48,21),(52,0),(59,21),(73,7),(67,28),(83,22),(65,41)],C.dGreen)
        cut(&c,[(42,37),(35,15),(49,28),(52,10),(57,29),(69,20),(59,40)],C.mGreen)
        layeredCut(&c,[(38,34),(54,31),(68,38),(77,52),(80,69),(74,85),(61,94),(43,96),
                       (29,88),(21,74),(23,55),(29,42)],C.yellowSh)
        cut(&c,[(35,41),(48,37),(59,40),(67,52),(70,72),(62,86),(46,90),(32,82),(27,66)],C.yellow)
        for row in 0..<6 { for col in 0..<4 {
            let x=CGFloat(31+col*10)+CGFloat(row%2)*4,y=CGFloat(46+row*7)
            if !(row == 5 && col == 3) {
                cut(&c,[(x-3,y),(x,y-2),(x+4,y+1),(x+1,y+4)],C.carrotSh.opacity(0.45))
                seam(&c,x-3,y+1,x,y+4,1.3,C.yellowHi)
            }
        } }
    }

    private func mango(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(50,28),(54,15),(61,11),(69,12),(66,17),(58,18),(56,31)],C.dGreen)
        layeredCut(&c,[(44,25),(58,22),(72,25),(82,35),(85,49),(82,65),(72,80),(54,90),(34,91),
                       (19,84),(12,73),(14,61),(23,51),(29,36)],C.carrot)
        cut(&c,[(51,28),(61,26),(73,30),(80,41),(80,54),(74,66),(61,75),(43,83),(29,82),(22,74),
                (27,62),(37,52),(42,36)],C.yellow)
        cut(&c,[(20,63),(28,56),(35,54),(32,64),(25,71),(23,78),(17,74)],C.apple.opacity(0.5))
    }

    // MARK: v2 육류·해산물

    private func sausage(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(15,42),(10,38),(11,32),(19,34)],C.meatSh)
        cut(&c,[(79,33),(86,27),(91,30),(84,38)],C.meatSh)
        layeredCut(&c,[(16,35),(25,26),(41,23),(60,26),(78,31),(84,39),(81,49),(73,54),
                       (56,49),(41,46),(27,48),(19,47),(14,41)],C.meat)
        cut(&c,[(22,32),(31,28),(44,28),(61,32),(70,37),(58,35),(40,32),(27,36)],C.shrimp.opacity(0.65))
        layeredCut(&c,[(20,65),(34,54),(54,51),(75,58),(84,67),(83,78),(73,84),(57,77),
                       (42,76),(28,84),(20,78)],C.meatSh)
        cut(&c,[(23,64),(36,57),(52,56),(67,60),(76,67),(79,75),(70,78),(54,72),(41,72),(28,79),(21,75)],C.meat)
        oval(&c,25,72,17,22,C.shrimp,sides:13)
        oval(&c,25,72,12,16,C.meat,sides:12)
        for (x,y) in [(CGFloat(23),CGFloat(68)),(28,74),(23,77)] { oval(&c,x,y,2.5,3,C.fat,sides:6) }
    }

    private func bacon(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(9,33),(26,29),(43,39),(61,37),(80,22),(91,25),(94,68),(78,82),(59,85),(42,75),(25,69),(12,73)],C.meatSh)
        layeredCut(&c,[(9,29),(26,25),(43,35),(61,33),(80,18),(91,21),(93,37),(77,49),(60,52),(43,45),(26,36),(10,40)],C.meat)
        cut(&c,[(10,35),(26,30),(43,40),(60,43),(76,40),(91,27),(92,33),(77,45),(60,48),(42,44),(26,35),(10,40)],C.fat)
        layeredCut(&c,[(11,49),(27,44),(43,52),(60,59),(78,54),(92,42),(94,62),(78,77),(60,79),(42,68),(27,62),(12,68)],C.meat)
        cut(&c,[(12,56),(26,51),(43,59),(59,67),(77,65),(93,51),(94,58),(79,73),(60,73),(42,64),(27,57),(12,63)],C.fat)
    }

    private func crab(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        for side in [CGFloat(-1),1] {
            var q=c;q.translateBy(x:50,y:55);q.scaleBy(x:side,y:1)
            for i in 0..<3 { let y=CGFloat(i*10)
                cut(&q,[(20,y-4),(35,y+3),(44,y+15),(34,y+9),(18,y+3)],C.shrimpSh)
            }
            cut(&q,[(23,-6),(36,-18),(33,-31),(26,-33),(25,-43),(34,-35),(36,-44),(43,-38),(45,-28),(39,-15),(29,-1)],C.tomato)
        }
        cut(&c,[(36,39),(33,31),(37,29),(41,41),(59,40),(63,29),(67,31),(65,43)],C.shrimpSh)
        oval(&c,36,31,5,5,C.inkFixed,sides:10)
        oval(&c,64,31,5,5,C.inkFixed,sides:10)
        layeredCut(&c,[(24,46),(37,38),(53,37),(68,40),(78,51),(79,64),(68,74),(52,79),(36,76),(23,66),(20,56)],C.shrimp)
        cut(&c,[(24,61),(38,69),(54,71),(71,65),(79,58),(79,64),(68,74),(52,79),(36,76),(23,66)],C.shrimpSh)
    }

    private func squid(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(33,42),(15,47),(31,21),(50,9),(69,25),(84,49),(66,45)],C.pink)
        for i in 0..<5 {
            let x=CGFloat(32+i*8),spread=CGFloat(i-2)*4
            cut(&c,[(x,66),(x+6,67),(x+5,82),(x+spread+9,93),(x+spread+4,98),(x+spread,88)],C.pink)
        }
        layeredCut(&c,[(48,7),(55,14),(64,32),(68,51),(65,68),(56,77),(43,77),(33,69),(30,55),(34,32),(41,17)],C.fat)
        cut(&c,[(59,24),(64,32),(68,51),(65,68),(56,77),(48,76),(58,66),(61,47)],C.pink.opacity(0.5))
        oval(&c,40,66,6,7,C.creamHi,sides:14);oval(&c,41,66,3.5,4,C.inkFixed,sides:12)
        oval(&c,60,65,6,7,C.creamHi,sides:14);oval(&c,60,65,3.5,4,C.inkFixed,sides:12)
    }

    private func clam(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(43,84),(31,88),(28,81),(43,72),(58,72),(72,81),(68,88),(56,83)],C.tanSh)
        let rim:[(CGFloat,CGFloat)]=[(49,84),(35,73),(20,62),(9,49),(12,39),(20,34),(22,24),
            (33,22),(40,16),(51,19),(61,15),(70,22),(81,24),(84,34),(92,39),(92,50),(81,64),(64,78)]
        cut(&c,rim,C.tanSh)
        layeredCut(&c,rim.map{($0.0,$0.1-2)},C.onion)
        for (x,y) in [(CGFloat(15),CGFloat(40)),(28,28),(42,22),(58,21),(74,29),(86,41)] {
            cut(&c,[(48,79),(x-2,y),(x+3,y),(53,79)],C.tan.opacity(0.7))
        }
        cut(&c,[(46,77),(50,78),(59,83),(54,87),(48,86),(40,82)],C.cream)
    }

    // MARK: v2 유제품

    private func yogurt(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(22,30),(79,30),(71,89),(61,95),(36,92),(29,84)],C.creamLo)
        cut(&c,[(22,30),(66,32),(62,87),(53,93),(36,92),(29,84)],C.creamHi)
        cut(&c,[(26,50),(75,48),(71,78),(32,80)],C.pink)
        oval(&c,50,29,62,18,C.metalSh,sides:16)
        oval(&c,49,26,62,17,C.cream,sides:16)
        cut(&c,[(62,20),(73,17),(82,22),(78,28),(64,29)],C.metalHi)
        cut(&c,[(40,60),(47,56),(52,58),(58,56),(64,62),(59,71),(52,77),(45,73)],C.berry)
        cut(&c,[(43,57),(49,60),(50,53),(55,59),(62,56),(57,63),(48,63)],C.dGreen)
    }

    private func butter(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(5,55),(18,44),(29,48),(72,43),(95,55),(83,81),(55,85),(27,89),(14,75)],C.metalSh)
        cut(&c,[(5,55),(27,55),(35,78),(27,89),(14,75)],C.metalHi)
        cut(&c,[(72,43),(95,55),(82,61),(83,81),(66,78)],C.creamHi)
        cut(&c,[(25,43),(67,37),(79,48),(77,73),(34,81),(25,71)],C.yellowSh)
        layeredCut(&c,[(25,43),(67,37),(79,48),(36,55)],C.yellowHi)
        cut(&c,[(36,55),(79,48),(77,73),(34,81)],C.yellow)
        layeredCut(&c,[(43,26),(66,23),(76,32),(75,42),(51,46),(43,39)],C.yellowSh)
        cut(&c,[(43,26),(66,23),(76,32),(51,36)],C.yellowHi)
        cut(&c,[(51,36),(76,32),(75,42),(51,46)],C.yellow)
        cut(&c,[(14,75),(27,69),(34,81),(55,85),(27,89)],C.milkLbl)
    }

    // MARK: v2 저장식품·기타

    private func honey(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(30,27),(67,27),(68,36),(77,46),(78,82),(71,93),(32,94),(23,85),(22,48),(30,37)],C.yellowSh)
        cut(&c,[(29,44),(34,37),(61,37),(69,46),(70,83),(65,88),(36,89),(29,83)],C.carrotHi)
        layeredCut(&c,[(26,16),(69,15),(72,28),(68,34),(27,33),(24,27)],C.tanSh)
        seam(&c,29,21,66,21,2,C.tan)
        cut(&c,[(23,56),(77,55),(77,78),(23,80)],C.cream)
        for (x,y) in [(CGFloat(43),CGFloat(66)),(54,66),(49,75)] {
            oval(&c,x,y,11,11,C.yellowSh,sides:6)
            oval(&c,x,y,7,7,C.yellow,sides:6)
        }
        seam(&c,32,43,31,51,2,C.yellowHi)
    }

    private func dumpling(_ r: CGRect, _ ctx: inout GraphicsContext) {
var c = paperContext(ctx, in:r)
        cut(&c,[(11,68),(15,54),(26,41),(42,32),(58,30),(75,38),(87,51),(92,66),
                (86,78),(69,85),(46,88),(26,82)],C.tan)
        layeredCut(&c,[(11,64),(15,50),(26,37),(42,28),(58,26),(75,34),(87,47),(92,62),
                       (87,74),(69,81),(46,84),(26,78)],C.creamLo)
        cut(&c,[(25,62),(32,49),(43,43),(57,40),(71,45),(79,56),(80,68),(68,74),(49,77),(32,72)],C.onion)
        for (x,y,a) in [(CGFloat(20),CGFloat(48),-48.0),(32,37,-28.0),(46,31,-8.0),(61,31,15.0),(75,39,38.0),(85,51,56.0)] {
            var q=c;q.translateBy(x:x,y:y);q.rotate(by:.degrees(a))
            layeredCut(&q,[(-4,-2),(1,-5),(5,-1),(3,18),(-1,21),(-1,4)],C.creamHi)
        }
    }

    // MARK: v3 요리(메뉴) 글리프

    /// 김밥 — 썰어 놓은 **단면 두 조각**(뒤 조각 + 앞 조각). 바깥 김 링 + 밥 링 + 속재료 색면 5종.
    /// 두 링은 **각기 다른 정다각형을 각도까지 어긋나게** 겹친다(9각 김 ↔ 8각 밥) — 링 두께가
    /// 들쭉날쭉해져 컴퍼스가 아니라 손으로 오린 종이 링이 된다(§13.3 완전한 원 금지).
    /// 40pt(냉장고 행)에서도 **진초록 링 → 흰 링 → 알록달록 속**이라는 세 겹의 명도 대비만으로
    /// 김밥이 읽히도록, 디테일을 이 세 겹에만 건다(참깨·밥알 같은 미세 디테일은 넣지 않는다 —
    /// 작은 크기에서 링을 갉아먹고 큰 크기에서만 보이는 장식은 두 크기 사이의 정체성을 갈라놓는다).
    private func gimbap(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let W = r.width, H = r.height
        // 뒤 조각(좌상·작게) — 김 + 밥 두 겹뿐. 그늘 톤이라 앞 조각과 명도로 갈린다.
        let bx = r.midX - W * 0.26, by = r.midY - H * 0.24, bd = W * 0.56
        let backNori = facet(bx, by, bd, bd, 8, phase: -.pi / 2 + 0.30)
        shadow(&ctx, backNori, r)
        fill(&ctx, backNori, C.seaweedShd)
        fill(&ctx, facet(bx, by, bd * 0.66, bd * 0.66, 7, phase: -.pi / 2 + 0.9), C.riceSh)
        // 속재료 한 점만 — 뒤 조각도 속이 찬 롤이라는 힌트(앞 조각과 겹치지 않는 좌상단에 둔다).
        fill(&ctx, facet(bx - bd * 0.10, by - bd * 0.09, bd * 0.22, bd * 0.22, 5), C.carrotSh)

        // 앞 조각(주역, 우하)
        let fx = r.midX + W * 0.06, fy = r.midY + H * 0.07, fd = W * 0.84
        let nori = facet(fx, fy, fd, fd, 9, phase: -.pi / 2 + 0.12)
        shadow(&ctx, nori, r)
        fill(&ctx, nori, C.seaweedDk)
        shadeBody(&ctx, nori, dark: C.seaweedShd, split: 0.5)
        // 참기름 광택(각진 대각 면) — 밥보다 먼저 그려 김 링에만 남는다.
        var c = ctx; c.clip(to: nori)
        c.fill(poly([CGPoint(x: fx - fd * 0.40, y: fy - fd * 0.20),
                     CGPoint(x: fx - fd * 0.20, y: fy - fd * 0.44),
                     CGPoint(x: fx - fd * 0.04, y: fy - fd * 0.40),
                     CGPoint(x: fx - fd * 0.32, y: fy - fd * 0.04)]),
               with: .color(C.seaweedGloss.opacity(0.80)))

        // 밥 링
        let riceFace = facet(fx, fy, fd * 0.79, fd * 0.79, 8, phase: -.pi / 2 + 0.55)
        fill(&ctx, riceFace, C.rice)
        shadeBody(&ctx, riceFace, dark: C.riceSh, split: 0.52)

        // 속재료 — 십자로 벌려 사이사이에 밥이 비친다(실제 단면의 결). 색면은 평면으로 두고
        // 면분할은 하지 않는다: 40pt에서 한 조각이 6pt라 톤을 나누면 색이 탁해진다.
        let R = fd / 2
        let fillings: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, sides: Int, color: Color)] = [
            (-0.29, -0.30, 0.52, 0.50, 6, C.yellow),    // 계란 지단
            ( 0.30, -0.28, 0.50, 0.50, 5, C.pink),      // 햄 — 장난기 있는 오프컬러 액센트 1포인트
            ( 0.28,  0.31, 0.52, 0.50, 6, C.carrot),    // 당근
            (-0.30,  0.30, 0.50, 0.52, 5, C.mGreen),    // 시금치
        ]
        for f in fillings {
            fill(&ctx, facet(fx + R * f.x, fy + R * f.y, R * f.w, R * f.h, f.sides,
                             phase: f.x + f.y), f.color)
        }
        fill(&ctx, facet(fx, fy, R * 0.38, R * 0.38, 5, phase: 0.4), C.lGreen)   // 오이(중앙)
    }

    /// 일반 — 각진 뉴트럴 블롭.
    private func blob(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let body = facet(r.midX, r.midY, r.width * 0.84, r.height * 0.80, 9)
        shadow(&ctx, body, r)
        fill(&ctx, body, C.neutral)
        shadeBody(&ctx, body, dark: C.neutralSh, split: 0.5)
    }
}

// MARK: - Expanded ingredient library
private extension PaperSilhouette {
    func paperContext(_ ctx: GraphicsContext, in r: CGRect) -> GraphicsContext {
        var c = ctx
        c.translateBy(x: r.minX, y: r.minY)
        c.scaleBy(x: r.width / 100, y: r.height / 100)
        return c
    }

    /// A narrow cast edge belongs to an overlapping paper piece, not every color patch.
    func layeredCut(_ c: inout GraphicsContext, _ pts: [(CGFloat, CGFloat)], _ color: Color) {
        cut(&c, pts.map { ($0.0 + 0.35, $0.1 + 1.1) }, .black.opacity(0.13))
        cut(&c, pts, color)
    }

    func seed(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat,
              _ w: CGFloat, _ h: CGFloat, _ color: Color, angle: Double = 0) {
        var s = c
        s.translateBy(x:x,y:y)
        s.rotate(by:.degrees(angle))
        cut(&s,[(0,-h*0.5),(w*0.41,-h*0.12),(w*0.46,h*0.24),(w*0.23,h*0.46),
                (-w*0.14,h*0.5),(-w*0.43,h*0.29),(-w*0.4,-h*0.08)],color)
    }

    /// Coordinates are in a 100-unit square. All pieces still pass through `poly`,
    /// so the existing freshness rounding and the canvas pose apply to new art too.
    func cut(_ c: inout GraphicsContext, _ pts: [(CGFloat, CGFloat)], _ color: Color) {
        fill(&c, poly(pts.map { CGPoint(x: $0.0, y: $0.1) }), color)
    }
    func oval(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat,
              _ w: CGFloat, _ h: CGFloat, _ color: Color, sides: Int = 11) {
        fill(&c, facet(x, y, w, h, sides), color)
    }
    func seam(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat,
              _ endX: CGFloat, _ endY: CGFloat, _ width: CGFloat, _ color: Color) {
        let dx = endX - x, dy = endY - y, length = max(hypot(dx, dy), 0.01)
        let nx = -dy / length * width / 2, ny = dx / length * width / 2
        cut(&c, [(x + nx,y + ny),(endX + nx * 0.5,endY + ny * 0.5),
                 (endX - nx * 0.5,endY - ny * 0.5),(x - nx,y - ny)], color)
    }
    func paperLeaf(_ c: inout GraphicsContext, x: CGFloat, y: CGFloat,
                   width: CGFloat, height: CGFloat, color: Color) {
        cut(&c, [(x,y),(x-width*0.48,y-height*0.33),(x-width*0.5,y-height*0.68),
                 (x-width*0.25,y-height*0.89),(x+width*0.04,y-height),
                 (x+width*0.42,y-height*0.76),(x+width*0.50,y-height*0.43)], color)
        seam(&c, x,y,x+width*0.04,y-height*0.88,1.3,C.lGreen.opacity(0.65))
        for k in [CGFloat(0.28),0.48,0.68] {
            seam(&c,x,y-height*k,x-width*0.31,y-height*(k+0.13),0.7,C.lGreen.opacity(0.45))
            seam(&c,x,y-height*k,x+width*0.30,y-height*(k+0.15),0.7,C.lGreen.opacity(0.45))
        }
    }

    func additional(_ glyph: FoodGlyph, in r: CGRect, ctx: inout GraphicsContext) {
        var c = ctx
        c.translateBy(x: r.minX, y: r.minY)
        c.scaleBy(x: r.width / 100, y: r.height / 100)
        switch glyph {
        case .scallion:
            cut(&c,[(38,70),(19,8),(30,5),(48,55),(43,3),(56,2),(60,56),(71,8),(81,12),(63,74)],C.dGreen)
            cut(&c,[(38,70),(26,9),(33,8),(51,69)],C.mGreen)
            cut(&c,[(38,65),(63,66),(60,89),(43,91)],C.cream)
            cut(&c,[(40,60),(65,61),(63,71),(40,72)],C.lGreen)
            for i in 0..<4 { seam(&c,46+CGFloat(i)*3,89,42+CGFloat(i)*6,98,2,C.purple) }
        case .radish, .beet:
            paperLeaf(&c,x:43,y:41,width:25,height:37,color:C.dGreen)
            paperLeaf(&c,x:58,y:40,width:23,height:35,color:C.mGreen)
            let red = glyph == .beet
            cut(&c,[(27,39),(39,31),(61,32),(74,43),(77,63),(67,78),(54,90),(50,99),
                    (44,89),(30,76),(24,57)],red ? C.berry : C.cream)
            cut(&c,[(27,39),(39,31),(61,32),(74,43),(70,50),(55,46),(38,49)],red ? C.berrySh : C.lGreen)
            seam(&c,61,54,54,81,3,red ? C.pink : C.creamLo)
            for y in [CGFloat(61),72] { seam(&c,29,y,40,y+2,1.5,red ? C.berrySh : C.tan.opacity(0.5)) }
        case .lotusRoot:
            for (x,y,w) in [(CGFloat(39),CGFloat(38),CGFloat(58)),(61,64,60)] {
                oval(&c,x,y+3,w,w*0.83,C.tan)
                oval(&c,x,y,w,w*0.83,C.creamLo)
                for i in 0..<7 {
                    let a = CGFloat(i)*2 * .pi/7
                    oval(&c,x+cos(a)*w*0.29,y+sin(a)*w*0.23,w*0.15,w*0.13,C.tanSh,sides:7)
                }
                oval(&c,x,y,7,6,C.tan,sides:7)
            }
        case .burdock:
            for (x,y) in [(CGFloat(20),CGFloat(18)),(40,11),(57,21)] {
                cut(&c,[(x,y),(x+10,y-3),(x+23,70),(x+18,91),(x+12,74)],C.tan)
                seam(&c,x+4,y+6,x+17,78,2,C.brown.opacity(0.65))
                for k in 0..<4 { let yy=y+13+CGFloat(k)*12; seam(&c,x+5+CGFloat(k)*2,yy,x+12+CGFloat(k)*2,yy-2,1,C.creamLo) }
            }
        case .enoki:
            for i in 0..<9 {
                let x=CGFloat(16+i*8), y=CGFloat(22+(i*7)%17)
                seam(&c,42+CGFloat(i)*2,86,x,y,3.8,C.creamLo)
                oval(&c,x,y,15,13,C.cream)
                oval(&c,x-2,y-2,6,4,C.creamHi,sides:6)
            }
            cut(&c,[(37,77),(65,77),(64,91),(41,93)],C.tan.opacity(0.6))
        case .napa, .bokChoy:
            let napa = glyph == .napa
            for (x,y,w,h) in [(CGFloat(31),CGFloat(75),CGFloat(38),CGFloat(60)),(69,75,37,57),(50,89,43,79)] {
                paperLeaf(&c,x:x,y:y,width:w,height:h,color:napa ? C.lGreen : C.dGreen)
                cut(&c,[(x-8,y-6),(x-4,y-h*0.71),(x+3,y-h*0.77),(x+9,y-7),(x+5,y+6),(x-4,y+7)],napa ? C.cream : C.cabbageVein)
            }
        case .sprout:
            for i in 0..<7 {
                let x=CGFloat(18+i*10), y=CGFloat(17+(i*11)%19)
                let dx=CGFloat(i%2 == 0 ? -8 : 8)
                cut(&c,[(x-2,y+4),(x+3,y+2),(x+dx+6,68),(x+dx,88),(x+dx-4,90),(x+dx+2,66)],C.creamLo)
                oval(&c,x,y,16,12,C.yellow)
                seam(&c,x,y-3,x+2,y+3,1.4,C.yellowSh)
            }
        case .asparagus:
            for i in 0..<3 {
                let x=CGFloat(29+i*20), y=CGFloat(21-i*4)
                cut(&c,[(x-5,y+11),(x+5,y+9),(x+3,91),(x-4,93)],C.mGreen)
                cut(&c,[(x-7,y+12),(x-8,y),(x,y-16),(x+8,y),(x+6,y+13)],C.dGreen)
                for j in 0..<3 { cut(&c,[(x-6,y+CGFloat(j)*6-4),(x,y+CGFloat(j)*6),(x+6,y+CGFloat(j)*6-5)],C.leafHi) }
                seam(&c,x-2,y+18,x-2,85,1.8,C.lGreen)
            }
        case .celery:
            for (x,dx) in [(CGFloat(34),CGFloat(-12)),(50,0),(64,14)] {
                cut(&c,[(x-5,88),(x+5,87),(x+dx+4,32),(x+dx-3,30)],C.lGreen)
                paperLeaf(&c,x:x+dx,y:39,width:25,height:29,color:C.mGreen)
                seam(&c,x,83,x+dx,35,1.6,C.cabbageVein)
            }
        case .cauliflower:
            cut(&c,[(31,69),(43,61),(61,60),(72,69),(60,91),(43,92)],C.lGreen)
            paperLeaf(&c,x:34,y:86,width:32,height:48,color:C.mGreen)
            paperLeaf(&c,x:68,y:86,width:29,height:43,color:C.dGreen)
            for (x,y,w) in [(CGFloat(29),CGFloat(45),CGFloat(33)),(46,30,38),(69,37,34),(74,57,32),(47,57,45),(27,64,25)] {
                oval(&c,x,y,w,w*0.84,C.creamLo)
                oval(&c,x-3,y-4,w*0.72,w*0.64,C.cream)
            }
        case .pear:
            cut(&c,[(46,18),(58,17),(62,36),(76,53),(82,71),(72,87),(48,94),(26,83),(21,64),(32,42),(40,34)],C.yellow)
            cut(&c,[(58,22),(61,40),(75,57),(76,76),(61,88),(50,91),(61,69)],C.yellowSh)
            seam(&c,51,23,55,7,4,C.brown)
            paperLeaf(&c,x:57,y:20,width:21,height:15,color:C.dGreen)
            for (x,y) in [(CGFloat(36),CGFloat(64)),(42,78),(60,54),(66,72)] { oval(&c,x,y,1.6,2,C.tan,sides:5) }
        case .peach:
            cut(&c,[(49,27),(66,21),(84,36),(88,57),(78,77),(53,91),(29,80),(15,61),(17,39),(33,24)],C.pink)
            cut(&c,[(49,28),(34,30),(24,46),(26,66),(40,80),(49,84),(41,61),(44,44)],C.carrotHi.opacity(0.7))
            seam(&c,51,31,47,72,2,C.berrySh.opacity(0.6))
            paperLeaf(&c,x:49,y:30,width:29,height:23,color:C.mGreen)
        case .blueberry:
            for (x,y,w) in [(CGFloat(34),CGFloat(35),CGFloat(36)),(66,35,33),(49,62,40),(74,70,27),(22,69,26)] {
                oval(&c,x,y+2,w,w,C.fishDk)
                oval(&c,x-1,y-2,w*0.88,w*0.85,C.fish)
                var pts: [(CGFloat,CGFloat)] = []
                for i in 0..<10 { let a=CGFloat(i) * .pi/5, rr=w*(i%2 == 0 ? 0.16 : 0.075);pts.append((x+cos(a)*rr,y-5+sin(a)*rr)) }
                cut(&c,pts,C.fishDk)
            }
        case .cherry:
            seam(&c,30,57,61,13,3,C.dGreen);seam(&c,72,64,61,13,3,C.mGreen)
            paperLeaf(&c,x:60,y:23,width:29,height:18,color:C.mGreen)
            for (x,y) in [(CGFloat(29),CGFloat(69)),(72,75)] {
                oval(&c,x,y,36,37,C.berrySh);oval(&c,x-3,y-3,29,30,C.berry)
                seam(&c,x-9,y-8,x-11,y,3,C.pink)
            }
        case .kiwi:
            oval(&c,36,42,53,64,C.brown)
            oval(&c,59,62,63,61,C.tan)
            oval(&c,59,61,55,53,C.lGreen)
            oval(&c,59,61,15,24,C.cream)
            for i in 0..<12 { let a=CGFloat(i) * .pi/6;oval(&c,59+cos(a)*18,61+sin(a)*17,2.6,4,C.inkFixed,sides:5) }
        case .melon:
            oval(&c,43,43,67,67,C.lGreen)
            for x in [CGFloat(23),39,55] { seam(&c,x,18,x+16,69,1,C.creamLo) }
            for y in [CGFloat(27),42,57] { seam(&c,15,y,66,y+4,1,C.creamLo) }
            cut(&c,[(28,64),(83,40),(93,66),(76,86),(50,93)],C.mGreen)
            cut(&c,[(32,64),(82,46),(87,65),(73,80),(51,86)],C.cream)
            cut(&c,[(39,65),(80,51),(80,65),(67,76),(52,81)],C.carrotHi)
            seam(&c,44,43,44,8,3,C.dGreen)
        case .orange, .lime:
            let color = glyph == .lime ? C.mGreen : C.carrot
            oval(&c,39,43,64,65,color)
            paperLeaf(&c,x:44,y:17,width:28,height:14,color:C.dGreen)
            oval(&c,65,68,56,53,color)
            oval(&c,65,68,48,45,C.cream)
            for i in 0..<8 {
                let a=CGFloat(i) * .pi/4, b=a+0.61
                cut(&c,[(65+cos(a)*5,68+sin(a)*5),(65+cos(a)*20,68+sin(a)*18),
                        (65+cos(b)*20,68+sin(b)*18)],glyph == .lime ? C.lGreen : C.carrotHi)
            }
        case .salmon:
            cut(&c,[(13,37),(33,21),(77,31),(90,60),(71,83),(27,73),(13,59)],C.fishDk)
            cut(&c,[(13,32),(33,16),(77,26),(90,55),(71,77),(27,67),(13,53)],C.shrimp)
            for i in 0..<5 {
                let x=CGFloat(25+i*11)
                cut(&c,[(x,25),(x+4,25),(x+16,45),(x+7,66),(x+3,66),(x+12,45)],C.fat)
            }
        case .octopus:
            for i in 0..<6 {
                let x=CGFloat(16+i*13), dx=CGFloat(i<3 ? -7 : 7)
                cut(&c,[(40+CGFloat(i)*4,47),(48+CGFloat(i)*3,51),(x+5,75),(x+dx,86),(x+dx-8,83),(x-1,77)],C.purple)
                oval(&c,x,76,4,4,C.pink,sides:6)
            }
            oval(&c,51,35,49,56,C.pink)
            cut(&c,[(64,16),(73,31),(71,50),(55,63),(58,39)],C.berrySh.opacity(0.35))
        case .fishCake:
            for i in 0..<3 {
                let y=CGFloat(26+i*20), dx=CGFloat(i%2*8)
                cut(&c,[(14+dx,y),(73+dx,y-7),(84+dx,y+7),(23+dx,y+16)],C.tanSh)
                cut(&c,[(14+dx,y-4),(73+dx,y-11),(84+dx,y+3),(23+dx,y+12)],C.creamLo)
                for j in 0..<3 { oval(&c,30+dx+CGFloat(j)*16,y,3,2,C.tan,sides:5) }
            }
        case .kimchi:
            oval(&c,50,80,83,25,C.bowlB)
            for (x,y) in [(CGFloat(23),CGFloat(40)),(42,22),(59,34),(34,54)] {
                cut(&c,[(x,y),(x+17,y-8),(x+31,y+1),(x+25,y+24),(x+15,y+34),(x+3,y+23)],C.tomato)
                cut(&c,[(x+8,y+3),(x+14,y),(x+20,y+18),(x+16,y+30),(x+10,y+18)],C.creamLo)
                seam(&c,x+9,y+10,x+26,y+5,2,C.tomatoSh)
            }
            oval(&c,50,82,76,12,C.bowlBHi)
        case .riceCake:
            for (x,y) in [(CGFloat(17),CGFloat(32)),(43,20),(61,44),(26,61)] {
                cut(&c,[(x,y),(x+10,y-6),(x+22,y),(x+22,y+26),(x+13,y+34),(x+2,y+29)],C.creamLo)
                cut(&c,[(x,y),(x+10,y-6),(x+18,y),(x+18,y+24),(x+8,y+29),(x+2,y+26)],C.cream)
                oval(&c,x+10,y,19,11,C.creamHi)
            }
        case .flour: paperBag(&c)
        case .grains, .beans, .nuts, .walnut, .driedFruit, .olive:
            looseFood(glyph, &c)
        case .spice, .jar, .oil, .water, .juice, .salt, .peppercorn, .curryPowder, .wasabi:
            pantryContainer(glyph, &c)
        case .cinnamon:
            for (x,y) in [(CGFloat(22),CGFloat(31)),(44,18),(58,35)] {
                cut(&c,[(x,y),(x+14,y-6),(x+27,y+49),(x+13,y+56)],C.brown)
                seam(&c,x+4,y+3,x+17,y+49,3,C.tan)
                oval(&c,x+7,y,15,10,C.tanSh)
                oval(&c,x+7,y,7,4,C.brown,sides:7)
            }
        case .starAnise:
            for (x,y) in [(CGFloat(37),CGFloat(37)),(65,67)] {
                var pts:[(CGFloat,CGFloat)] = []
                for i in 0..<16 {
                    let a=CGFloat(i) * .pi/8, radius:CGFloat = i%2 == 0 ? 29 : 10
                    pts.append((x+cos(a)*radius,y+sin(a)*radius))
                }
                cut(&c,pts,C.brown)
                for i in 0..<8 { let a=CGFloat(i) * .pi/4;oval(&c,x+cos(a)*17,y+sin(a)*17,4,5,C.tan,sides:6) }
            }
        case .coffee, .tea:
            let color = glyph == .tea ? C.mGreen : C.brown
            oval(&c,77,55,31,32,C.bowlB)
            oval(&c,77,55,18,20,C.cream)
            cut(&c,[(15,35),(73,35),(69,76),(56,88),(28,86),(19,72)],C.bowlB)
            cut(&c,[(19,39),(28,41),(33,79),(25,75)],C.bowlBHi)
            oval(&c,44,36,58,27,C.cream)
            oval(&c,44,37,48,18,color)
            if glyph == .tea {
                seam(&c,57,39,65,65,1,C.cream)
                cut(&c,[(60,63),(72,63),(72,77),(60,77)],C.yellow)
            } else { oval(&c,40,36,29,9,C.tan) }
        case .chocolate:
            cut(&c,[(17,22),(68,13),(86,74),(34,90)],C.brown)
            for row in 0..<3 { for col in 0..<2 {
                let x=CGFloat(22+col*23+row*5),y=CGFloat(27+row*18-col*4)
                cut(&c,[(x,y),(x+19,y-4),(x+22,y+10),(x+3,y+14)],C.tanDk)
                seam(&c,x+3,y+2,x+16,y-1,1.3,C.tan)
            } }
            cut(&c,[(27,67),(78,53),(90,81),(38,96)],C.purple)
            cut(&c,[(27,67),(41,73),(52,62),(62,67),(78,53),(80,61),(32,77)],C.metalHi)
        case .cornDog:
            seam(&c,53,70,58,98,7,C.tan)
            oval(&c,46,43,45,71,C.carrot)
            cut(&c,[(34,18),(49,26),(35,38),(54,46),(39,58),(56,68)],C.yellow)
            for (x,y) in [(CGFloat(31),CGFloat(47)),(55,20),(58,58),(39,69)] { oval(&c,x,y,3,3,C.creamLo,sides:5) }
        case .ricePaper:
            oval(&c,47,53,83,72,C.tan)
            oval(&c,52,47,83,72,C.creamLo)
            oval(&c,51,44,78,65,C.cream)
            for (x,y) in [(CGFloat(31),CGFloat(27)),(62,27),(72,49),(32,58),(48,67)] { oval(&c,x,y,3,2,C.tan.opacity(0.5),sides:5) }
        case .iceCream:
            cut(&c,[(28,48),(72,48),(54,96),(46,93)],C.tan)
            for i in 0..<3 { seam(&c,32+CGFloat(i)*9,53,54+CGFloat(i)*3,77,1,C.creamLo) }
            oval(&c,49,34,60,48,C.pink)
            oval(&c,42,25,37,31,C.cream)
            oval(&c,65,43,17,18,C.pink)
        default: break // Only the explicit dispatch in draw(_:in:ctx:) enters here.
        }
    }

    func paperBag(_ c: inout GraphicsContext) {
        cut(&c,[(24,14),(72,14),(68,25),(80,84),(70,91),(22,88),(28,26)],C.tan)
        cut(&c,[(28,25),(67,25),(74,81),(26,82)],C.creamLo)
        cut(&c,[(24,14),(72,14),(68,23),(28,23)],C.breadSh)
        seam(&c,51,72,47,39,2,C.brown)
        for i in 0..<4 {
            let y=CGFloat(43+i*7)
            oval(&c,43,y,10,5,C.yellowSh,sides:5)
            oval(&c,54,y+3,10,5,C.yellowSh,sides:5)
        }
    }

    func looseFood(_ g: FoodGlyph, _ c: inout GraphicsContext) {
        let spots: [(CGFloat,CGFloat)] = [(32,28),(62,24),(78,48),(49,50),(21,58),(42,77),(71,76)]
        for (i,p) in spots.enumerated() {
            let (x,y)=p
            switch g {
            case .grains:
                oval(&c,x,y,24,12,i%2 == 0 ? C.tan : C.creamLo,sides:7)
                seam(&c,x-8,y,x+7,y-1,1,C.breadSh)
            case .beans:
                cut(&c,[(x-11,y-7),(x-4,y-12),(x+6,y-10),(x+12,y-2),(x+8,y+10),
                        (x-3,y+12),(x-10,y+5),(x-5,y)],i%2 == 0 ? C.brown : C.tanSh)
                seam(&c,x-4,y-3,x-1,y+4,2,C.creamLo)
            case .nuts:
                cut(&c,[(x-12,y+5),(x-8,y-7),(x+2,y-15),(x+10,y-7),(x+12,y+4),(x+4,y+12),(x-6,y+11)],C.tan)
                seam(&c,x,y-9,x-2,y+8,1.7,C.brown)
                seam(&c,x+5,y-4,x+4,y+7,1,C.creamLo)
            case .walnut:
                cut(&c,[(x-13,y-7),(x-6,y-12),(x-1,y-8),(x+5,y-14),(x+13,y-7),
                        (x+10,y),(x+15,y+6),(x+7,y+13),(x+1,y+8),(x-7,y+13),(x-14,y+5)],C.tan)
                seam(&c,x,y-8,x,y+9,2.5,C.brown)
                seam(&c,x-8,y-3,x-4,y+5,2,C.tanSh)
                seam(&c,x+7,y-4,x+5,y+6,2,C.creamLo)
            case .olive:
                oval(&c,x,y,23,28,i%2 == 0 ? C.dGreen : C.mGreen)
                oval(&c,x,y-6,9,7,C.inkFixed,sides:7)
                oval(&c,x,y-6,5,4,C.tomato,sides:6)
            default:
                oval(&c,x,y,22,29,C.purple,sides:9)
                seam(&c,x-4,y-8,x-5,y+7,2,C.pink.opacity(0.55))
                seam(&c,x+3,y-6,x+5,y+5,1.5,C.brown)
            }
        }
    }

    func pantryContainer(_ g: FoodGlyph, _ c: inout GraphicsContext) {
        if g == .juice {
            cut(&c,[(27,19),(62,13),(77,29),(76,88),(26,88)],C.creamLo)
            cut(&c,[(62,13),(77,29),(76,88),(63,80)],C.carrotSh)
            cut(&c,[(27,35),(63,34),(63,80),(27,84)],C.carrot)
            oval(&c,45,59,25,28,C.yellow)
            paperLeaf(&c,x:48,y:50,width:17,height:13,color:C.dGreen)
            seam(&c,29,17,62,12,4,C.cream)
            return
        }
        let tall = g == .oil || g == .water
        let top: CGFloat = tall ? 32 : 26
        let left: CGFloat = tall ? 29 : 19, right: CGFloat = tall ? 71 : 81
        let glass = g == .oil ? C.dGreen : (g == .water ? C.fishHi : C.creamLo)
        cut(&c,[(left,top+8),(38,top),(38,13),(62,13),(62,top),(right,top+8),
                (right,85),(right-8,92),(left+7,92),(left,85)],glass)
        let food: Color
        switch g {
        case .spice: food = C.tomatoSh
        case .salt: food = C.creamHi
        case .peppercorn: food = C.inkFixed
        case .curryPowder: food = C.yellowSh
        case .wasabi: food = C.lGreen
        case .jar: food = C.brown
        default: food = C.yellow
        }
        if !tall { cut(&c,[(left+4,46),(right-4,46),(right-4,82),(right-10,86),(left+8,86)],food) }
        cut(&c,[(34,7),(65,7),(66,20),(34,20)],g == .water ? C.milkLbl : C.brown)
        seam(&c,left+7,top+13,left+7,76,3,C.cream.opacity(0.7))
        cut(&c,[(left+3,53),(right-3,53),(right-3,72),(left+3,72)],C.cream)
        if g == .oil { paperLeaf(&c,x:51,y:70,width:13,height:15,color:C.mGreen) }
        else if g == .water { cut(&c,[(50,56),(43,66),(46,70),(53,70),(57,66)],C.milkLbl) }
        else {
            oval(&c,50,62,13,13,food,sides:9)
            if g == .spice { for x in [CGFloat(42),50,58] { oval(&c,x,13,2,2,C.cream,sides:5) } }
        }
    }
}
