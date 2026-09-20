import Foundation

/// 영수증 OCR 텍스트 → 재료 후보 — **순수 로직**(Vision 의존 없음, 유닛 테스트 대상).
/// 마트 영수증의 축약 상품명("서울우유1L", "삼겹살 500g")을 정본 재료 사전 매칭으로
/// canonical ID에 매핑하고, 합계/카드/전화번호 같은 소음 라인을 걸러낸다.
///
/// 식재료 사전으로 확인되지 않은 텍스트는 표시하거나 저장하지 않는다.
enum ReceiptParser {

    struct Candidate: Identifiable {
        let id = UUID()
        var rawLine: String        // OCR 원문(확인 화면 참고용)
        var canonicalID: String?   // 스캔 결과는 식재료 사전 매칭 ID만 허용
        var name: String           // 사전 대표 표기 또는 동일 재료의 다른 상품명
        var quantity: Quantity
        var requiresConfirmation = true
        var quantityNeedsConfirmation = true
    }

    /// 상품명이 아닌 영수증 상용구 — 포함되면 라인 전체를 버린다.
    static let noiseKeywords: [String] = [
        // ko
        "합계", "총액", "총 액", "부가세", "과세", "면세", "카드", "현금", "승인", "거스름",
        "포인트", "할인", "쿠폰", "봉투", "반품", "교환", "전화", "사업자", "대표", "주소",
        "감사합니다", "영수증", "결제", "잔액", "매장", "번호",
        // en
        "total", "subtotal", "tax", "cash", "card", "change", "approval", "thank",
        "receipt", "balance", "tel", "store no",
    ]

