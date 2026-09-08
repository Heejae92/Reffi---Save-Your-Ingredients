import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Reffi

struct ArtworkCoverageTests {
    @Test func knownIngredientsHaveArtwork() {
        for entry in IngredientLexicon.shared.entries {
            let glyph = FoodGlyph(rawValue: entry.glyph)
            #expect(glyph != nil && glyph != .generic, "Missing artwork: \(entry.id)")
        }
    }

    @Test func differentIngredientsNoLongerShareMisleadingPictures() {
        for (name, expected) in [("대파", FoodGlyph.scallion), ("양파", .onion), ("무", .radish),
                                 ("당근", .root), ("팽이버섯", .enoki), ("블루베리", .blueberry),
                                 ("딸기", .berry), ("연어", .salmon), ("문어", .octopus),
                                 ("키위", .kiwi), ("김치", .kimchi), ("콩나물", .sprout)] {
            #expect(FoodGlyph.match(name) == expected, "\(name)")
        }
    }

    @Test @MainActor func existingInventoryRefreshesOnlyArtwork() {
        let old = Ingredient(name: "대파", category: "Veg", daysLeft: 3,
                             quantity: Quantity(value: 2, unit: .piece), glyph: .onion, place: "Market")
        let store = FridgeStore(ingredients: [old], recipes: [])
        let refreshed = store.ingredients[0]
        #expect(refreshed.glyph == .scallion)
        #expect(refreshed.id == old.id)
        #expect(refreshed.quantity == old.quantity)
        #expect(refreshed.expiresAt == old.expiresAt)
        #expect(refreshed.place == old.place)
    }

    @Test func bananaAndCrabStickGarnishesKeepTheirFoodIdentity() {
        for id in ["banana-pancake", "pb-banana-toast", "american-overnight-oats"] {
            let look = DishGlyphCatalog.curatedLook(id: id)
            #expect(look?.mark?.shape == .bananaSlice)
        }
        #expect(DishGlyphCatalog.curatedLook(id: "matsal-gyeran-mari")?.mark?.shape == .strip)
    }

    @Test func distinctiveRecipesUseTheirActualServingShapes() {
        for (id, expected) in [("indian-mango-lassi", DishArchetype.drinkGlass),
                               ("onigiri", .riceTriangle), ("margherita-toast", .openToast),
                               ("american-buttermilk-waffles", .waffle),
                               ("godeungeo-gui", .wholeFish), ("salmon-steak", .salmonFillet),
                               ("indonesian-satay-skewers", .skewers)] {
            #expect(DishGlyphCatalog.curatedLook(id: id)?.archetype == expected)
        }
    }
}

