import Testing
import Foundation
import UIKit
import Vision
@testable import Reffi

/// 영수증 OCR 파싱 — 축약 상품명 매핑·소음 제거·수량 추출(순수 로직).
struct ReceiptParserTests {

    private let receipt = [
        "이마트 성수점",
        "2026-07-02 21:11",
        "서울우유1L        2,500",
        "삼겹살 500g      12,900",
        "대파               1,200",
        "코카콜라 1.5L     2,800",
        "합계             19,400",
        "카드승인 12345678",
        "감사합니다",
    ]

    @Test func mapsAbbreviatedProductNames() {
        let found = ReceiptParser.candidates(from: receipt)
        let ids = found.map(\.canonicalID)
        #expect(ids.contains("milk"))         // 서울우유1L → milk (포함 매칭)
        #expect(ids.contains("pork-belly"))   // 삼겹살 → pork-belly
        #expect(ids.contains("green-onion"))  // 대파 → green-onion (양파 오탐 아님)
        #expect(!ids.contains("onion"))
    }

    @Test func dropsNoiseLines() {
        let found = ReceiptParser.candidates(from: receipt)
        for c in found {
            #expect(!c.rawLine.contains("합계"))
            #expect(!c.rawLine.contains("카드"))
            #expect(!c.rawLine.contains("감사합니다"))
        }
        // 가격·날짜뿐인 라인도 후보가 되지 않는다.
        #expect(ReceiptParser.candidates(from: ["19,400", "2026-07-02"]).isEmpty)
    }

    @Test func extractsQuantities() {
        let found = ReceiptParser.candidates(from: receipt)
        let milk = found.first { $0.canonicalID == "milk" }
        let pork = found.first { $0.canonicalID == "pork-belly" }
        #expect(milk?.quantity == Quantity(value: 1, unit: .liter))
        #expect(pork?.quantity == Quantity(value: 500, unit: .gram))
        // 수량 표기가 없으면 1개 기본값.
        let onion = found.first { $0.canonicalID == "green-onion" }
        #expect(onion?.quantity == Quantity(value: 1, unit: .piece))
    }

    /// 45차: 중복 제거의 축이 캐논에서 **정규화 표기**로 바뀌었다 — 같은 캐논으로 떨어지는 서로
    /// 다른 상품(서울우유 1L + 저지방우유 500ml)은 각자 산 물건이라 둘 다 확인 화면에 남아야 한다.
    /// 예전 캐논 축은 두 번째 상품을 화면에서 통째로 지웠다(산 물건의 무성 소실).
    @Test func dedupesByNormalizedNameNotByCanon() {
        let found = ReceiptParser.candidates(from: ["서울우유 1L", "저지방우유 500ml", "우유",
                                                    "서울우유 1L"])
        let milk = found.filter { $0.canonicalID == "milk" }
        #expect(milk.count == 3, "서로 다른 상품 세 줄은 셋 다 남는다")
        #expect(found.count == 3, "같은 표기의 반복(네 번째 줄)만 접힌다")
        // Keep all package sizes; displayed names contain food names only, never POS metadata.
        #expect(milk.map(\.quantity.value) == [1, 500, 1])
    }

    @Test func excludesUnverifiedTextAndNonFoodProducts() {
        let found = ReceiptParser.candidates(from: receipt + [
            "OPEN DAILY", "Customer service", "LEMON SOAP 4.99", "COCONUT SHAMPOO",
            "우유 비누", "사과향 세제", "APPLE STORE", "PAPER TOWEL", "VISA 1234"
        ])
        #expect(found.count == 3)
        #expect(found.allSatisfy { $0.canonicalID != nil })
        #expect(ReceiptParser.candidates(from: ["코카콜라 1.5L", "ㅁ1ㅐ", "x2"]).isEmpty)
    }

    @Test func foodWordsAreNotNoiseSubstrings() {
        #expect(!ReceiptParser.isNonFoodLine("CASHEW 4.99"))
        #expect(ReceiptParser.normalizedProductLine("MILK 3.99 F") == "MILK")
        #expect(ReceiptParser.extractQuantity(from: "MILK 1L") == Quantity(value: 1, unit: .liter))
        #expect(ReceiptParser.extractQuantity(from: "2 lemons") == Quantity(value: 1, unit: .piece))
    }

    @Test func categoryArtworkCoversEveryCategory() {
        for category in FoodGlyph.categoryOrder {
            let glyph = FoodGlyph.categoryRepresentative(category)
            #expect(glyph != .generic)
            #expect(glyph.categoryLabel == category)
        }
    }

