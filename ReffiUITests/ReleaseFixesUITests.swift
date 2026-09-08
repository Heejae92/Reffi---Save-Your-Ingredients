import XCTest

final class ReleaseFixesUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testFirstIngredientEnglish() { checkFirstIngredient(korean: false) }
    func testFirstIngredientKorean() { checkFirstIngredient(korean: true) }

    private func checkFirstIngredient(korean: Bool) {
        let app = XCUIApplication()
        let language = korean ? "ko" : "en"
        app.launchArguments = ["-skipAuth", "-skipOnboarding", "-analyticsOff", "-uiTestEmptyFridge",
                               "-app.language", language, "-AppleLanguages", "(\(language))"]
        app.launch()
        let first = app.buttons[korean ? "첫 재료 추가" : "Add first ingredient"]
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        XCTAssertTrue(first.isEnabled)
        attach(app, "first-empty-\(language)")
        first.tap()
        let manual = app.buttons[korean ? "직접 입력" : "Add by hand"]
        XCTAssertTrue(manual.waitForExistence(timeout: 6))
        attach(app, "first-add-options-\(language)")
        manual.tap()
        let name = app.textFields[korean ? "이름" : "Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 6))
        name.tap()
        name.typeText("Milk")
        let quantity = app.textFields["ingredient.quantity"]
        quantity.doubleTap()
        quantity.typeText("0")
        attach(app, "quantity-zero-\(language)")
        XCTAssertEqual(quantity.value as? String, "0")
        XCTAssertTrue(app.staticTexts[korean ? "예상 소비기한" : "Estimated use-by"].exists)
        let save = app.buttons[korean ? "저장" : "Save"]
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.staticTexts[korean ? "수량은 0보다 크게 입력해 주세요." : "Enter a quantity greater than 0."].exists)
        quantity.doubleTap()
        quantity.typeText("2")
        XCTAssertTrue(save.isEnabled)
        quantity.doubleTap()
        quantity.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertFalse(save.isEnabled, "Clearing a quantity must not save the previous value")
        quantity.typeText("2")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let cook = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", korean ? "요리 시작" : "Start cooking")).firstMatch
        XCTAssertTrue(cook.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", korean ? "냉장고 보기" : "View fridge")).firstMatch.exists)
        attach(app, "first-added-\(language)")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-uiTestEmptyFridge" }
        app.launch()
        XCTAssertTrue(cook.waitForExistence(timeout: 15), "Registered stock must survive reopening")
        XCTAssertFalse(first.exists)
    }

    func testExactRemainingQuantityPersists() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-skipOnboarding", "-analyticsOff", "-uiTestSampleFridge",
                               "-cookTicket", "-cookTicket.recipeID", "scrambled-eggs", "-app.language", "en", "-AppleLanguages", "(en)"]
        app.launch()
        let finish = app.buttons["Finish cooking"]
        XCTAssertTrue(finish.waitForExistence(timeout: 20))
        finish.tap()
        let milk = app.buttons["Milk"]
        XCTAssertTrue(milk.waitForExistence(timeout: 6))
        milk.tap()
        let quantity = app.textFields["leftover.quantity.milk"]
        XCTAssertTrue(quantity.waitForExistence(timeout: 5))
        quantity.tap()
        quantity.doubleTap()
        quantity.typeText("2")
        let confirm = app.buttons["Confirm & finish"]
        XCTAssertFalse(confirm.isEnabled, "Remaining quantity cannot exceed 1 L")
        quantity.doubleTap()
        quantity.typeText("0.8")
        XCTAssertTrue(confirm.isEnabled)
        attach(app, "exact-remaining-input")
        confirm.tap()
        let fridge = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "View fridge")).firstMatch
        XCTAssertTrue(fridge.waitForExistence(timeout: 8))
        fridge.tap()
        let list = app.buttons["Switch to simple view"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.tap()
        let remaining = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Milk", "800")).firstMatch
        for _ in 0..<5 {
            if remaining.exists && remaining.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(remaining.exists, "The fridge must show the entered remainder")
        attach(app, "exact-remaining-stock")
        app.terminate()
        app.launchArguments = ["-skipAuth", "-skipOnboarding", "-analyticsOff", "-fridgeTab",
                               "-app.language", "en", "-AppleLanguages", "(en)"]
        app.launch()
        for _ in 0..<5 {
            if remaining.waitForExistence(timeout: 2) { break }
            app.swipeUp()
        }
        XCTAssertTrue(remaining.exists, "Exact remainder must survive relaunch")
    }

    func testRecipeAmountsAndStepCompletion() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-skipOnboarding", "-analyticsOff", "-uiTestSampleFridge",
                               "-cookTicket", "-cookTicket.recipeID", "kimchi-jjigae", "-app.language", "en", "-AppleLanguages", "(en)"]
        app.launch()
        let how = app.buttons["How to cook"]
        XCTAssertTrue(how.waitForExistence(timeout: 20))
        how.tap()
        let list = app.scrollViews["kitchenCopy.steps"]
        XCTAssertTrue(list.waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Ingredients"].exists)
        attach(app, "recipe-amounts-en")
        let step = list.buttons.firstMatch
        for _ in 0..<10 {
            if step.exists && step.isHittable { break }
            list.swipeUp()
        }
        XCTAssertTrue(step.isHittable)
        step.tap()
        XCTAssertEqual(step.value as? String, "Done")
        attach(app, "recipe-step-checked-en")
    }
}