/// Opt-in native render artefacts, including measured alpha bounds for physics integration.
@MainActor
struct ArtworkContactSheetTests {
    @Test func renderReviewSheetsAndMeasureBodies() throws {
        guard ProcessInfo.processInfo.environment["REFFI_CONTACT_SHEET"] == "1" else { return }
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DISH_SHEET_DIR"]
                            ?? FileManager.default.temporaryDirectory.path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var metrics: [String: [Double]] = [:]
        for glyph in FoodGlyph.allCases {
            if let m = GlyphBodyMetrics.measure(glyph) {
                metrics[glyph.rawValue] = [Double(m.w * 0.9), Double(m.h * 0.9),
                                          Double(0.5 - (m.minYf + m.maxYf) / 2)]
            }
        }
        try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("body-metrics.json"))
        let food = FoodGlyph.allCases.filter { $0 != .generic }
        for (index, start) in stride(from: 0, to: food.count, by: 48).enumerated() {
            let group = Array(food[start..<min(start+48, food.count)])
            let items = group.map { g in
                ReviewItem(label: g.rawValue, image: AnyView(PaperSilhouette(glyph:g, fresh:.fresh)))
            }
            try write(items, title: "Reffi ingredients · \(index+1)", name: "ingredients-\(index+1)", directory:directory)
        }
        let recipes = seedRecipesForTests()
        for (index, start) in stride(from: 0, to: recipes.count, by: 48).enumerated() {
            let group = Array(recipes[start..<min(start+48, recipes.count)])
            let items = group.map { recipe in
                ReviewItem(label: recipe.name.ko ?? recipe.name.en,
                           image: AnyView(RecipeHeroIconView(icon:recipe.heroIcon)))
            }
            try write(items, title:"Reffi recipes · \(index+1)", name:"recipes-\(index+1)", directory:directory)
        }
        let featureGlyphs: [FoodGlyph] = [.scallion,.radish,.kiwi,.blueberry,.salmon,.walnut]
        let featureIDs = ["margherita-toast","salmon-steak","onigiri","american-buttermilk-waffles","indian-mango-lassi","indonesian-satay-skewers"]
        var feature = featureGlyphs.map { ReviewItem(label:$0.rawValue,image:AnyView(PaperSilhouette(glyph:$0,fresh:.fresh))) }
        feature += recipes.filter { featureIDs.contains($0.id) }.map {
            ReviewItem(label:$0.name.ko ?? $0.name.en,image:AnyView(RecipeHeroIconView(icon:$0.heroIcon)))
        }
        try write(feature,title:"Reffi · cut paper food",name:"highlights",directory:directory,columns:6,cell:170)
        let refreshed: [(FoodGlyph, String)] = [
            (.leaf,"잎채소"),(.root,"당근"),(.pepper,"파프리카"),(.tomato,"토마토"),
            (.cucumber,"오이"),(.pea,"완두콩"),(.onion,"양파"),(.garlic,"마늘"),
            (.mushroom,"버섯"),(.avocado,"아보카도"),(.fish,"생선"),(.meat,"고기")
        ]
        try write(refreshed.map { ReviewItem(label:$0.1,image:AnyView(PaperSilhouette(glyph:$0.0,fresh:.fresh))) },
                  title:"Reffi · paper cut ingredients",name:"refreshed-highlights",directory:directory,columns:6,cell:180)
        let pantry: [(FoodGlyph,String)] = [(.can,"통조림"),(.honey,"꿀"),(.dumpling,"만두")]
        try write(pantry.map { ReviewItem(label:$0.1,image:AnyView(PaperSilhouette(glyph:$0.0,fresh:.fresh))) },
                  title:"Reffi · pantry",name:"refreshed-pantry",directory:directory,columns:3,cell:180)
        // Native point sizes and the same freshness/color-scheme inputs used by app surfaces.
        for scheme in [ColorScheme.light, .dark] {
            let view = VStack(alignment:.leading,spacing:16) {
                Text("32 pt · 56 pt · 132 pt · Urgent 56 pt").font(.system(size:15,weight:.medium))
                ForEach(Array(refreshed.enumerated()),id:\.offset) { _, item in
                    HStack(spacing:18) {
                        Text(verbatim:item.1).font(.system(size:13)).frame(width:66,alignment:.leading)
                        ForEach([CGFloat(32),56,132],id:\.self) { side in
                            PaperSilhouette(glyph:item.0,fresh:.fresh).frame(width:side,height:side)
                        }
                        PaperSilhouette(glyph:item.0,fresh:.urgent).frame(width:56,height:56)
                    }
                }
            }.padding(24).foregroundStyle(scheme == .light ? Color.black : Color.white)
                .background(scheme == .light ? ReffiColor.oklch(0.97,0.013,90) : ReffiColor.oklch(0.25,0.01,80))
                .environment(\.colorScheme,scheme)
            let renderer=ImageRenderer(content:view);renderer.scale=2
            let png = try #require(renderer.uiImage?.pngData())
            try png.write(to:directory.appendingPathComponent("sizes-\(scheme == .light ? "light" : "dark").png"))
        }
        print("ARTWORK_SHEETS_WRITTEN \(directory.path)")
    }

    private struct ReviewItem { let label:String; let image:AnyView }
    private func write(_ items:[ReviewItem], title:String, name:String, directory:URL,
                       columns:Int = 8, cell:CGFloat = 122) throws {
        let rows = (items.count+columns-1)/columns
        let view = VStack(alignment:.leading,spacing:16) {
            Text(verbatim:title).font(.system(size:24,weight:.semibold)).foregroundStyle(.black)
            VStack(spacing:8) {
                ForEach(0..<rows,id:\.self) { row in
                    HStack(alignment:.top,spacing:8) {
                        ForEach(0..<columns,id:\.self) { col in
                            let index=row*columns+col
                            if index < items.count {
                                VStack(spacing:5) {
                                    items[index].image.frame(width:cell-12,height:cell-12)
                                    Text(verbatim:items[index].label).font(.system(size:11,weight:.medium))
                                        .foregroundStyle(.black).lineLimit(2).multilineTextAlignment(.center)
                                }.frame(width:cell,height:cell+25,alignment:.top)
                            } else { Color.clear.frame(width:cell,height:cell+25) }
                        }
                    }
                }
            }
        }.padding(24).background(ReffiColor.oklch(0.97,0.013,90)).environment(\.colorScheme,.light)
        let renderer=ImageRenderer(content:view);renderer.scale=2
        let image = try #require(renderer.uiImage)
        let png = try #require(image.pngData())
        try png.write(to:directory.appendingPathComponent(name+".png"))
    }
}