    @Test func manualCategorySurvivesEncoding() throws {
        let item = Ingredient(name: "Garden greens", category: "Veg", expiresAt: Date(),
                              glyph: .leaf, categoryOverride: "Veg")
        let decoded = try JSONDecoder().decode(Ingredient.self, from: JSONEncoder().encode(item))
        #expect(decoded.categoryOverride == "Veg")
        #expect(decoded.glyph == .leaf)
        #expect(decoded.canonicalID == nil)
    }

    @Test @MainActor func explicitCategorySurvivesStoreArtworkRefresh() {
        let item = Ingredient(name: "Tomato", category: "Fruit", expiresAt: Date(),
                              glyph: .apple, categoryOverride: "Fruit")
        let store = FridgeStore(ingredients: [item], recipes: [])
        #expect(store.ingredients[0].glyph == .apple)
        #expect(store.ingredients[0].category == "Fruit")
        #expect(store.ingredients[0].canonicalID == "tomato")
    }

    @Test func rejoinsOCRColumnsWithoutMergingAdjacentProducts() {
        let fragments: [ReceiptParser.TextFragment] = [
            .init(text: "3.99", bounds: CGRect(x: 0.8, y: 0.8, width: 0.1, height: 0.02)),
            .init(text: "MILK", bounds: CGRect(x: 0.1, y: 0.8, width: 0.3, height: 0.02)),
            .init(text: "1L", bounds: CGRect(x: 0.6, y: 0.801, width: 0.1, height: 0.02)),
            .init(text: "LEMON", bounds: CGRect(x: 0.1, y: 0.75, width: 0.3, height: 0.02)),
            .init(text: "SOAP", bounds: CGRect(x: 0.5, y: 0.751, width: 0.2, height: 0.02)),
            .init(text: "TOMATO", bounds: CGRect(x: 0.1, y: 0.70, width: 0.3, height: 0.02))
        ]
        let lines = ReceiptParser.readingLines(from: fragments)
        #expect(lines == ["MILK 1L 3.99", "LEMON SOAP", "TOMATO"])
        let found = ReceiptParser.candidates(from: lines)
        #expect(found.map(\.canonicalID) == ["milk", "tomato"])
        #expect(found.first?.quantity == Quantity(value: 1, unit: .liter))
    }