    /// Match English noise as tokens so "hotel" does not match "tel" and
    /// "cashew" does not match "cash". Reject non-food products before food matching.
    static func isNonFoodLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        let tokens = Set(IngredientLexicon.matchTokens(lower))
        let nonFood = ["soap", "detergent", "shampoo", "conditioner", "lotion", "cleaner",
                       "towel", "towels", "tissue", "tissues", "napkin", "bag", "bags", "scent", "candle", "toothpaste",
                       "pet", "dog", "cat", "diaper", "diapers", "supplement", "vitamin", "toner", "perfume", "sanitizer", "bleach", "wrap", "foil", "pay", "rewards",
                       "store", "market", "supermarket", "www", "http", "payment", "visa", "mastercard", "debit", "credit", "cashier", "discount",
                       "세제", "비누", "샴푸", "린스", "치약", "휴지", "물티슈", "세정", "방향제", "주방타월"]
        return (noiseKeywords + nonFood).contains { word in
            if word.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) }) {
                return lower.contains(word)
            }
            return word.contains(" ") ? lower.contains(word) : tokens.contains(word)
        }
    }

    struct TextFragment {
        let text: String
        let bounds: CGRect
        var confidence: Float = 1
    }

    /// Vision can return product names, units and prices as separate boxes.
    /// Rejoin only boxes on the same baseline, then read each row left to right.
    static func readingLines(from fragments: [TextFragment]) -> [String] {
        readingRows(from: fragments).map(\.text)
    }

    static func readingRows(from fragments: [TextFragment]) -> [TextFragment] {
        var rows: [[TextFragment]] = []
        for fragment in fragments.sorted(by: { $0.bounds.midY > $1.bounds.midY }) {
            if let index = rows.firstIndex(where: { row in
                let anchor = row[0].bounds
                let overlaps = row.contains { $0.bounds.intersection(fragment.bounds).width > min($0.bounds.width, fragment.bounds.width) * 0.2 }
                return !overlaps && abs(anchor.midY - fragment.bounds.midY) < min(anchor.height, fragment.bounds.height) * 0.4
            }) {
                rows[index].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return rows.map { row in
            TextFragment(text: row.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text).joined(separator: " "),
                         bounds: row.dropFirst().reduce(row[0].bounds) { $0.union($1.bounds) },
                         confidence: row.map(\.confidence).min() ?? 0)
        }
    }

    static func candidates(from fragments: [TextFragment]) -> [Candidate] {
        guard !containsMultipleReceipts(fragments) else { return [] }
        let rows = readingRows(from: fragments)
        return candidates(from: rows.map(\.text)).map { candidate in
            var result = candidate
            if let index = rows.firstIndex(where: { $0.text == candidate.rawLine }) {
                if rows[index].confidence < 0.9 { result.requiresConfirmation = true }
                // The count also has independent arithmetic evidence. Vision often gives
                // 0.5 to a row whose @ symbol is misread while all three numbers agree.
                if index + 1 < rows.count,
                   purchaseCount(product: rows[index].text, following: rows[index + 1].text) != nil,
                   rows[index + 1].confidence < 0.5 {
                    result.requiresConfirmation = true
                    result.quantityNeedsConfirmation = true
                }
            } else { result.requiresConfirmation = true }
            return result
        }
    }

    /// Repeated independent food names far apart on the same baseline indicate
    /// side-by-side receipts. Joining those columns would corrupt transaction quantities.
    static func containsMultipleReceipts(_ fragments: [TextFragment]) -> Bool {
        let products = fragments.filter { !isNonFoodLine($0.text) && productMatch(normalizedProductLine($0.text)) != nil }
        var conflictingRows = Set<Int>()
        for (i, left) in products.enumerated() {
            for right in products.dropFirst(i + 1) {
                if abs(left.bounds.midX - right.bounds.midX) > 0.3,
                   abs(left.bounds.midY - right.bounds.midY) < min(left.bounds.height, right.bounds.height) * 0.6 {
                    conflictingRows.insert(Int(left.bounds.midY * 100))
                }
            }
        }
        return conflictingRows.count >= 2
    }

    /// OCR 라인들에서 식재료 후보만 추출하고 정규화 상품명 기준으로 중복을 제거한다.
    static func candidates(from lines: [String],
                           lexicon: IngredientLexicon = .shared) -> [Candidate] {
        // A refund or mixed purchase/refund image must never create positive stock.
        // Policy prose ("returns within 30 days") is not a transaction marker.
        guard !containsReturnTransaction(lines) else { return [] }
        var seenNames = Set<String>()
        var out: [Candidate] = []
        for (index, raw) in lines.enumerated() {
            if isTransactionEnd(raw) { break }
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 2, !isNonFoodLine(line), !isQuantityRow(line),
                  line.range(of: #"(?:^|\s)-\s*\d"#, options: .regularExpression) == nil else { continue }
            let cleaned = normalizedProductLine(line)
            guard let match = productMatch(cleaned, lexicon: lexicon) else { continue }
            guard seenNames.insert(cleaned.lowercased()).inserted else {
                if let existing = out.firstIndex(where: { normalizedProductLine($0.rawLine).lowercased() == cleaned.lowercased() }) {
                    out[existing].requiresConfirmation = true
                    out[existing].quantityNeedsConfirmation = true
                }
                continue
            }
            var amount = quantityEvidence(line)
            // Count-size grading on produce (e.g. Hass avocado 40 CT) is not a purchase count.
            if line.range(of: #"(?i)\bct\b"#, options: .regularExpression) != nil,
               let glyphName = lexicon.entry(id: match.id)?.glyph,
               let category = FoodGlyph(rawValue: glyphName)?.categoryLabel,
               ["Fruit", "Veg"].contains(category) { amount = nil }
            // Quantity lines belong to the immediately preceding product only. Do not
            // cross another product, total or barcode to guess a quantity.
            if index + 1 < lines.count {
                let next = purchaseCount(product: line, following: lines[index + 1])
                if let next {
                    if let current = amount, current.unit != .piece, next.unit == .piece {
                        amount = Quantity(value: current.value * next.value, unit: current.unit)
                    } else if amount == nil { amount = next }
                    else { amount = nil } // two count measures need packaging confirmation
                }
            }
            if let amount, [.liter, .milliliter].contains(amount.unit),
               let glyphName = lexicon.entry(id: match.id)?.glyph,
               let category = FoodGlyph(rawValue: glyphName)?.categoryLabel,
               ["Fruit", "Veg", "Meat", "Seafood"].contains(category) { continue }
            let knownQuantity = amount?.isValid == true && !hasUnresolvedCount(line)
            out.append(Candidate(rawLine: line, canonicalID: match.id,
                                 name: lexicon.entry(id: match.id)?.displayName ?? cleaned,
                                 quantity: amount ?? Quantity(value: 1, unit: .piece),
                                 requiresConfirmation: !match.exact || !knownQuantity,
                                 quantityNeedsConfirmation: !knownQuantity))
        }
        return out
    }

    static func isTransactionEnd(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "").lowercased()
        return ["합계", "총구매액", "결제대상", "면세물품", "과세물품", "subtotal", "total", "balance", "amountdue"]
            .contains { compact.hasPrefix($0) }
    }

    static func containsReturnTransaction(_ lines: [String]) -> Bool {
        lines.contains { line in
            line.range(of: #"(?i)(반품\s*(총액|금액|영수증)|환불\s*(금액|영수증)|^\s*(return|refund|void)(?:\s+(transaction|receipt|total))?\s*[:$\d-]*$|\b(refund|return)\s+total\b)"#, options: .regularExpression) != nil
        }
    }

    /// Associate a purchase count only when unit price × count equals the item's total.
    /// Supports barcode/price/count/total rows and US count @ price continuation rows.
    static func purchaseCount(product: String, following: String) -> Quantity? {
        func captures(_ pattern: String, _ text: String) -> [Double]? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
            let numbers = (1..<match.numberOfRanges).compactMap { i -> Double? in
                guard let range = Range(match.range(at: i), in: text) else { return nil }
                return Double(text[range].replacingOccurrences(of: ",", with: ""))
            }
            return numbers.count == match.numberOfRanges - 1 ? numbers : nil
        }
        if let n = captures(#"^\s*\*?\d{6,14}\s+([\d,]+)\s+(\d{1,3})\s+([\d,]+)\s*[*#]?\s*$"#, following),
           n[1] > 0, abs(n[0] * n[1] - n[2]) < 0.01 {
            return Quantity(value: n[1], unit: .piece)
        }
        if let n = captures(#"^\s*(\d{1,3})\s*(?:ea)?\s*[@08]\s*\$?([\d]+\.[\d]{2})(?:\s*/\s*ea)?\s*$"#, following),
           let total = captures(#"\$?(\d+\.\d{2})\s*[A-Z]?\s*$"#, product)?.first,
           n[0] > 0, abs(n[0] * n[1] - total) < 0.01 {
            return Quantity(value: n[0], unit: .piece)
        }
        return nil
    }

    /// A trailing count column without a verified table relationship is ambiguous.
    private static func hasUnresolvedCount(_ line: String) -> Bool {
        line.range(of: #"(?i)(?:kg|g|ml|l|oz|lb|개|ea|팩|병|봉)\s+\d+\s+[$₩]?[\d,.]+\s*[A-Z]?$"#, options: .regularExpression) != nil
    }

    /// Unit-price rows can resemble food after OCR (7EA → TEA). Never match them as names.
    static func isQuantityRow(_ line: String) -> Bool {
        line.range(of: #"(?i)(/\s*(ea|lb|kg|oz)\b|^\s*\d+(?:\.\d+)?\s*(ea|lb|kg|oz)\b|^\s*\d+\s*[@8]\s*\$)"#, options: .regularExpression) != nil
    }

    private struct ProductRules: Decodable {
        struct Override: Decodable { let pattern: String; let id: String? }
        let overrides: [Override]
        let removableTokens: [String]
    }
    private static let productRules: ProductRules = {
        guard let url = Bundle.main.url(forResource: "receipt-products", withExtension: "json"),
              let data = try? Data(contentsOf: url), let rules = try? JSONDecoder().decode(ProductRules.self, from: data)
        else { return ProductRules(overrides: [], removableTokens: []) }
        return rules
    }()

    /// Receipt matching deliberately does not inherit free-text fuzzy matching.
    /// A recognized component of an unknown product is not a verified ingredient.
    static func productMatch(_ raw: String, lexicon: IngredientLexicon = .shared) -> (id: String, exact: Bool)? {
        let expanded = expandedAbbreviations(raw).lowercased()
        for rule in productRules.overrides where expanded.range(of: rule.pattern, options: .regularExpression) != nil {
            guard let id = rule.id, lexicon.entry(id: id) != nil else { return nil }
            return (id, false) // semantic override needs explicit review of the branded product
        }
        let stripped = expanded
            .replacingOccurrences(of: #"(?i)\b\d+(?:\.\s*\d+)?\s*(?:kg|g|ml|l|oz|lbs?|ct|ea|개|입|팩|병|봉)\b"#, with: " ", options: .regularExpression)
        let tokens = IngredientLexicon.matchTokens(stripped).filter { !productRules.removableTokens.contains($0) }
        guard !tokens.isEmpty else { return nil }
        let name = tokens.joined(separator: " ")
        if let id = lexicon.exactCanonicalID(for: name) { return (id, true) }
        // English plural forms, including reordered multi-word POS descriptions.
        let singular = tokens.map { token -> String in
            if token.hasSuffix("ies") { return String(token.dropLast(3)) + "y" }
            if token.hasSuffix("s") && !token.hasSuffix("ss") { return String(token.dropLast()) }
            return token
        }
        if let id = lexicon.exactCanonicalID(for: singular.joined(separator: " ")) { return (id, true) }
        let ordered = singular.sorted()
        let unordered = lexicon.entries.filter { entry in
            entry.names.en.contains { IngredientLexicon.matchTokens($0).sorted() == ordered }
        }
        if unordered.count == 1 { return (unordered[0].id, true) }
        // Korean brands concatenate the head noun. Keep only a terminal head noun;
        // multiple independently matched food components require review and are not guessed.
        if name.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) }),
           let id = lexicon.headNounCanonicalID(for: name) { return (id, false) }
        if let id = lexicon.headNounCanonicalID(for: name) { return (id, false) }
        return nil
    }

    /// 영수증 상품명 정규화 — 매칭을 막는 장식만 뗀다(공격적 변형 금지, 원문은 rawLine에 남는다).
    /// 규칙과 순서는 44차 실측 리서치(CU·GS25·이마트24 상품 마스터 + 국세청 면세 표기) 근거다:
    /// ① 묶음 곱셈 꼬리("2L*6") — 면세 별표(*)보다 **먼저** 소비해야 한다(같은 기호의 두 의미).
    /// ② 앞의 면세 별표·행사 코드("1+1 ") — "\d+\d" 꼴만: "한우 1+등급"의 1+는 등급이라 건드리면
    ///    정육 라인이 파괴된다(숫자+숫자 요구가 그 함정을 구조적으로 피한다).
    /// ③ 접두 코드 "농심)"·"미트)"·"7P)" — 편의점 POS 관행(1~6자 + 짝 없는 닫는 괄호).
    /// ④ 대괄호 짧은 코드("[냉장]") ⑤ 카테고리 꼬리("…/돼지고기") ⑥ 가격 꼬리 ⑦ 공백 정리.
    static func normalizedProductLine(_ line: String) -> String {
        var s = line
        for pattern in [#"\s*[*xX×]\s*\d+\s*$"#,
                        #"^\*+\s*"#, #"^\d\+\d\s+"#, #"^행사\s+"#,
                        #"^[^\s()\[\]]{1,6}\)\s*"#, #"\[[^\]]{1,6}\]"#,
                        #"\s*/\s*(?:돼지고기|소고기|닭고기|수산물?|채소|과일)\s*$"#,
                        #"\s+(?:[$₩]\s*)?\d[\d,]*\.\d{2}(?:\s+[A-Z])?\s*$"#,
                        #"\s+[\d,]{3,}원?$"#] {
            s = s.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return s.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// 미국 영수증 약어 전개(44차) — 실물 영수증(Walmart·Costco·TJ's)과 CA WIC 품목파일 8,048행에서
    /// **실측 확인된 high-confidence 토큰만** 싣는다. 2차 블로그발 추정(MLK·CHZ·BF)은 넣지 않는다 —
    /// BF는 실측 0건에 breakfast·buffalo와 충돌하고, GRN은 같은 영수증에서 green과 grain 두 뜻으로
    /// 쓰였다(둘 다 제외). 대문자 단독 토큰일 때만 전개한다(소문자 일반 단어 오폭 방지).
    static let receiptTokenExpansion: [String: String] = [
        "BRST": "breast", "CKN": "chicken", "CHED": "cheddar", "CRM": "cream",
        "TOM": "tomato", "ALMD": "almond", "SAUS": "sausage", "BROC": "broccoli",
        "HNY": "honey", "CHOC": "chocolate", "GRK": "greek", "SWT": "sweet",
        "CNUT": "coconut", "PNUT": "peanut", "OJ": "orange juice",
        // 수식·브랜드·단위 — 의미가 아니라 소음이라 전개 대신 제거한다.
        "ORG": "", "FZN": "", "BNLS": "", "DK": "", "W/": "",
        "GV": "", "KS": "", "TJ'S": "",
        "OZ": "", "LB": "", "CT": "", "EA": "", "QT": "", "GAL": "",
    ]

    static func expandedAbbreviations(_ s: String) -> String {
        s.split(separator: " ").map { token -> String in
            guard token == token.uppercased() else { return String(token) }
            return receiptTokenExpansion[String(token)] ?? String(token)
        }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    /// 라인에서 수량 추출 — "500g", "1L", "2개", "3 ea" 패턴. 가격("2,500")은 단위가 없어 안 잡힌다.
    static func extractQuantity(from line: String) -> Quantity {
        quantityEvidence(line) ?? Quantity(value: 1, unit: .piece)
    }

    /// Evidence is optional: no explicit amount must not silently become a confirmed 1 ea.
    static func quantityEvidence(_ raw: String) -> Quantity? {
        guard raw.range(of: #"[※✕]\s*\d"#, options: .regularExpression) == nil else { return nil }
        let line = raw.lowercased().replacingOccurrences(of: #"(\d)\.\s+(\d)"#, with: "$1.$2", options: .regularExpression)
        let pattern = #"(?<![\d.,-])([0-9]+(?:\.[0-9]+)?)\s*(fl\s*oz|lbs?|oz|gallons?|gal|kg|ml|g|l|개|ea|ct|팩|병|봉)(?![a-z])(?:\s*[*x×]\s*(\d+))?"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let full = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, range: full)
        // Several amounts or a unit-price expression require explicit confirmation.
        guard matches.count == 1, let match = matches.first,
              let valueRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line),
              let value = Double(line[valueRange]), value > 0 else { return nil }
        let prefix = String(line[..<Range(match.range, in: line)!.lowerBound])
        guard !prefix.hasSuffix("/"), !prefix.hasSuffix("$") else { return nil }
        var multiplier = 1.0
        if let range = Range(match.range(at: 3), in: line) { multiplier = Double(line[range]) ?? 0 }
        let unit = String(line[unitRange])
        let amount: Quantity
        switch unit {
        case "lb", "lbs": amount = .init(value: value * 453.59237, unit: .gram)
        case "oz": amount = .init(value: value * 28.349523125, unit: .gram)
        case "fl oz", "floz": amount = .init(value: value * 29.5735295625, unit: .milliliter)
        case "gallon", "gallons", "gal": amount = .init(value: value * 3.785411784, unit: .liter)
        case "ct": amount = .init(value: value, unit: .piece)
        default: amount = Quantity.parseLegacy("\(value)\(unit)")
        }
        let result = Quantity(value: amount.value * multiplier, unit: amount.unit)
        return result.isValid ? result : nil
    }

    /// 상호(구매처) 추출 — **순수 함수**. 영수증 최상단 몇 줄 중, 소음 라인·날짜 라인·가격/숫자뿐인 라인·
    /// 재료 사전에 매칭되는 라인(=상품명이지 상호가 아님)을 제외한 첫 텍스트 라인을 상호 후보로 본다.
    /// 길이 2~20자 — 너무 짧은 토막(단위 등)이나 긴 안내문은 상호가 아닐 확률이 높아 배제.
    static func storeName(from lines: [String], lexicon: IngredientLexicon = .shared) -> String? {
        for raw in lines.prefix(5) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (2...20).contains(line.count) else { continue }
            if isNonFoodLine(line) { continue }
            // 숫자·기호뿐인 라인(가격·바코드) 제외.
            if line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace || $0.isSymbol }) {
                continue
            }
            // 날짜/시각 라인("2026-07-02 21:11") 제외.
            if line.range(of: #"^\d{4}[-./]\d{1,2}[-./]\d{1,2}"#, options: .regularExpression) != nil {
                continue
            }
            // 재료 사전에 매칭되는 라인은 상품명 — 상호 후보에서 제외. 후보 생성과 **같은 눈**으로
            // 본다(정규화·약어 전개 포함) — 아니면 "BNLS CKN BRST"가 상품인 줄 모르고 상호가 된다.
            if lexicon.canonicalID(for: line) != nil
                || lexicon.canonicalID(for: expandedAbbreviations(normalizedProductLine(line))) != nil {
                continue
            }
            return line
        }
        return nil
    }
}
