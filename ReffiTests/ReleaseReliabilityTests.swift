import Foundation
import Testing
@testable import Reffi

struct ReleaseReliabilityTests {
    @Test @MainActor func expiredLegacySessionKeepsTheSavedLocalOwner() throws {
        let owner = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FridgeStore(ingredients: SampleData.ingredients,
                                persistenceURL: directory.appendingPathComponent("fridge-guest.json"))
        try store.switchAccount(to: owner, inheritGuest: true, directory: directory)
        let expected = store.ingredients
        let restoredOwner = DataOwner.localOwner(authenticated: nil, stored: owner)
        try store.switchAccount(to: restoredOwner, inheritGuest: false, directory: directory)
        #expect(store.ingredients == expected)
        #expect(!store.ingredients.isEmpty)
        #expect(DataOwner.localOwner(authenticated: nil, stored: nil) == nil)
        let explicitlyCleared = DataOwner.localOwner(authenticated: nil, stored: owner, preserveSavedOwner: false)
        #expect(explicitlyCleared == nil)
        try store.switchAccount(to: explicitlyCleared, inheritGuest: false, directory: directory)
        #expect(store.ingredients.isEmpty, "Explicit clearing leaves the old owner; expiration does not")
    }

    @Test func editableQuantityRejectsBlankAndPartialOrInvalidNumbers() {
        let locale = Locale(identifier: "en_US")
        for input in ["", " ", ".", "-1", "0", "2abc", "1..2", "1,000", "nan", "inf"] {
            #expect(Quantity.inputValue(input, locale: locale) == nil)
        }
        #expect(Quantity.inputValue("2", locale: locale) == 2)
        #expect(Quantity.inputValue(".5", locale: locale) == 0.5)
        #expect(Quantity.inputValue("0.8", locale: locale) == 0.8)
        #expect(Quantity.inputValue("0,8", locale: Locale(identifier: "de_DE")) == 0.8)
    }

    @Test func expiryProvenanceSurvivesSavingAndLegacyDatesAreUnverified() throws {
        let ingredient = Ingredient(name: "Milk", category: "Dairy", expiresAt: Ingredient.day(offset: 7))
        let encoded = try JSONEncoder().encode(ingredient)
        #expect(try JSONDecoder().decode(Ingredient.self, from: encoded).expiryIsEstimated == false)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "expiryIsEstimated")
        let legacy = try JSONDecoder().decode(Ingredient.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.expiryIsEstimated)
        #expect(legacy.dDayText.hasPrefix("≈"))
    }

    @Test @MainActor func failedWriteIsVisibleAndRetryPreservesStockWithoutDuplicates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("blocked directory".utf8).write(to: directory)
        let url = directory.appendingPathComponent("fridge.json")
        let store = FridgeStore(ingredients: [], persistenceURL: url)
        let milk = Ingredient(name: "Milk", category: "Dairy", expiresAt: Ingredient.day(offset: 7),
                              quantity: Quantity(value: 2, unit: .liter), expiryIsEstimated: true)
        #expect(!store.add(milk))
        #expect(store.hasSaveError)
        #expect(store.ingredients.count == 1)
        #expect(store.ingredients.first?.id == milk.id)
        #expect(store.ingredients.first?.quantity == milk.quantity)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(store.retrySave())
        #expect(!store.hasSaveError)
        #expect(store.add(milk))
        let saved = try #require(FridgeStore.decodeSnapshot(Data(contentsOf: url)))
        #expect(saved.ingredients.count == 1)
        #expect(saved.ingredients[0].quantity == milk.quantity)
        #expect(saved.ingredients[0].expiryIsEstimated)
    }

    @Test @MainActor func exactLeftoverUsesCompatibleUnitsAndUndoRestoresOriginal() throws {
        let recipe = try #require(RecipeCatalog.loadSeed().first { $0.ingredients.contains { $0.ref == "milk" } })
        var milk = Ingredient(name: "Milk", category: "Dairy", expiresAt: Ingredient.day(offset: 7),
                              quantity: Quantity(value: 1, unit: .liter))
        milk.canonicalID = "milk"
        let store = FridgeStore(ingredients: [milk])
        #expect(store.cook(RecipeRecommender.result(for: recipe, ingredients: [milk])))
        let session = store.activeCook
        #expect(!store.finishCooking(remaining: [milk.id: Quantity(value: 2, unit: .liter)]))
        #expect(store.activeCook == session)
        #expect(store.ingredients.first?.quantity == milk.quantity)
        #expect(store.finishCooking(remaining: [milk.id: Quantity(value: 800, unit: .milliliter)]))
        #expect(store.ingredients.first?.quantity == Quantity(value: 0.8, unit: .liter))
        store.undoPending()
        #expect(store.ingredients.first?.quantity == milk.quantity)
        #expect(store.activeCook == session)
    }
}