    @Test @MainActor func readsFoodOnlyFromRenderedReceipt() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 700)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 700))
            let lines = ["GROCERY MARKET", "MILK 1L       3.99", "TOMATO       2.49",
                         "LEMON SOAP       4.99", "TOTAL       11.47", "VISA PAYMENT"]
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 50, y: 40 + index * 90), withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 36, weight: .regular),
                    .foregroundColor: UIColor.black
                ])
            }
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true
        request.customWords = IngredientLexicon.shared.entries.flatMap { $0.names.en + $0.names.ko }
        request.minimumTextHeight = 0.005
        try VNImageRequestHandler(cgImage: #require(image.cgImage)).perform([request])
        let fragments = (request.results ?? []).compactMap { observation -> ReceiptParser.TextFragment? in
            guard let text = observation.topCandidates(1).first, text.confidence >= 0.3 else { return nil }
            return .init(text: text.string, bounds: observation.boundingBox)
        }
        let found = ReceiptParser.candidates(from: ReceiptParser.readingLines(from: fragments))
        #expect(found.map(\.canonicalID) == ["milk", "tomato"])
        #expect(found.first?.quantity == Quantity(value: 1, unit: .liter))
    }

    /// **영수증 정규화(44차)** — 접두 코드(냉)·행사·1+1·괄호 코드)와 가격 꼬리를 뗀 뒤 한 번 더
    /// 매칭한다. 원문은 rawLine에 그대로 남는다(정규화는 매칭을 돕는 장식 제거지 개명이 아니다).
    @Test func normalizedPrefixCodesStillMatchTheDictionary() {
        let found = ReceiptParser.candidates(from: ["냉)삼겹살 500g 12,900", "*1+1 대파 1,200"])
        let ids = found.map(\.canonicalID)
        #expect(ids.contains("pork-belly"))
        #expect(ids.contains("green-onion"))
        #expect(ReceiptParser.normalizedProductLine("*1+1 코카콜라 1.5L 2,800") == "코카콜라 1.5L")
        #expect(ReceiptParser.normalizedProductLine("[냉장] 무항생제 특란 30구") == "무항생제 특란 30구")
    }

    /// **미국 영수증 약어 전개(44차)** — 실물 영수증 실측 high-confidence 토큰만.
    /// BF(근거 0건)·GRN(green/grain 중의)·MLK 같은 블로그발 추정은 일부러 없다.
    @Test func expandsVerifiedUSReceiptAbbreviations() {
        let found = ReceiptParser.candidates(from: ["GV ALMD MILK 64OZ", "BNLS CKN BRST 2.1LB",
                                                    "KS ORG BROC 3CT"])
        let ids = found.map(\.canonicalID)
        #expect(ids.contains("almond-milk"))
        #expect(ids.contains("chicken-breast"))
        #expect(ids.contains("broccoli"))
        // 묶음 곱셈 꼬리는 면세 별표보다 먼저 소비된다 — "2L*6"의 *는 면세 마크가 아니다.
        #expect(ReceiptParser.normalizedProductLine("삼다수 그린 2L*6") == "삼다수 그린 2L")
        // "한우 1+등급"의 1+는 행사 코드가 아니다 — 숫자+숫자 꼴만 행사로 본다.
        #expect(ReceiptParser.normalizedProductLine("한우 1+등급 등심 100G") == "한우 1+등급 등심 100G")
    }

    /// **개봉 라이프사이클(44차 오너 결정)** — 밀봉 가공식품은 미개봉 장기 기한으로 살다가,
    /// 2주 주기 확인에서 "개봉했다"가 되는 순간 개봉 후 기한으로 줄어든다.
    @Test func sealedLifecycleShortensExpiryOnOpen() {
        let spam = Ingredient(name: "스팸", category: "가공", daysLeft: 1000,
                              quantity: Quantity(value: 1, unit: .piece), glyph: .can,
                              boughtDaysAgo: 15)
        var s = spam
        s.canonicalID = "spam"
        #expect(s.sealedCheckDue(), "밀봉 + 미개봉 + 15일 경과 → 확인 대상")
        s.sealedCheckAt = Date()
        #expect(!s.sealedCheckDue(), "방금 '아직'이라고 답했다 — 2주 뒤에 다시 묻는다")
        s.openedAt = Date()
        #expect(!s.sealedCheckDue(), "개봉했으면 더는 묻지 않는다")
        #expect(s.effectiveDaysLeft <= 3, "개봉 후 기한(스팸 3일)으로 줄어든다")
        // 원 기한이 더 짧으면 개봉 기록이 기한을 늘리지 않는다(min).
        var short = spam
        short.canonicalID = "spam"
        short.expiresAt = Ingredient.day(offset: 1)
        short.openedAt = Date()
        #expect(short.effectiveDaysLeft <= 1)
        // 비밀봉 항목은 확인 대상이 아니다.
        let onion = Ingredient(name: "양파", category: "채소", daysLeft: 5,
                               quantity: Quantity(value: 1, unit: .piece), glyph: .onion,
                               boughtDaysAgo: 20)
        var o = onion
        o.canonicalID = "onion"
        #expect(!o.sealedCheckDue())
    }

    @Test func compositeProductsNeverBecomeTheirComponentIngredients() {
        let found = ReceiptParser.candidates(from: ["검은콩 고칼슘 두유 200ml×24", "아침에주스 포도1. 8L",
            "PEPPER BELL RED 2 EA", "POTATO SWEET 1LB", "SPAGHETTI SQUASH EACH 2.69",
            "REESE EGG 1.99", "BAREBELLS CHOCOLATE DOUGH 2.29", "SPINDRIFT ORANGE MANGO 7.49"])
        #expect(found.map(\.canonicalID) == ["soy-milk", "juice", "bell-pepper", "sweet-potato"])
        #expect(found[0].quantity == Quantity(value: 4800, unit: .milliliter))
        #expect(found[1].quantity == Quantity(value: 1.8, unit: .liter))
        #expect(found.allSatisfy { $0.requiresConfirmation })
        #expect(ReceiptParser.candidates(from: ["APPLE CANDLE", "CHICKEN DOG FOOD", "EGG SHAMPOO", "MILK STOUT"]).isEmpty)
    }

    @Test func returnsAndQuantityFragmentsCannotCreateStock() {
        #expect(ReceiptParser.candidates(from: ["두부450g", "반품총액: -19,700"]).isEmpty)
        #expect(ReceiptParser.candidates(from: ["Milk 1L", "REFUND TOTAL $3.99"]).isEmpty)
        #expect(ReceiptParser.candidates(from: ["TEA 0 0.49/EA", "7EA @ 0.49/EA"]).isEmpty)
        #expect(ReceiptParser.candidates(from: ["Returns within 30 days", "Milk 1L"]).count == 1)
    }

    @Test func automaticSelectionRequiresNameQuantityAndOCRCertainty() {
        let candidates = ReceiptParser.candidates(from: ["MILK 1L 3.99", "EGGS 12CT 4.99", "APPLE 2.99", "브랜드두부 300g"])
        #expect(candidates.count == 4)
        #expect(candidates.prefix(2).allSatisfy { !$0.requiresConfirmation })
        #expect(candidates.suffix(2).allSatisfy { $0.requiresConfirmation })
        #expect(candidates[2].quantityNeedsConfirmation)
        let lowQuality = ReceiptParser.candidates(from: [ReceiptParser.TextFragment(text: "MILK 1L", bounds: CGRect(x: 0, y: 0, width: 1, height: 0.1), confidence: 0.5)])
        #expect(lowQuality.first?.requiresConfirmation == true)
        let uncertainCount = ReceiptParser.candidates(from: [
            ReceiptParser.TextFragment(text: "BANANA 1.61", bounds: CGRect(x: 0, y: 0.8, width: 1, height: 0.04)),
            ReceiptParser.TextFragment(text: "7 @ $0.23", bounds: CGRect(x: 0, y: 0.6, width: 1, height: 0.04), confidence: 0.3)])
        #expect(uncertainCount.first?.quantityNeedsConfirmation == true)
        #expect(ReceiptParser.candidates(from: ["MILK 1L 2 7.98"]).first?.requiresConfirmation == true)
    }

    @Test func verifiesPurchaseCountsAndConvertsUSUnits() {
        let bananas = ReceiptParser.candidates(from: ["BANANAS 1.61", "7 @ $0.23"])
        #expect(bananas.first?.quantity == Quantity(value: 7, unit: .piece))
        #expect(bananas.first?.requiresConfirmation == false)
        let wrongTotal = ReceiptParser.candidates(from: ["BANANAS 1.61", "8 @ $0.23"])
        #expect(wrongTotal.first?.quantityNeedsConfirmation == true)
        let milk = ReceiptParser.candidates(from: ["우유1L", "8801234567890 2500 2 5000"])
        #expect(milk.first?.quantity == Quantity(value: 2, unit: .liter))
        #expect(abs(ReceiptParser.extractQuantity(from: "OATS 2LB").value - 907.18474) < 0.001)
        #expect(ReceiptParser.extractQuantity(from: "햇반 210g*3").value == 630)
        #expect(ReceiptParser.quantityEvidence("MIX 200g 300g") == nil)
        #expect(ReceiptParser.quantityEvidence("$2.99/lb") == nil)
        #expect(ReceiptParser.quantityEvidence("두유200ml※24") == nil)
        #expect(ReceiptParser.candidates(from: ["PEACH 930ml"]).isEmpty)
        #expect(ReceiptParser.candidates(from: ["Milk 1L", "SUBTOTAL 3.99", "Tea 500ml"]).count == 1)
        let columns = ["Milk 1L", "Apple 2EA", "Tofu 300g", "Banana 4EA"].enumerated().map { i, text in
            ReceiptParser.TextFragment(text: text, bounds: CGRect(x: i % 2 == 0 ? 0 : 0.6, y: i < 2 ? 0.8 : 0.6, width: 0.3, height: 0.04))
        }
        #expect(ReceiptParser.containsMultipleReceipts(columns))
        #expect(ReceiptParser.candidates(from: columns).isEmpty)
        let repeated = ReceiptParser.candidates(from: ["Milk 1L", "Milk 1L"])
        #expect(repeated.count == 1)
        #expect(repeated.first?.quantityNeedsConfirmation == true)
    }

    // MARK: 상호(구매처) 추출

    @Test func extractsStoreNameFromTopLine() {
        #expect(ReceiptParser.storeName(from: receipt) == "이마트 성수점")
    }

    @Test func storeNameNilWhenAbsent() {
        // 상단 몇 줄이 전부 날짜/소음/가격뿐 — 상호 후보가 없다.
        let lines = ["2026-07-02 21:11", "합계             19,400", "카드승인 12345678"]
        #expect(ReceiptParser.storeName(from: lines) == nil)
    }
}
