import SwiftUI

/// 요리 일러스트(§13.7) — 재료 글리프(`PaperSilhouette`)와 **같은 컷페이퍼 문법**으로 완성된 요리를 그린다:
/// 곡선 대신 직선 면(5~12각), 몸통 2~3톤 면분할, 아웃라인 없음, 조각마다 옅은 종이 그림자,
/// 실루엣 전체에 단일 외곽 그림자. 색은 OKLCH 정본 고정색(`DishPalette`).
///
/// **별도 파일인 이유**: `PaperSilhouette`는 재료 52종 + 시듦 처리로 이미 1.8k줄이다. 요리는 축이
/// 다르고(원형 15 × 변주) 시듦도 없어, 한 파일에 합치면 두 축이 서로를 가린다.
/// 기하 헬퍼(`poly`·`facet`·`shadeBody`)는 이름·의미를 그대로 옮겼다 — `PaperSilhouette` 쪽 원본은
/// 시듦 라운딩(`look.rounding`) 분기를 품고 있어 그대로 꺼내 쓰면 요리에 불필요한 상태가 딸려온다.
struct DishSilhouette: View {
    let look: DishLook
    /// false면 외곽 그림자 필터를 끈다 — 오프스크린 래스터 비교가 블러에 흔들리지 않게
    /// (`PaperSilhouette.shadowed` 선례).
    var shadowed: Bool = true

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.07,
                                                              dy: size.height * 0.07)
            var shaded = ctx
            if shadowed {
                shaded.addFilter(.shadow(color: .black.opacity(0.16),
                                         radius: size.width * 0.018, x: 0, y: size.height * 0.015))
            }
            shaded.drawLayer { layer in
                draw(in: r, ctx: &layer)
                FoodPaperGrain.overlay(in: r, context: &layer)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Dispatch

    func draw(in r: CGRect, ctx: inout GraphicsContext) {
        switch look.archetype {
        case .stewPot:       stewPot(r, &ctx)
        case .soupBowl:      soupBowl(r, &ctx)
        case .riceBowl:      riceBowl(r, &ctx)
        case .noodleBowl:    noodleBowl(r, &ctx)
        case .pastaPlate:    pastaPlate(r, &ctx)
        case .skillet:       skillet(r, &ctx)
        case .platedMound:   platedMound(r, &ctx)
        case .grillPlate:    grillPlate(r, &ctx)
        case .discStack:     discStack(r, &ctx)
        case .rollSlices:    rollSlices(r, &ctx)
        case .sandwichStack: sandwichStack(r, &ctx)
        case .foldedWrap:    foldedWrap(r, &ctx)
        case .curryPlate:    curryPlate(r, &ctx)
        case .sideBowl:      sideBowl(r, &ctx)
        case .bakeDish:      bakeDish(r, &ctx)
        case .openToast, .riceTriangle, .skewers, .drinkGlass, .waffle, .wholeFish, .salmonFillet:
            platedSpecialty(r, &ctx)
        }
    }

    // MARK: Helpers (컷페이퍼 기하 — PaperSilhouette와 같은 문법)

    private func fill(_ ctx: inout GraphicsContext, _ p: Path, _ color: Color) {
        ctx.fill(p, with: .color(color))
    }

    /// 종이 그림자(아래로 옅게) — 조각이 배경 위에 얹힌 느낌.
    private func shadow(_ ctx: inout GraphicsContext, _ p: Path, _ r: CGRect) {
        ctx.fill(p.applying(.init(translationX: 0, y: r.height * 0.02)),
                 with: .color(.black.opacity(0.08)))
    }

    /// 닫힌 다각형(직선 면) — 모든 면이 이 한 곳을 지난다.
    private func poly(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let f = pts.first else { return p }
        p.move(to: f)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        p.closeSubpath()
        return p
    }

    /// 각진 N각형(타원 근사) — 곡선 대신 직선 면으로 종이 컷 느낌.
    private func facet(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat,
                       _ sides: Int, phase: CGFloat = -.pi / 2) -> Path {
        var pts: [CGPoint] = []
        for i in 0..<sides {
            let a = phase + CGFloat(i) / CGFloat(sides) * 2 * .pi
            pts.append(CGPoint(x: cx + cos(a) * w / 2, y: cy + sin(a) * h / 2))
        }
        return poly(pts)
    }

    /// 각진 고리 — 바깥 면 안에 작은 면을 겹쳐 두고 **even-odd**로 칠하면 가운데가 뚫린다.
    /// 파 링(고명)과 파스타 네스트(감긴 면)가 이 하나를 공유한다.
    private func ringPath(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat,
                          _ sides: Int, thickness: CGFloat, phase: CGFloat = -.pi / 2) -> Path {
        var p = facet(cx, cy, w, h, sides, phase: phase)
        p.addPath(facet(cx, cy, max(w - thickness * 2, 0.01), max(h - thickness * 2, 0.01),
                        sides, phase: phase))
        return p
    }

    private func fillRing(_ ctx: inout GraphicsContext, _ p: Path, _ color: Color) {
        ctx.fill(p, with: .color(color), style: FillStyle(eoFill: true))
    }

    /// 각진 잎/칼날 한 장(base→tip, 가운데가 가장 넓은 다이아 블레이드).
    private func angularLeaf(_ base: CGPoint, _ tip: CGPoint, _ halfW: CGFloat) -> Path {
        let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
        let dx = tip.y - base.y, dy = -(tip.x - base.x)
        let len = max(hypot(dx, dy), 0.0001)
        let nx = dx / len * halfW, ny = dy / len * halfW
        return poly([base,
                     CGPoint(x: mid.x + nx, y: mid.y + ny),
                     tip,
                     CGPoint(x: mid.x - nx, y: mid.y - ny)])
    }

    /// 몸통 면분할(2~3톤) — body로 클립하고 우하 어두운 면 + 좌상 밝은 면을 얹는다.
    private func shadeBody(_ ctx: inout GraphicsContext, _ body: Path,
                           dark: Color, light: Color? = nil, split: CGFloat = 0.42) {
        let b = body.boundingRect
        guard b.width > 0, b.height > 0 else { return }
        var c = ctx
        c.clip(to: body)
        c.fill(poly([CGPoint(x: b.minX - 2, y: b.maxY + 2),
                     CGPoint(x: b.maxX + 2, y: b.minY + b.height * split),
                     CGPoint(x: b.maxX + 2, y: b.maxY + 2)]), with: .color(dark))
        if let light {
            c.fill(poly([CGPoint(x: b.minX - 2, y: b.minY - 2),
                         CGPoint(x: b.minX + b.width * 0.6, y: b.minY - 2),
                         CGPoint(x: b.minX - 2, y: b.minY + b.height * 0.64)]), with: .color(light))
        }
    }

    /// 색을 하나만 아는 작은 조각(고명·내용물)의 면분할 — 짝이 되는 어두운 색을 팔레트에 늘리지 않고
    /// 검정 12%를 우하단에 얹는다. 조각이 작아 색상 이동이 눈에 띄지 않고, 팔레트가 두 배로 안 는다.
    private func chipShade(_ ctx: inout GraphicsContext, _ body: Path, split: CGFloat = 0.5) {
        shadeBody(&ctx, body, dark: .black.opacity(0.12), split: split)
    }

    /// 그릇 재질 3톤.
    private var tone: (base: Color, dark: Color, light: Color) {
        switch look.vessel {
        case .clay:      (DishPalette.clayBase, DishPalette.clayDark, DishPalette.clayLight)
        case .porcelain: (DishPalette.porcBase, DishPalette.porcDark, DishPalette.porcLight)
        case .indigo:    (DishPalette.indigoBase, DishPalette.indigoDark, DishPalette.indigoLight)
        case .wood:      (DishPalette.woodBase, DishPalette.woodDark, DishPalette.woodLight)
        case .iron:      (DishPalette.ironBase, DishPalette.ironDark, DishPalette.ironLight)
        case .glaze:     (DishPalette.glazeBase, DishPalette.glazeDark, DishPalette.glazeLight)
        }
    }

    /// 그릇의 **앞쪽 테두리** — 봉우리(밥·면)를 먼저 그린 뒤 이걸 덮으면 "그릇 안에 담김"이 된다.
    /// 윗변이 가운데로 처진 다각형이라 뒤쪽 테두리는 봉우리에 가려진 것처럼 읽힌다.
    private func bowlFront(_ cx: CGFloat, _ rim: CGFloat, _ halfW: CGFloat,
                           _ depth: CGFloat, sag: CGFloat) -> Path {
        poly([CGPoint(x: cx - halfW, y: rim),
              CGPoint(x: cx - halfW * 0.80, y: rim + depth * 0.55),
              CGPoint(x: cx - halfW * 0.42, y: rim + depth),
              CGPoint(x: cx + halfW * 0.42, y: rim + depth),
              CGPoint(x: cx + halfW * 0.80, y: rim + depth * 0.55),
              CGPoint(x: cx + halfW, y: rim),
              CGPoint(x: cx + halfW * 0.50, y: rim + sag),
              CGPoint(x: cx - halfW * 0.50, y: rim + sag)])
    }

    /// 납작한 접시(각진 타원 두 겹) — 바깥 테두리 + 안쪽 우묵한 면.
    /// 테두리를 **한 톤 낮춰** 칠한다: 백자 접시를 크림 종이 배경(L 0.99) 위에 밝은 톤으로 놓으면
    /// 배경에 녹아 음식만 허공에 뜬 것처럼 보인다 — 접시가 먼저 실루엣으로 읽혀야 요리로 읽힌다.
    private func plate(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat,
                       _ w: CGFloat, _ h: CGFloat) {
        let t = tone
        let rimP = facet(cx, cy, w, h, 12)
        shadow(&ctx, rimP, CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
        fill(&ctx, rimP, t.dark)
        let well = facet(cx, cy - h * 0.02, w * 0.82, h * 0.70, 12)
        fill(&ctx, well, t.base)
        shadeBody(&ctx, well, dark: t.dark, light: t.light, split: 0.36)
    }

    // MARK: 고명

    /// 원형이 넘긴 슬롯에 1차·2차 고명을 번갈아 놓는다 — 슬롯 순서가 곧 배치 우선순위다.
    private func marks(_ ctx: inout GraphicsContext, _ slots: [(CGPoint, CGFloat)]) {
        let seq: [DishMark?] = [look.mark, look.mark2, look.mark, look.mark2]
        for (i, slot) in slots.enumerated() where i < seq.count {
            guard let m = seq[i] else { continue }
            mark(&ctx, m, at: slot.0, size: slot.1)
        }
    }

    private func mark(_ ctx: inout GraphicsContext, _ m: DishMark, at p: CGPoint, size s: CGFloat) {
        switch m.shape {
        case .cube:
            let q = poly([CGPoint(x: p.x - s * 0.42, y: p.y - s * 0.34),
                          CGPoint(x: p.x + s * 0.40, y: p.y - s * 0.42),
                          CGPoint(x: p.x + s * 0.46, y: p.y + s * 0.36),
                          CGPoint(x: p.x - s * 0.36, y: p.y + s * 0.44)])
            fill(&ctx, q, m.color); chipShade(&ctx, q, split: 0.55)
        case .ring:
            let ring = ringPath(p.x, p.y, s * 0.90, s * 0.62, 8, thickness: s * 0.19)
            fill(&ctx, facet(p.x, p.y, s * 0.54, s * 0.30, 7), DishPalette.markHole)
            fillRing(&ctx, ring, m.color)
        case .baton:
            let q = poly([CGPoint(x: p.x - s * 0.62, y: p.y - s * 0.10),
                          CGPoint(x: p.x + s * 0.56, y: p.y - s * 0.28),
                          CGPoint(x: p.x + s * 0.62, y: p.y + s * 0.06),
                          CGPoint(x: p.x - s * 0.56, y: p.y + s * 0.24)])
            fill(&ctx, q, m.color); chipShade(&ctx, q, split: 0.5)
        case .disc:
            let d = facet(p.x, p.y, s * 0.92, s * 0.56, 9)
            fill(&ctx, d, m.color); chipShade(&ctx, d, split: 0.52)
        case .dot:
            fill(&ctx, facet(p.x - s * 0.26, p.y - s * 0.16, s * 0.30, s * 0.24, 5), m.color)
            fill(&ctx, facet(p.x + s * 0.24, p.y + s * 0.10, s * 0.34, s * 0.26, 5), m.color)
            fill(&ctx, facet(p.x + s * 0.02, p.y - s * 0.34, s * 0.26, s * 0.22, 5), m.color)
        case .leafy:
            let leaf = poly([CGPoint(x:p.x-s*0.5,y:p.y+s*0.2),
                             CGPoint(x:p.x-s*0.46,y:p.y-s*0.22),
                             CGPoint(x:p.x-s*0.08,y:p.y-s*0.46),
                             CGPoint(x:p.x+s*0.51,y:p.y-s*0.39),
                             CGPoint(x:p.x+s*0.40,y:p.y+s*0.13),
                             CGPoint(x:p.x+s*0.03,y:p.y+s*0.34)])
            fill(&ctx, leaf, m.color); chipShade(&ctx, leaf, split:0.6)
            fill(&ctx, poly([CGPoint(x:p.x-s*0.45,y:p.y+s*0.22),
                             CGPoint(x:p.x+s*0.40,y:p.y-s*0.32),
                             CGPoint(x:p.x+s*0.15,y:p.y-s*0.10),
                             CGPoint(x:p.x-s*0.37,y:p.y+s*0.25)]),
                 DishPalette.cabbagePale.opacity(0.65))
        case .yolk:
            fill(&ctx, facet(p.x, p.y, s * 1.40, s * 1.15, 11), DishPalette.eggWhite)
            let y = facet(p.x, p.y, s * 0.92, s * 0.80, 10)
            fill(&ctx, y, m.color)
            fill(&ctx, facet(p.x - s * 0.14, p.y - s * 0.16, s * 0.34, s * 0.28, 6),
                 DishPalette.markHole.opacity(0.55))
            chipShade(&ctx, y, split: 0.62)
        case .strip:
            let q = poly([CGPoint(x: p.x - s * 0.56, y: p.y - s * 0.06),
                          CGPoint(x: p.x - s * 0.10, y: p.y - s * 0.38),
                          CGPoint(x: p.x + s * 0.58, y: p.y - s * 0.18),
                          CGPoint(x: p.x + s * 0.30, y: p.y + s * 0.34),
                          CGPoint(x: p.x - s * 0.34, y: p.y + s * 0.30)])
            fill(&ctx, q, m.color); chipShade(&ctx, q, split: 0.48)
        case .shrimp, .eggHalf, .bananaSlice, .mushroom, .citrusSlice, .tomatoSlice, .floret, .clam, .lotus, .dumpling, .berry:
            foodMark(&ctx, m, at: p, size: s)
        case .wedge:
            let q = poly([CGPoint(x: p.x - s * 0.52, y: p.y + s * 0.42),
                          CGPoint(x: p.x + s * 0.52, y: p.y + s * 0.30),
                          CGPoint(x: p.x + s * 0.04, y: p.y - s * 0.52)])
            fill(&ctx, q, m.color); chipShade(&ctx, q, split: 0.5)
        }
    }

    // MARK: - 냄비 (찌개·탕·조림)

    private func stewPot(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let t = tone, cx = r.midX, w = r.width, h = r.height
        // 입구를 낮고 넓게 잡는다 — 냄비 벽이 깊으면 그릇만 커다란 어두운 상자가 되고
        // 정작 요리를 가르는 국물면이 실 한 줄로 줄어든다(원형은 같아도 요리가 안 갈린다).
        let rim = r.minY + h * 0.40, bot = r.maxY - h * 0.08
        steam(&ctx, r, rim: rim)
        // 귀 손잡이 — 몸통보다 먼저 깔아 몸통이 위를 덮게(붙어 있는 인상).
        for s in [CGFloat(-1), CGFloat(1)] {
            let ex = cx + s * w * 0.40
            fill(&ctx, poly([CGPoint(x: ex, y: rim + h * 0.02),
                             CGPoint(x: ex + s * w * 0.12, y: rim + h * 0.055),
                             CGPoint(x: ex + s * w * 0.11, y: rim + h * 0.16),
                             CGPoint(x: ex, y: rim + h * 0.15)]), t.dark)
        }
        let body = poly([CGPoint(x: cx - w * 0.42, y: rim),
                         CGPoint(x: cx + w * 0.42, y: rim),
                         CGPoint(x: cx + w * 0.36, y: bot - h * 0.07),
                         CGPoint(x: cx + w * 0.26, y: bot),
                         CGPoint(x: cx - w * 0.26, y: bot),
                         CGPoint(x: cx - w * 0.36, y: bot - h * 0.07)])
        shadow(&ctx, body, r)
        fill(&ctx, body, t.base)
        shadeBody(&ctx, body, dark: t.dark, light: t.light, split: 0.38)
        fill(&ctx, facet(cx, rim, w * 0.88, h * 0.34, 12), t.light)      // 전(입구 테두리)
        let broth = facet(cx, rim + h * 0.008, w * 0.74, h * 0.28, 12)
        fill(&ctx, broth, look.fill)
        chipShade(&ctx, broth, split: 0.58)
        var c = ctx; c.clip(to: broth)
        marks(&c, [(CGPoint(x: cx - w * 0.16, y: rim + h * 0.005), w * 0.20),
                   (CGPoint(x: cx + w * 0.15, y: rim + h * 0.042), w * 0.19),
                   (CGPoint(x: cx + w * 0.01, y: rim - h * 0.044), w * 0.16)])
    }

    /// 김 — 각진 지그재그 리본 둘. 냄비에만 붙여 "국(대접)"과 "찌개(냄비)"를 실루엣으로 가른다.
    private func steam(_ ctx: inout GraphicsContext, _ r: CGRect, rim: CGFloat) {
        let cx = r.midX, w = r.width
        let top = r.minY + r.height * 0.01, bottom = rim - r.height * 0.05
        let span = max(bottom - top, 0.01)
        for (dx, k) in [(CGFloat(-0.15), CGFloat(1)), (CGFloat(0.11), CGFloat(0.76))] {
            let x = cx + w * dx
            fill(&ctx, poly([CGPoint(x: x, y: bottom),
                             CGPoint(x: x + w * 0.055 * k, y: bottom - span * 0.34),
                             CGPoint(x: x - w * 0.030 * k, y: bottom - span * 0.66),
                             CGPoint(x: x + w * 0.020 * k, y: top),
                             CGPoint(x: x + w * 0.075 * k, y: top + span * 0.10),
                             CGPoint(x: x + w * 0.038 * k, y: bottom - span * 0.60),
                             CGPoint(x: x + w * 0.100 * k, y: bottom - span * 0.28),
                             CGPoint(x: x + w * 0.062 * k, y: bottom)]), DishPalette.steam)
        }
    }

    // MARK: - 대접 (국·수프·죽)

    private func soupBowl(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let t = tone, cx = r.midX, w = r.width, h = r.height
        // 대접은 **넓고 얕다**. 밑을 좁게 조이고 굽을 길게 빼면 깔때기·전등갓으로 읽힌다
        // (밑변 폭이 입구의 60% 아래로 내려가는 순간 그릇이 아니게 된다).
        let rim = r.minY + h * 0.31, bodyBot = rim + h * 0.34
        fill(&ctx, poly([CGPoint(x: cx - w * 0.21, y: bodyBot - h * 0.01),   // 굽(낮고 넓게)
                         CGPoint(x: cx + w * 0.21, y: bodyBot - h * 0.01),
                         CGPoint(x: cx + w * 0.17, y: bodyBot + h * 0.055),
                         CGPoint(x: cx - w * 0.17, y: bodyBot + h * 0.055)]), t.dark)
        let body = poly([CGPoint(x: cx - w * 0.47, y: rim),
                         CGPoint(x: cx + w * 0.47, y: rim),
                         CGPoint(x: cx + w * 0.41, y: rim + h * 0.15),
                         CGPoint(x: cx + w * 0.28, y: bodyBot),
                         CGPoint(x: cx - w * 0.28, y: bodyBot),
                         CGPoint(x: cx - w * 0.41, y: rim + h * 0.15)])
        shadow(&ctx, body, r)
        fill(&ctx, body, t.base)
        shadeBody(&ctx, body, dark: t.dark, light: t.light, split: 0.40)
        // 국물면을 넉넉히 잡는다 — 수면이 실 한 줄이면 고명이 클립에 잘려 조각만 남고,
        // 아홉 개 국·수프가 전부 "색만 다른 빈 그릇"이 된다(변주 축이 렌더에서 사라진다).
        fill(&ctx, facet(cx, rim, w * 0.96, h * 0.36, 12), t.light)
        let broth = facet(cx, rim + h * 0.008, w * 0.82, h * 0.29, 12)
        fill(&ctx, broth, look.fill)
        chipShade(&ctx, broth, split: 0.58)
        var c = ctx; c.clip(to: broth)
        marks(&c, [(CGPoint(x: cx - w * 0.19, y: rim + h * 0.005), w * 0.20),
                   (CGPoint(x: cx + w * 0.17, y: rim + h * 0.040), w * 0.19),
                   (CGPoint(x: cx + w * 0.01, y: rim - h * 0.045), w * 0.17)])
    }

    // MARK: - 덮밥 공기

    private func riceBowl(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let t = tone, cx = r.midX, w = r.width, h = r.height
        let rim = r.minY + h * 0.44
        let mound = poly([CGPoint(x: cx - w * 0.35, y: rim),
                          CGPoint(x: cx - w * 0.23, y: rim - h * 0.17),
                          CGPoint(x: cx - w * 0.02, y: rim - h * 0.25),
                          CGPoint(x: cx + w * 0.21, y: rim - h * 0.16),
                          CGPoint(x: cx + w * 0.35, y: rim)])
        shadow(&ctx, mound, r)
        fill(&ctx, mound, look.fill)
        chipShade(&ctx, mound, split: 0.62)
        // 토핑 — 봉우리 위쪽을 덮는 각진 면(덮밥의 핵심 신호).
        if let accent = look.accent {
            var c = ctx; c.clip(to: mound)
            let top = poly([CGPoint(x: cx - w * 0.33, y: rim - h * 0.035),
                            CGPoint(x: cx - w * 0.22, y: rim - h * 0.175),
                            CGPoint(x: cx - w * 0.01, y: rim - h * 0.255),
                            CGPoint(x: cx + w * 0.22, y: rim - h * 0.155),
                            CGPoint(x: cx + w * 0.33, y: rim - h * 0.020),
                            CGPoint(x: cx + w * 0.13, y: rim - h * 0.095),
                            CGPoint(x: cx - w * 0.09, y: rim - h * 0.060)])
            c.fill(top, with: .color(accent))
            chipShade(&c, top, split: 0.6)
        }
        var mc = ctx; mc.clip(to: mound)
        marks(&mc, [(CGPoint(x: cx - w * 0.17, y: rim - h * 0.115), w * 0.20),
                    (CGPoint(x: cx + w * 0.15, y: rim - h * 0.135), w * 0.19),
                    (CGPoint(x: cx + w * 0.01, y: rim - h * 0.055), w * 0.17)])
        let front = bowlFront(cx, rim, w * 0.37, h * 0.42, sag: h * 0.055)
        fill(&ctx, front, t.base)
        shadeBody(&ctx, front, dark: t.dark, light: t.light, split: 0.34)
        fill(&ctx, poly([CGPoint(x: cx - w * 0.37, y: rim),                   // 앞 테두리 하이라이트
                         CGPoint(x: cx + w * 0.37, y: rim),
                         CGPoint(x: cx + w * 0.185, y: rim + h * 0.055),
                         CGPoint(x: cx - w * 0.185, y: rim + h * 0.055),
                         CGPoint(x: cx - w * 0.30, y: rim + h * 0.028)]), t.light)
    }

    // MARK: - 면기

    private func noodleBowl(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let t = tone, cx = r.midX, w = r.width, h = r.height
        let rim = r.minY + h * 0.59
        // 뒤 테두리 + 국물(있을 때만) — 국물 유무가 국물면/볶음면을 가르는 축이다.
        fill(&ctx, facet(cx, rim, w * 0.80, h * 0.15, 11), t.light)
        if let broth = look.accent {
            let disc = facet(cx, rim + h * 0.006, w * 0.70, h * 0.12, 11)
            fill(&ctx, disc, broth)
            chipShade(&ctx, disc, split: 0.6)
        }
        chopsticks(&ctx, r, rim: rim)
        let mound = poly([CGPoint(x: cx - w * 0.32, y: rim + h * 0.015),
                          CGPoint(x: cx - w * 0.24, y: rim - h * 0.14),
                          CGPoint(x: cx - w * 0.04, y: rim - h * 0.21),
                          CGPoint(x: cx + w * 0.19, y: rim - h * 0.13),
                          CGPoint(x: cx + w * 0.31, y: rim + h * 0.015)])
        fill(&ctx, mound, look.fill)
        chipShade(&ctx, mound, split: 0.66)
        var c = ctx; c.clip(to: mound)
        for i in 0..<7 {
            let y = rim - h * (0.04 + CGFloat(i) * 0.025)
            let path = ringPath(cx + w * (i % 2 == 0 ? -0.02 : 0.025), y,
                                w * (0.54 - CGFloat(i) * 0.027), h * 0.12, 12,
                                thickness: w * 0.014)
            fillRing(&c, path, i % 2 == 0 ? .white.opacity(0.40) : .black.opacity(0.12))
        }
        marks(&c, [(CGPoint(x: cx - w * 0.16, y: rim - h * 0.095), w * 0.19),
                   (CGPoint(x: cx + w * 0.14, y: rim - h * 0.100), w * 0.18),
                   (CGPoint(x: cx + w * 0.00, y: rim - h * 0.035), w * 0.16)])
        let front = bowlFront(cx, rim, w * 0.40, h * 0.30, sag: h * 0.060)
        fill(&ctx, front, t.base)
        shadeBody(&ctx, front, dark: t.dark, light: t.light, split: 0.34)
        fill(&ctx, poly([CGPoint(x: cx - w * 0.40, y: rim),
                         CGPoint(x: cx + w * 0.40, y: rim),
                         CGPoint(x: cx + w * 0.20, y: rim + h * 0.060),
                         CGPoint(x: cx - w * 0.20, y: rim + h * 0.060),
                         CGPoint(x: cx - w * 0.32, y: rim + h * 0.030)]), t.light)
    }

    /// 젓가락 — 오른쪽 위에서 면기로 내려꽂힌 나무 두 짝. 면 요리를 한눈에 못 박는 신호다.
    private func chopsticks(_ ctx: inout GraphicsContext, _ r: CGRect, rim: CGFloat) {
        let cx = r.midX, w = r.width, h = r.height
        for (i, off) in [CGFloat(0), CGFloat(0.055)].enumerated() {
            let tipX = cx + w * (0.06 + off), tipY = rim - h * 0.09
            let topX = cx + w * (0.34 + off * 1.4), topY = r.minY + h * 0.01
            let dx = topX - tipX, dy = topY - tipY
            let len = max(hypot(dx, dy), 0.001)
            let nx = -dy / len * w * 0.021, ny = dx / len * w * 0.021
            let stick = poly([CGPoint(x: tipX + nx * 0.45, y: tipY + ny * 0.45),
                              CGPoint(x: topX + nx, y: topY + ny),
                              CGPoint(x: topX - nx, y: topY - ny),
                              CGPoint(x: tipX - nx * 0.45, y: tipY - ny * 0.45)])
            fill(&ctx, stick, i == 0 ? DishPalette.woodLight : DishPalette.woodBase)
        }
    }

    // MARK: - 파스타 접시

    private func pastaPlate(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.10, w = r.width, h = r.height
        plate(&ctx, cx, cy, w * 0.98, h * 0.52)
        // 감긴 면 — 각진 고리 두 겹 + 가운데 뭉치.
        let nest = facet(cx, cy - h * 0.04, w * 0.60, h * 0.30, 10)
        shadow(&ctx, nest, r)
        fill(&ctx, nest, look.fill)
        chipShade(&ctx, nest, split: 0.6)
        fillRing(&ctx, ringPath(cx, cy - h * 0.05, w * 0.48, h * 0.24, 9, thickness: w * 0.035),
                 .black.opacity(0.10))
        fillRing(&ctx, ringPath(cx + w * 0.04, cy - h * 0.02, w * 0.30, h * 0.15, 8,
                                thickness: w * 0.030, phase: 0.5),
                 .black.opacity(0.10))
        marks(&ctx, [(CGPoint(x: cx - w * 0.17, y: cy - h * 0.10), w * 0.20),
                     (CGPoint(x: cx + w * 0.16, y: cy - h * 0.02), w * 0.18),
                     (CGPoint(x: cx + w * 0.01, y: cy - h * 0.13), w * 0.16)])
    }

    // MARK: - 볶음 팬

    private func skillet(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let t = tone, cx = r.midX - r.width * 0.05, cy = r.midY + r.height * 0.06
        let w = r.width, h = r.height
        // 손잡이(오른쪽 위) — 팬보다 먼저 깔아 팬 아래로 물려 들어가게.
        fill(&ctx, poly([CGPoint(x: cx + w * 0.30, y: cy - h * 0.06),
                         CGPoint(x: r.maxX, y: r.minY + h * 0.16),
                         CGPoint(x: r.maxX, y: r.minY + h * 0.26),
                         CGPoint(x: cx + w * 0.31, y: cy + h * 0.06)]), t.dark)
        let pan = facet(cx, cy, w * 0.82, h * 0.56, 12)
        shadow(&ctx, pan, r)
        fill(&ctx, pan, t.base)
        shadeBody(&ctx, pan, dark: t.dark, light: t.light, split: 0.34)
        let inner = facet(cx, cy - h * 0.005, w * 0.70, h * 0.46, 12)
        fill(&ctx, inner, look.fill)
        chipShade(&ctx, inner, split: 0.56)
        var c = ctx; c.clip(to: inner)
        marks(&c, [(CGPoint(x: cx - w * 0.17, y: cy - h * 0.07), w * 0.21),
                   (CGPoint(x: cx + w * 0.15, y: cy + h * 0.06), w * 0.20),
                   (CGPoint(x: cx + w * 0.02, y: cy - h * 0.11), w * 0.17),
                   (CGPoint(x: cx - w * 0.10, y: cy + h * 0.11), w * 0.16)])
    }

    // MARK: - 접시 위 밥 산 (볶음밥·리조또·매쉬)

    private func platedMound(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.17, w = r.width, h = r.height
        plate(&ctx, cx, cy, w * 0.98, h * 0.44)
        let mound = poly([CGPoint(x: cx - w * 0.33, y: cy - h * 0.01),
                          CGPoint(x: cx - w * 0.24, y: cy - h * 0.20),
                          CGPoint(x: cx - w * 0.04, y: cy - h * 0.30),
                          CGPoint(x: cx + w * 0.20, y: cy - h * 0.19),
                          CGPoint(x: cx + w * 0.33, y: cy - h * 0.01),
                          CGPoint(x: cx + w * 0.20, y: cy + h * 0.08),
                          CGPoint(x: cx - w * 0.20, y: cy + h * 0.08)])
        shadow(&ctx, mound, r)
        fill(&ctx, mound, look.fill)
        chipShade(&ctx, mound, split: 0.56)
        // 밥알 — 봉우리 안쪽에 작은 면 몇 개(알갱이 질감).
        var c = ctx; c.clip(to: mound)
        for (dx, dy) in [(CGFloat(-0.14), CGFloat(-0.10)), (0.10, -0.16), (0.02, -0.02),
                         (-0.05, -0.20), (0.18, -0.06)] {
            c.fill(facet(cx + w * dx, cy + h * dy, w * 0.075, h * 0.045, 4),
                   with: .color(.black.opacity(0.09)))
        }
        marks(&c, [(CGPoint(x: cx - w * 0.16, y: cy - h * 0.14), w * 0.19),
                   (CGPoint(x: cx + w * 0.14, y: cy - h * 0.12), w * 0.18),
                   (CGPoint(x: cx + w * 0.00, y: cy - h * 0.22), w * 0.16)])
    }

    // MARK: - 구이 접시

    private func grillPlate(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.15, w = r.width, h = r.height
        plate(&ctx, cx, cy, w * 0.98, h * 0.46)
        // 사이드(왼쪽) — 밥 반달이거나 잎 더미. 구이 덩어리보다 먼저 깔아 뒤에 놓이게.
        if let accent = look.accent {
            let side = poly([CGPoint(x: cx - w * 0.38, y: cy + h * 0.02),
                             CGPoint(x: cx - w * 0.32, y: cy - h * 0.13),
                             CGPoint(x: cx - w * 0.17, y: cy - h * 0.16),
                             CGPoint(x: cx - w * 0.09, y: cy - h * 0.02),
                             CGPoint(x: cx - w * 0.16, y: cy + h * 0.09),
                             CGPoint(x: cx - w * 0.32, y: cy + h * 0.09)])
            shadow(&ctx, side, r)
            fill(&ctx, side, accent)
            chipShade(&ctx, side, split: 0.5)
        }
        // 구운 덩어리 — 각진 슬래브 + 그릴 자국 두 줄.
        let slab = poly([CGPoint(x: cx - w * 0.14, y: cy - h * 0.13),
                         CGPoint(x: cx + w * 0.24, y: cy - h * 0.19),
                         CGPoint(x: cx + w * 0.39, y: cy - h * 0.02),
                         CGPoint(x: cx + w * 0.29, y: cy + h * 0.13),
                         CGPoint(x: cx - w * 0.06, y: cy + h * 0.12)])
        shadow(&ctx, slab, r)
        fill(&ctx, slab, look.fill)
        shadeBody(&ctx, slab, dark: .black.opacity(0.14), split: 0.42)
        var c = ctx; c.clip(to: slab)
        for k in [CGFloat(-0.05), CGFloat(0.06)] {
            c.fill(poly([CGPoint(x: cx - w * 0.16, y: cy + h * (k - 0.03)),
                         CGPoint(x: cx + w * 0.40, y: cy + h * (k - 0.09)),
                         CGPoint(x: cx + w * 0.40, y: cy + h * (k - 0.05)),
                         CGPoint(x: cx - w * 0.16, y: cy + h * (k + 0.01))]),
                    with: .color(.black.opacity(0.16)))
        }
        marks(&ctx, [(CGPoint(x: cx + w * 0.30, y: cy + h * 0.14), w * 0.20),
                     (CGPoint(x: cx - w * 0.26, y: cy + h * 0.10), w * 0.18),
                     (CGPoint(x: cx + w * 0.06, y: cy + h * 0.17), w * 0.16)])
    }

    // MARK: - 원판 (전·팬케이크·크레페·프리타타)

    private func discStack(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, w = r.width, h = r.height
        let n = max(1, min(3, look.layers))
        let gap = h * 0.115
        let baseY = r.midY + h * 0.20
        let discW = w * 0.86, discH = h * (n == 1 ? 0.42 : 0.30)
        for i in 0..<n {
            let cy = baseY - gap * CGFloat(i)
            let d = facet(cx, cy, discW, discH, 11, phase: i % 2 == 0 ? -.pi / 2 : -.pi / 2 + 0.28)
            shadow(&ctx, d, r)
            fill(&ctx, d, look.fill)
            shadeBody(&ctx, d, dark: .black.opacity(0.13), split: 0.44)
        }
        let topY = baseY - gap * CGFloat(n - 1)
        // 시럽·치즈 — 윗면에서 흘러내리는 각진 띠. 원판을 거의 다 덮으면 반죽 색이 사라져
        // 크레페든 팬케이크든 그냥 시럽 덩어리가 된다 — 윗면 절반 안쪽에서 흐르게 묶어둔다.
        if let accent = look.accent {
            var c = ctx
            c.clip(to: facet(cx, topY, discW, discH, 11))
            c.fill(poly([CGPoint(x: cx - w * 0.20, y: topY - discH * 0.34),
                         CGPoint(x: cx - w * 0.03, y: topY - discH * 0.48),
                         CGPoint(x: cx + w * 0.16, y: topY - discH * 0.28),
                         CGPoint(x: cx + w * 0.22, y: topY + discH * 0.10),
                         CGPoint(x: cx + w * 0.06, y: topY - discH * 0.02),
                         CGPoint(x: cx - w * 0.03, y: topY + discH * 0.22),
                         CGPoint(x: cx - w * 0.14, y: topY - discH * 0.04)]),
                    with: .color(accent))
        }
        marks(&ctx, [(CGPoint(x: cx - w * 0.15, y: topY - discH * 0.10), w * 0.20),
                     (CGPoint(x: cx + w * 0.17, y: topY + discH * 0.10), w * 0.19),
                     (CGPoint(x: cx + w * 0.02, y: topY - discH * 0.30), w * 0.16)])
    }

    // MARK: - 롤 단면 (김밥·계란말이)

    private func rollSlices(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.06, w = r.width, h = r.height
        let n = max(2, min(3, look.layers))
        let d = w * 0.44
        // 뒤 → 앞 순서로 겹친다(뒤쪽 조각이 앞 조각에 가리게).
        var spots: [CGPoint] = [CGPoint(x: cx + w * 0.02, y: cy - h * 0.17)]
        spots += [CGPoint(x: cx - w * 0.22, y: cy + h * 0.10),
                  CGPoint(x: cx + w * 0.24, y: cy + h * 0.13)]
        for (i, p) in spots.prefix(n).enumerated() {
            let outer = facet(p.x, p.y, d, d, 10, phase: -.pi / 2 + CGFloat(i) * 0.22)
            shadow(&ctx, outer, r)
            fill(&ctx, outer, look.fill)
            chipShade(&ctx, outer, split: 0.5)
            let core = facet(p.x, p.y, d * 0.76, d * 0.76, 10, phase: -.pi / 2 + CGFloat(i) * 0.22)
            fill(&ctx, core, look.accent ?? DishPalette.riceWhite)
            chipShade(&ctx, core, split: 0.6)
            var c = ctx; c.clip(to: core)
            marks(&c, [(CGPoint(x: p.x - d * 0.13, y: p.y - d * 0.06), d * 0.34),
                       (CGPoint(x: p.x + d * 0.12, y: p.y + d * 0.10), d * 0.32)])
        }
    }

    // MARK: - 샌드위치 층

    private func sandwichStack(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, w = r.width, h = r.height
        let left = cx - w * 0.42, right = cx + w * 0.42
        // 층은 **맞닿아 쌓인다** — 각 층의 y를 아래에서부터 누적해 잡는다. 위·아래 빵을 프레임의
        // 상단·하단에 각각 붙이면 사이가 벌어져 빵 두 쪽이 허공에 뜬 그림이 된다.
        let sliceH = h * 0.19, fillH = h * 0.15
        let botY = r.maxY - h * 0.12
        let lowerTop = botY - sliceH, fillTop = lowerTop - fillH, upperTop = fillTop - sliceH
        // 아래 빵
        let lower = poly([CGPoint(x: left + w * 0.03, y: lowerTop),
                          CGPoint(x: right - w * 0.02, y: lowerTop - h * 0.012),
                          CGPoint(x: right - w * 0.04, y: botY - h * 0.018),
                          CGPoint(x: cx, y: botY),
                          CGPoint(x: left + w * 0.05, y: botY - h * 0.024)])
        shadow(&ctx, lower, r)
        fill(&ctx, lower, look.fill)
        shadeBody(&ctx, lower, dark: .black.opacity(0.13), split: 0.44)
        // 속 — 빵보다 좌우로 삐져나온 지그재그 띠(층이 있다는 신호).
        if let accent = look.accent {
            let band = poly([CGPoint(x: left - w * 0.03, y: fillTop + h * 0.010),
                             CGPoint(x: cx - w * 0.18, y: fillTop - h * 0.028),
                             CGPoint(x: cx + w * 0.08, y: fillTop + h * 0.008),
                             CGPoint(x: right + w * 0.02, y: fillTop - h * 0.022),
                             CGPoint(x: right, y: lowerTop + h * 0.008),
                             CGPoint(x: cx + w * 0.06, y: lowerTop - h * 0.020),
                             CGPoint(x: cx - w * 0.16, y: lowerTop + h * 0.010),
                             CGPoint(x: left, y: lowerTop - h * 0.012)])
            fill(&ctx, band, accent)
            chipShade(&ctx, band, split: 0.5)
        }
        // 위 빵
        let upper = poly([CGPoint(x: left + w * 0.06, y: upperTop + h * 0.030),
                          CGPoint(x: cx - w * 0.10, y: upperTop),
                          CGPoint(x: right - w * 0.05, y: upperTop + h * 0.022),
                          CGPoint(x: right - w * 0.02, y: fillTop + h * 0.004),
                          CGPoint(x: left + w * 0.03, y: fillTop + h * 0.016)])
        shadow(&ctx, upper, r)
        fill(&ctx, upper, look.fill)
        shadeBody(&ctx, upper, dark: .black.opacity(0.11), light: .white.opacity(0.16), split: 0.50)
        // 고명 — 속에서 삐져나온 것 둘 + 윗면에 얹힌 것 하나(오픈 토스트도 읽히게).
        marks(&ctx, [(CGPoint(x: left + w * 0.07, y: fillTop + h * 0.055), w * 0.19),
                     (CGPoint(x: right - w * 0.08, y: fillTop + h * 0.040), w * 0.18),
                     (CGPoint(x: cx + w * 0.12, y: upperTop + h * 0.026), w * 0.16)])
    }

    // MARK: - 반달 또띠아 (타코·퀘사디아·파히타)

    private func foldedWrap(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, w = r.width, h = r.height
        let top = r.minY + h * 0.44, bot = r.maxY - h * 0.07
        let halfW = w * 0.46, depth = bot - top
        // 좌우 대칭인 반원을 똑바로 세우면 **그릇**으로 읽힌다(수평선 + 그 위에 담긴 내용물).
        // 눈에 띄게 기울여야 "바닥에 놓인 그릇"이 아니라 "반으로 접은 또띠아"가 된다 —
        // 7도로는 부족했다(대칭축이 아직 수직이라 그릇 읽기가 이긴다).
        var g = ctx
        g.translateBy(x: cx, y: top)
        g.rotate(by: .degrees(-20))
        g.translateBy(x: -cx, y: -top)
        // 껍질 — 윗변이 평평한 반원. 옆면을 곧게 세우면(사다리꼴) 통·바구니가 된다.
        let shell = poly((0...9).map { i in
            let a = CGFloat.pi * CGFloat(i) / 9
            return CGPoint(x: cx - halfW * cos(a), y: top + depth * sin(a))
        })
        shadow(&g, shell, r)
        fill(&g, shell, look.fill)
        shadeBody(&g, shell, dark: .black.opacity(0.13), light: .white.opacity(0.14), split: 0.40)
        // 껍질 두께 — 잘린 윗면(또띠아 단면)을 한 톤 밝게. 안쪽으로 파인 면을 그리면 그릇의
        // 오목한 안벽이 되어버리므로, 두께는 **윗변에 붙은 얇은 띠**로만 표현한다.
        var sc = g; sc.clip(to: shell)
        sc.fill(poly([CGPoint(x: cx - halfW, y: top),
                      CGPoint(x: cx + halfW, y: top),
                      CGPoint(x: cx + halfW * 0.96, y: top + h * 0.050),
                      CGPoint(x: cx - halfW * 0.96, y: top + h * 0.050)]),
                with: .color(.white.opacity(0.22)))
        // 속 — 껍질 **밖으로 삐져나와** 윗변 위로 솟는다. 속이 껍질 폭 안에 갇히면
        // 그릇에 담긴 국물처럼 보인다(넘쳐야 싸 먹는 음식으로 읽힌다).
        if let accent = look.accent {
            let stuff = poly([CGPoint(x: cx - halfW * 1.04, y: top + h * 0.020),
                              CGPoint(x: cx - halfW * 0.66, y: top - h * 0.090),
                              CGPoint(x: cx - halfW * 0.20, y: top - h * 0.035),
                              CGPoint(x: cx + halfW * 0.28, y: top - h * 0.110),
                              CGPoint(x: cx + halfW * 0.76, y: top - h * 0.030),
                              CGPoint(x: cx + halfW * 1.04, y: top + h * 0.020),
                              CGPoint(x: cx + halfW * 0.80, y: top + h * 0.042),
                              CGPoint(x: cx - halfW * 0.80, y: top + h * 0.042)])
            shadow(&g, stuff, r)
            fill(&g, stuff, accent)
            chipShade(&g, stuff, split: 0.46)
        }
        marks(&g, [(CGPoint(x: cx - w * 0.22, y: top - h * 0.048), w * 0.19),
                     (CGPoint(x: cx + w * 0.21, y: top - h * 0.058), w * 0.18),
                     (CGPoint(x: cx - w * 0.01, y: top - h * 0.088), w * 0.16)])
    }

    // MARK: - 커리 접시 (밥 + 소스 두 존)

    private func curryPlate(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.15, w = r.width, h = r.height
        plate(&ctx, cx, cy, w * 0.98, h * 0.48)
        // 밥 — 왼쪽 반달(오른쪽 변이 곧다: 소스와 맞닿는 경계).
        let rice = poly([CGPoint(x: cx - w * 0.02, y: cy - h * 0.17),
                         CGPoint(x: cx - w * 0.02, y: cy + h * 0.15),
                         CGPoint(x: cx - w * 0.24, y: cy + h * 0.14),
                         CGPoint(x: cx - w * 0.38, y: cy + h * 0.02),
                         CGPoint(x: cx - w * 0.30, y: cy - h * 0.14),
                         CGPoint(x: cx - w * 0.14, y: cy - h * 0.20)])
        shadow(&ctx, rice, r)
        fill(&ctx, rice, look.accent ?? DishPalette.riceWhite)
        chipShade(&ctx, rice, split: 0.56)
        // 소스 — 오른쪽 웅덩이(왼쪽 변이 밥과 맞닿는다).
        let sauce = poly([CGPoint(x: cx - w * 0.02, y: cy - h * 0.17),
                          CGPoint(x: cx + w * 0.16, y: cy - h * 0.19),
                          CGPoint(x: cx + w * 0.36, y: cy - h * 0.06),
                          CGPoint(x: cx + w * 0.32, y: cy + h * 0.12),
                          CGPoint(x: cx + w * 0.10, y: cy + h * 0.18),
                          CGPoint(x: cx - w * 0.02, y: cy + h * 0.15)])
        shadow(&ctx, sauce, r)
        fill(&ctx, sauce, look.fill)
        chipShade(&ctx, sauce, split: 0.54)
        var c = ctx; c.clip(to: sauce)
        marks(&c, [(CGPoint(x: cx + w * 0.13, y: cy - h * 0.07), w * 0.19),
                   (CGPoint(x: cx + w * 0.21, y: cy + h * 0.06), w * 0.18),
                   (CGPoint(x: cx + w * 0.05, y: cy + h * 0.08), w * 0.15)])
    }

    // MARK: - 낮은 볼 (샐러드·나물·딥)

    private func sideBowl(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let t = tone, cx = r.midX, w = r.width, h = r.height
        let cy = r.midY + h * 0.04
        let body = facet(cx, cy + h * 0.11, w * 0.94, h * 0.60, 12)
        shadow(&ctx, body, r)
        fill(&ctx, body, t.dark)
        fill(&ctx, facet(cx, cy, w * 0.96, h * 0.56, 12), t.light)
        let surface = facet(cx, cy, w * 0.81, h * 0.44, 12)
        fill(&ctx, surface, look.fill)
        var c = ctx; c.clip(to: surface)
        switch look.surface {
        case .smooth:
            fillRing(&c, ringPath(cx, cy, w * 0.59, h * 0.26, 11, thickness: w * 0.015),
                     .white.opacity(0.16))
        case .leaves, .pieces:
            for (i, spot) in [(CGFloat(-0.23), CGFloat(-0.08)), (0.04,-0.13), (0.24,-0.04),
                              (-0.16,0.08), (0.11,0.09), (0.00,0.00)].enumerated() {
                let center = CGPoint(x:cx+w*spot.0,y:cy+h*spot.1)
                if look.surface == .leaves {
                    mark(&c, DishMark(shape:.leafy,color:look.fill), at:center, size:w*0.36)
                } else {
                    let chunk = facet(center.x, center.y, w*0.28, h*0.17, 9,
                                      phase:CGFloat(i)*0.35)
                    shadow(&c, chunk, r)
                    fill(&c, chunk, look.fill)
                    chipShade(&c, chunk, split:0.67)
                }
            }
        case .shreds:
            for i in 0..<10 {
                let x=cx+w*(CGFloat((i*7)%9)/14-0.28)
                let y=cy+h*(CGFloat(i%4)/12-0.13)
                mark(&c,DishMark(shape:.baton,color:look.fill),at:CGPoint(x:x,y:y),size:w*0.32)
                fill(&c,facet(x,y-h*0.012,w*0.18,h*0.011,4),.white.opacity(0.35))
            }
        }
        if let accent = look.accent {
            for dx in [CGFloat(-0.26), CGFloat(0.23)] {
                mark(&ctx, DishMark(shape: .wedge, color: accent),
                     at: CGPoint(x: cx + w * dx, y: cy - h * 0.12), size: w * 0.30)
            }
        }
        marks(&c, [(CGPoint(x: cx - w * 0.20, y: cy - h * 0.025), w * 0.28),
                   (CGPoint(x: cx + w * 0.17, y: cy - h * 0.055), w * 0.26),
                   (CGPoint(x: cx + w * 0.01, y: cy + h * 0.105), w * 0.25),
                   (CGPoint(x: cx - w * 0.025, y: cy - h * 0.12), w * 0.20)])
    }

    // MARK: - 오븐 그릇 (그라탕·라자냐·베이크)

    private func bakeDish(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let t = tone, cx = r.midX, w = r.width, h = r.height
        let backY = r.minY + h * 0.30, frontY = r.minY + h * 0.56, botY = r.maxY - h * 0.10
        let backHalf = w * 0.36, frontHalf = w * 0.44
        // 귀 손잡이
        for s in [CGFloat(-1), CGFloat(1)] {
            fill(&ctx, poly([CGPoint(x: cx + s * frontHalf * 0.96, y: frontY + h * 0.02),
                             CGPoint(x: cx + s * (frontHalf + w * 0.07), y: frontY + h * 0.05),
                             CGPoint(x: cx + s * (frontHalf + w * 0.06), y: frontY + h * 0.14),
                             CGPoint(x: cx + s * frontHalf * 0.94, y: frontY + h * 0.12)]), t.dark)
        }
        // 앞면(그릇 벽)
        let front = poly([CGPoint(x: cx - frontHalf, y: frontY),
                          CGPoint(x: cx + frontHalf, y: frontY),
                          CGPoint(x: cx + frontHalf * 0.90, y: botY),
                          CGPoint(x: cx - frontHalf * 0.90, y: botY)])
        shadow(&ctx, front, r)
        fill(&ctx, front, t.base)
        shadeBody(&ctx, front, dark: t.dark, light: t.light, split: 0.30)
        // 윗면(내용물이 보이는 사다리꼴)
        let top = poly([CGPoint(x: cx - backHalf, y: backY),
                        CGPoint(x: cx + backHalf, y: backY),
                        CGPoint(x: cx + frontHalf, y: frontY),
                        CGPoint(x: cx - frontHalf, y: frontY)])
        fill(&ctx, top, t.light)
        let surface = poly([CGPoint(x: cx - backHalf * 0.90, y: backY + h * 0.022),
                            CGPoint(x: cx + backHalf * 0.90, y: backY + h * 0.022),
                            CGPoint(x: cx + frontHalf * 0.90, y: frontY - h * 0.020),
                            CGPoint(x: cx - frontHalf * 0.90, y: frontY - h * 0.020)])
        fill(&ctx, surface, look.fill)
        chipShade(&ctx, surface, split: 0.5)
        // 아래 층 — 앞면 위쪽에 드러난 단면 줄(라자냐 층·감자 층).
        if let accent = look.accent {
            fill(&ctx, poly([CGPoint(x: cx - frontHalf * 0.97, y: frontY + h * 0.030),
                             CGPoint(x: cx + frontHalf * 0.97, y: frontY + h * 0.030),
                             CGPoint(x: cx + frontHalf * 0.95, y: frontY + h * 0.085),
                             CGPoint(x: cx - frontHalf * 0.95, y: frontY + h * 0.085)]), accent)
        }
        var c = ctx; c.clip(to: surface)
        marks(&c, [(CGPoint(x: cx - w * 0.19, y: backY + h * 0.075), w * 0.20),
                   (CGPoint(x: cx + w * 0.17, y: backY + h * 0.115), w * 0.19),
                   (CGPoint(x: cx - w * 0.01, y: backY + h * 0.045), w * 0.16)])
    }
}

// MARK: - Recognisable food details and serving shapes
private extension DishSilhouette {
    func piece(_ c: inout GraphicsContext, _ pts: [(CGFloat,CGFloat)], _ color: Color) {
        let path = poly(pts.map { CGPoint(x:$0.0,y:$0.1) })
        fill(&c,path,color)
    }

    func foodMark(_ ctx: inout GraphicsContext, _ m: DishMark, at p: CGPoint, size s: CGFloat) {
        var c=ctx
        c.translateBy(x:p.x,y:p.y)
        c.scaleBy(x:s,y:s)
        let P=DishPalette.self
        switch m.shape {
        case .shrimp:
            // A segmented curled body and a separate tail, instead of a meat strip.
            for i in 0..<6 {
                let a = CGFloat(i) * 0.47 + 0.55
                let x=cos(a)*0.34,y=sin(a)*0.30
                fill(&c,facet(x,y,0.31-CGFloat(i)*0.025,0.27,7),m.color)
                fill(&c,facet(x-0.035,y-0.04,0.08,0.18,5),P.eggWhite.opacity(0.65))
            }
            piece(&c,[(-0.34,0.03),(-0.52,-0.28),(-0.31,-0.17),(-0.20,-0.36),(-0.20,-0.04)],m.color)
        case .bananaSlice:
            fill(&c,facet(0,0,1.06,0.87,11),P.pancakeGold)
            fill(&c,facet(0,-0.025,0.93,0.74,11),P.eggWhite)
            fill(&c,facet(0,-0.025,0.82,0.64,11),m.color.opacity(0.45))
            for i in 0..<3 {
                let a=CGFloat(i) * .pi * 2 / 3
                fill(&c,facet(cos(a)*0.13,sin(a)*0.10,0.06,0.085,5),P.woodLight)
            }
        case .eggHalf:
            fill(&c,facet(0,0,0.92,1.23,11),P.eggWhite)
            fill(&c,facet(0,0.15,0.59,0.59,10),m.color)
        case .mushroom:
            piece(&c,[(-0.13,0.02),(0.14,0.02),(0.23,0.49),(-0.24,0.49)],P.eggWhite)
            piece(&c,[(-0.54,0.05),(-0.43,-0.27),(-0.20,-0.44),(0.22,-0.42),(0.45,-0.22),(0.54,0.05)],m.color)
            piece(&c,[(-0.27,-0.21),(-0.06,-0.13),(0.20,-0.28),(0.06,-0.05)],P.eggWhite.opacity(0.8))
        case .citrusSlice, .tomatoSlice, .lotus:
            fill(&c,facet(0,0,1.12,0.89,11),m.color)
            fill(&c,facet(0,0,0.91,0.72,11),m.shape == .tomatoSlice ? P.chiliRed : P.eggWhite)
            for i in 0..<7 {
                let a=CGFloat(i) * .pi * 2 / 7
                if m.shape == .lotus {
                    fill(&c,facet(cos(a)*0.32,sin(a)*0.25,0.15,0.17,7),P.mushroomTan)
                } else {
                    let b=a+0.65
                    piece(&c,[(cos(a)*0.08,sin(a)*0.06),(cos(a)*0.41,sin(a)*0.31),
                              (cos(b)*0.41,sin(b)*0.31)],m.shape == .tomatoSlice ? P.tomatoRed : m.color)
                    if m.shape == .tomatoSlice { fill(&c,facet(cos(a)*0.26,sin(a)*0.19,0.05,0.07,5),P.sesame) }
                }
            }
        case .floret:
            piece(&c,[(-0.1,0),(0.13,0),(0.23,0.48),(-0.20,0.48)],P.cabbagePale)
            for (x,y) in [(CGFloat(-0.27),CGFloat(-0.08)),(0,-0.26),(0.28,-0.06),(0.03,0.08)] {
                fill(&c,facet(x,y,0.48,0.44,9),m.color)
                fill(&c,facet(x-0.06,y-0.06,0.23,0.18,7),P.eggWhite.opacity(0.25))
            }
        case .clam:
            piece(&c,[(-0.51,-0.10),(-0.35,-0.44),(0,-0.49),(0.36,-0.32),(0.47,0.05),
                      (0.22,0.43),(-0.20,0.45)],m.color)
            fill(&c,facet(0,0.03,0.66,0.59,9),P.eggWhite)
            fill(&c,facet(0.02,0.09,0.40,0.30,9),P.mushroomTan)
            for x in [CGFloat(-0.25),0,0.25] { piece(&c,[(x,-0.30),(x+0.04,-0.28),(0.03,0.34),(-0.02,0.34)],P.woodDark.opacity(0.4)) }
        case .dumpling:
            piece(&c,[(-0.55,0.22),(-0.41,-0.13),(-0.19,-0.36),(0.15,-0.39),(0.46,-0.17),
                      (0.55,0.16),(0.29,0.37),(-0.28,0.39)],m.color)
            for x in [CGFloat(-0.28),-0.08,0.13,0.31] {
                piece(&c,[(x,-0.20),(x+0.035,-0.22),(x*0.45,0.22),(x*0.45-0.04,0.23)],P.woodLight.opacity(0.6))
            }
        case .berry:
            for (x,y) in [(CGFloat(-0.23),CGFloat(-0.08)),(0.23,-0.15),(0,0.23)] {
                fill(&c,facet(x,y,0.48,0.51,9),m.color)
                fill(&c,facet(x,y-0.08,0.12,0.10,5),P.oliveInk)
            }
        default: break
        }
    }

    func platedSpecialty(_ r: CGRect, _ ctx: inout GraphicsContext) {
        var c=ctx
        c.translateBy(x:r.minX,y:r.minY)
        c.scaleBy(x:r.width/100,y:r.height/100)
        let P=DishPalette.self
        let unit=CGRect(x:0,y:0,width:100,height:100)
        if look.archetype != .drinkGlass {
            plate(&c,50,57,98,72)
        }
        switch look.archetype {
        case .openToast:
            for (i,x) in [CGFloat(17),CGFloat(53)].enumerated() {
                let y:CGFloat = i == 0 ? 28 : 23
                let crust=poly([CGPoint(x:x,y:y+9),CGPoint(x:x+7,y:y),CGPoint(x:x+24,y:y-3),
                                CGPoint(x:x+31,y:y+6),CGPoint(x:x+30,y:y+48),CGPoint(x:x+21,y:y+55),
                                CGPoint(x:x+3,y:y+53)])
                shadow(&c,crust,unit);fill(&c,crust,look.fill)
                piece(&c,[(x+4,y+12),(x+10,y+4),(x+23,y+3),(x+27,y+10),(x+25,y+47),(x+6,y+48)],P.toastCream)
                piece(&c,[(x+7,y+15),(x+12,y+8),(x+24,y+12),(x+23,y+43),(x+8,y+44)],look.accent ?? P.toastGold)
                if let m=look.mark { mark(&c,m,at:CGPoint(x:x+15,y:y+23),size:19) }
                if let m=look.mark2 { mark(&c,m,at:CGPoint(x:x+18,y:y+39),size:15) }
            }
        case .riceTriangle:
            for (x,y) in [(CGFloat(12),CGFloat(27)),(48,34)] {
                let rice=poly([CGPoint(x:x,y:y+37),CGPoint(x:x+16,y:y+2),CGPoint(x:x+24,y:y),
                               CGPoint(x:x+43,y:y+35),CGPoint(x:x+38,y:y+44),CGPoint(x:x+7,y:y+46)])
                shadow(&c,rice,unit);fill(&c,rice,look.fill)
                piece(&c,[(x+15,y+25),(x+28,y+24),(x+31,y+43),(x+14,y+45)],look.accent ?? P.seaweedDark)
                for (dx,dy) in [(CGFloat(14),CGFloat(19)),(25,12),(32,29),(8,32)] {
                    fill(&c,facet(x+dx,y+dy,3.5,1.8,5),P.woodLight.opacity(0.3))
                }
            }
        case .skewers:
            for i in 0..<3 {
                let x=CGFloat(20+i*22)
                piece(&c,[(x,18),(x+2,18),(x+10,89),(x+8,89)],P.woodLight)
                for j in 0..<3 {
                    let y=CGFloat(27+j*17),xx=x+CGFloat(j)*2
                    let chunk=poly([CGPoint(x:xx-7,y:y),CGPoint(x:xx+7,y:y-4),CGPoint(x:xx+12,y:y+7),
                                    CGPoint(x:xx+5,y:y+13),CGPoint(x:xx-8,y:y+9)])
                    shadow(&c,chunk,unit);fill(&c,chunk,look.fill)
                    piece(&c,[(xx-5,y+1),(xx+8,y-1),(xx+9,y+2),(xx-4,y+4)],P.searDark.opacity(0.6))
                }
            }
            if let m=look.mark2 { mark(&c,m,at:CGPoint(x:75,y:76),size:17) }
        case .drinkGlass:
            piece(&c,[(22,20),(77,20),(71,84),(62,94),(35,94),(27,84)],P.indigoLight)
            piece(&c,[(27,29),(72,29),(66,83),(60,88),(37,88),(32,80)],look.fill)
            fill(&c,facet(49,25,53,22,12),P.eggWhite)
            fill(&c,facet(49,25,44,15,12),look.fill)
            piece(&c,[(59,50),(67,5),(71,6),(63,51)],P.woodLight)
            piece(&c,[(28,37),(32,38),(37,80),(34,81)],P.eggWhite.opacity(0.7))
            if let m=look.mark { mark(&c,m,at:CGPoint(x:47,y:23),size:12) }
        case .waffle:
            for (i,x) in [CGFloat(16),CGFloat(43)].enumerated() {
                let y:CGFloat = i == 0 ? 29 : 43
                piece(&c,[(x,y),(x+39,y-7),(x+45,y+34),(x+6,y+41)],look.fill)
                for row in 0..<3 { for col in 0..<3 {
                    let xx=x+5+CGFloat(col)*11+CGFloat(row),yy=y+5+CGFloat(row)*10-CGFloat(col)*2
                    piece(&c,[(xx,yy),(xx+8,yy-1),(xx+9,yy+6),(xx+1,yy+8)],P.toastGold)
                    piece(&c,[(xx,yy),(xx+8,yy-1),(xx+8,yy+1),(xx+2,yy+3),(xx+1,yy+8)],P.woodLight)
                } }
            }
            piece(&c,[(46,39),(60,36),(65,46),(51,50)],P.butterCube)
            if let m=look.mark { mark(&c,m,at:CGPoint(x:72,y:72),size:18) }
        case .wholeFish:
            for (x,y) in [(CGFloat(14),CGFloat(38)),(23,57)] {
                let body=poly([CGPoint(x:x,y:y),CGPoint(x:x+10,y:y-9),CGPoint(x:x+48,y:y-8),
                               CGPoint(x:x+58,y:y),CGPoint(x:x+49,y:y+12),CGPoint(x:x+9,y:y+11)])
                shadow(&c,body,unit);fill(&c,body,P.indigoLight)
                piece(&c,[(x+56,y),(x+71,y-9),(x+67,y+2),(x+72,y+11),(x+56,y+7)],P.indigoDark)
                piece(&c,[(x+10,y-9),(x+48,y-8),(x+54,y-3),(x+12,y-3)],P.indigoDark)
                fill(&c,facet(x+9,y+1,5,5,9),P.eggWhite)
                fill(&c,facet(x+9,y+1,2.6,2.6,8),P.oliveInk)
                for k in 0..<3 { let xx=x+23+CGFloat(k)*8;piece(&c,[(xx,y-3),(xx+2,y-3),(xx-1,y+6),(xx-3,y+7)],P.searDark.opacity(0.6)) }
            }
            foodMark(&c,DishMark(shape:.citrusSlice,color:P.lemonYellow),at:CGPoint(x:73,y:27),size:22)
        case .salmonFillet:
            let slab=poly([CGPoint(x:29,y:26),CGPoint(x:69,y:30),CGPoint(x:87,y:68),
                           CGPoint(x:68,y:83),CGPoint(x:29,y:71),CGPoint(x:19,y:41)])
            shadow(&c,slab,unit);fill(&c,slab,look.fill)
            var clipped=c;clipped.clip(to:slab)
            for i in 0..<6 {
                let x=CGFloat(28+i*8)
                piece(&clipped,[(x,24),(x+2,24),(x+13,50),(x+6,78),(x+3,78),(x+10,50)],P.porkFat)
            }
            mark(&c,DishMark(shape:.leafy,color:look.accent ?? P.parsley),at:CGPoint(x:19,y:65),size:26)
            foodMark(&c,DishMark(shape:.citrusSlice,color:P.lemonYellow),at:CGPoint(x:77,y:29),size:22)
        default: break
        }
    }
}