@MainActor
struct FoodPaperGrainTests {
    private func render(side: Int, textured: Bool, legacy: Bool = false) throws -> [UInt8] {
        let view = Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.drawLayer { layer in
                let inset = rect.insetBy(dx: 3, dy: 3)
                var shape = Path(ellipseIn: inset)
                shape.addEllipse(in: inset.insetBy(dx: inset.width * 0.35, dy: inset.height * 0.35))
                layer.fill(shape, with: .color(.gray), style: FillStyle(eoFill: true))
                if legacy {
                    var c = layer; c.blendMode = .sourceAtop
                    let transform = CGAffineTransform(scaleX:size.width,y:size.height)
                    c.fill(Self.legacyFibres.0.applying(transform),with:.color(.white.opacity(0.16)))
                    c.fill(Self.legacyFibres.1.applying(transform),with:.color(.black.opacity(0.075)))
                } else if textured { FoodPaperGrain.overlay(in:rect,context:&layer) }
            }
        }.frame(width:CGFloat(side),height:CGFloat(side))
        let renderer = ImageRenderer(content:view); renderer.scale = 1
        let image = try #require(renderer.cgImage)
        var bytes = [UInt8](repeating:0,count:side*side*4)
        let context = try #require(CGContext(data:&bytes,width:side,height:side,bitsPerComponent:8,
                                             bytesPerRow:side*4,space:CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image,in:CGRect(x:0,y:0,width:side,height:side))
        return bytes
    }

    @Test func allSizesHaveGrainWithoutFillingTransparentGaps() throws {
        for side in [32,56,132] {
            let flat = try render(side:side,textured:false)
            let grain = try render(side:side,textured:true)
            var changed = 0, interior = 0
            for pixel in 0..<(side*side) {
                let offset = pixel*4
                #expect(flat[offset+3] == grain[offset+3], "Texture changed alpha at \(side) pt")
                if flat[offset+3] == 255 {
                    interior += 1
                    if flat[offset] != grain[offset] { changed += 1 }
                }
            }
            #expect(changed > interior/4, "Texture is absent at \(side) pt")
        }
    }

    @Test func plateIsSharedAndBounded() {
        #expect(FoodPaperGrain.plate === FoodPaperGrain.plate)
        #expect(FoodPaperGrain.plate.bytesPerRow * FoodPaperGrain.plate.height == 262_144)
    }

    /// Opt-in comparison, not a timing assertion that can flake under simulator load.
    @Test func compareWarmRenderCost() throws {
        guard ProcessInfo.processInfo.environment["REFFI_GRAIN_BENCH"] == "1" else { return }
        _ = try render(side:132,textured:true)
        _ = try render(side:132,textured:false,legacy:true)
        var old:[Double] = [], new:[Double] = []
        for index in 0..<40 {
            for legacy in index.isMultiple(of:2) ? [true,false] : [false,true] {
                let start = CFAbsoluteTimeGetCurrent()
                _ = try render(side:132,textured:true,legacy:legacy)
                let elapsed = (CFAbsoluteTimeGetCurrent()-start)*1000
                if legacy { old.append(elapsed) } else { new.append(elapsed) }
            }
        }
        print("PAPER_GRAIN_RENDER_MEDIAN_MS old=\(old.sorted()[20]) new=\(new.sorted()[20]) samples=40 side=132")
    }

    // Previous production plate, retained only for the opt-in performance comparison.
    private static let legacyFibres: (Path,Path) = {
        var light = Path(), dark = Path(), random = SeededGen(417)
        for i in 0..<1800 {
            let rect = CGRect(x:random.unit(),y:random.unit(),width:0.0015+random.unit()*0.0045,
                              height:0.001+random.unit()*0.0018)
            if i.isMultiple(of:2) { light.addEllipse(in:rect) } else { dark.addEllipse(in:rect) }
        }
        return (light,dark)
    }()
}
