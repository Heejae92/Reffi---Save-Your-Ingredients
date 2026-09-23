import Foundation

/// 음식 모티프 종류 — 종이컷 실루엣(`PaperSilhouette`)이 이 값으로 단일 쉐입을 그린다.
/// 케이스 선언만 여기(Shared) 둔다 — 위젯·워치가 같은 그림을 그리려면 이 enum이 필요하지만,
/// 이름→글리프 판정(`match`·`dishGlyph`)은 재료 사전(`IngredientLexicon`)에 기대는 앱 전용이라
/// `Ingredient.swift`의 확장에 남긴다.
enum FoodGlyph: String, Codable, CaseIterable {
    // 채소
    case leaf, root, squash, onion, tomato, pepper, mushroom, broccoli, potato, garlic
    case cucumber, pea, cabbage, chili, pumpkin        // 신규 채소
    case eggplant, sweetPotato, ginger, seaweed        // v2 신규 채소·해조
    // 과일
    case apple, citrus, berry
    case avocado, banana                               // 신규 과일
    case grape, watermelon, pineapple, mango           // v2 신규 과일
    // 단백질
    case egg, tofu, meat, poultry, fish, shrimp
    case sausage, bacon                                // v2 신규 육류
    case crab, squid, clam                             // v2 신규 해산물
    // 유제품
    case milk, cheese, bread
    case yogurt, butter                                // v2 신규 유제품
    // 곡류·저장식품
    case rice, noodles, corn                           // 신규 곡류
    case sauceBottle, can                              // 신규 저장식품
    case honey, dumpling                               // v2 신규 저장식품·기타
    case gimbap                                        // v3 요리형(만두 선례) — 재료가 아니라 메뉴 자체가 모티프
    // Dedicated silhouettes for previously shared or missing ingredients.
    case scallion, radish, beet, lotusRoot, burdock, enoki, napa, sprout
    case bokChoy, asparagus, celery, cauliflower, pear, peach, blueberry, cherry
    case kiwi, melon, orange, lime, salmon, octopus, fishCake, kimchi
    case riceCake, flour, grains, spice, beans, nuts, walnut, jar
    case oil, water, coffee, tea, juice, chocolate, olive, driedFruit
    case cornDog, ricePaper, iceCream
    case salt, peppercorn, curryPowder, cinnamon, starAnise, wasabi
    case generic

    /// 톨러런트 디코드 — 미지의 rawValue(향후 케이스 추가·데이터 오염)가 필드 하나로 끝나게
    /// .generic으로 폴백한다. strict하게 두면 글리프 하나가 스냅샷 전체를 격리시킨다.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FoodGlyph(rawValue: raw) ?? .generic
    }
}
