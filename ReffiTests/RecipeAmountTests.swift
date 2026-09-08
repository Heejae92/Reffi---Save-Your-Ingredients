import Foundation
import Testing
@testable import Reffi

struct RecipeAmountTests {
    @Test func olderRecipesStillDecodeWithoutAmounts() throws {
        let data = Data(#"{"ref":"egg","en":"eggs","ko":"계란"}"#.utf8)
        let item = try JSONDecoder().decode(Recipe.Item.self, from: data)
        #expect(item.amount == nil)
        #expect(item.ref == "egg")
    }

    @Test func amountsRoundTripWithoutChangingInventoryMatching() throws {
        var recipe = Recipe.userRecipe(name: "Eggs", ingredientNames: ["egg"], minutes: 5)
        let egg = Ingredient(name: "egg", category: "Protein", daysLeft: 3,
                             quantity: Quantity(value: 1, unit: .piece), glyph: .egg)
        let before = RecipeRecommender.result(for: recipe, ingredients: [egg])
        recipe.ingredients[0].amount = .init(en: "4 eggs", ko: "계란 4개")
        let restored = try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe))
        #expect(restored == recipe)
        let after = RecipeRecommender.result(for: restored, ingredients: [egg])
        #expect(after.used.map(\.id) == before.used.map(\.id))
        #expect(after.used.first?.quantity.value == 1)
    }

    @Test func representativeRecipesHaveBilingualAmountsForEveryIngredient() {
        let ids: Set<String> = ["kimchi-jjigae", "doenjang-jjigae", "kimchi-fried-rice",
            "egg-fried-rice", "gyeran-mari", "kongnamul-guk", "dubu-jorim", "bok-choy-stir-fry",
            "tomato-egg-stir-fry", "tomato-pasta", "aglio-e-olio", "scrambled-eggs",
            "french-toast", "grilled-cheese"]
        let recipes = RecipeCatalog.loadSeed().filter { ids.contains($0.id) }
        #expect(recipes.count == ids.count)
        for recipe in recipes {
            #expect((recipe.servings ?? 0) > 0)
            for item in recipe.ingredients {
                #expect(item.amount?.en.isEmpty == false, "\(recipe.id): \(item.en)")
                #expect(item.amount?.ko?.isEmpty == false, "\(recipe.id): \(item.en)")
            }
        }
    }
}
