import XCTest

/// 리텐션 프롬프트(§14.9) — 두 다이얼로그의 문구·그림·버튼 흐름과 첫 등록 트리거.
/// 언제 묻는지의 판정은 단위 테스트(`RetentionPromptTests`)가 본다. 하네스 인자(`-skipAuth` 등)는
/// 제안을 끄므로(`RetentionPromptHost.suppressed`) 여기서는 `-retention.*`로 명시해서 켠다.
final class RetentionPromptUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func launch(_ extra: [String], korean: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        let language = korean ? "ko" : "en"
        app.launchArguments = ["-skipAuth", "-skipOnboarding", "-analyticsOff"] + extra
            + ["-app.language", language, "-AppleLanguages", "(\(language))"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 다이얼로그 안의 버튼 — 뒤 화면에 같은 낱말의 버튼이 있을 수 있다(홈 알림 배너 "Later"도 한국어로 "나중에").
    private func dialogButton(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        element(app, "paperDialog").buttons[label]
    }

    // MARK: 알림 제안

    func testAlertPromptEnglish() { checkAlertPrompt(korean: false) }
    func testAlertPromptKorean() { checkAlertPrompt(korean: true) }

    /// 첫 알림 미리보기 + 나중에 · 알림 받기. "나중에"는 아무것도 묻지 않고 닫는다.
    private func checkAlertPrompt(korean: Bool) {
        let app = launch(["-uiTestSampleFridge", "-retention.alerts"], korean: korean)
        let title = app.staticTexts[korean ? "상하기 전에 알려드릴까요?" : "Want a heads-up before food turns?"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "retention.alertPreview").exists, "The dialog shows the real first alert")
        XCTAssertTrue(dialogButton(app, korean ? "알림 받기" : "Remind me").exists)
        attach(app, "retention-alerts-\(korean ? "ko" : "en")")
        dialogButton(app, korean ? "나중에" : "Not now").tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
    }

    // MARK: 위젯 제안

    func testWidgetPromptEnglish() { checkWidgetPrompt(korean: false) }
    func testWidgetPromptKorean() { checkWidgetPrompt(korean: true) }

    /// 위젯 미리보기 → 방법 보기 → 세 단계 → 알겠어요.
    private func checkWidgetPrompt(korean: Bool) {
        let language = korean ? "ko" : "en"
        let app = launch(["-uiTestSampleFridge", "-retention.widget"], korean: korean)
        let title = app.staticTexts[korean ? "먼저 쓸 재료를 홈 화면에 꺼내 둘까요?"
                                           : "Keep what to use first on your Home Screen?"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "retention.widgetPreview").exists, "The dialog shows the real widget")
        attach(app, "retention-widget-\(language)")
        dialogButton(app, korean ? "방법 보기" : "See how").tap()
        let steps = app.staticTexts[korean ? "세 단계면 끝나요" : "Add it in 3 steps"]
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        XCTAssertFalse(title.exists, "The steps replace the first dialog")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "retention.widgetStep").count, 3,
                       "Three numbered steps, one row each")
        attach(app, "retention-widget-steps-\(language)")
        dialogButton(app, korean ? "알겠어요" : "Got it").tap()
        XCTAssertTrue(steps.waitForNonExistence(timeout: 5))
    }

    // MARK: 실제 트리거

    func testFirstRegistrationAsksOnceEnglish() { checkFirstRegistration(korean: false) }
    func testFirstRegistrationAsksOnceKorean() { checkFirstRegistration(korean: true) }

    /// 빈 냉장고에 첫 재료를 저장하면 추가 시트가 내려간 뒤 알림 제안이 뜨고, 다시 열어도 또 묻지 않는다.
    /// 시뮬레이터의 알림 권한은 테스트가 되돌릴 수 없어 `-retention.live`가 '아직 안 물음'으로 본다.
    private func checkFirstRegistration(korean: Bool) {
        let language = korean ? "ko" : "en"
        let live = ["-retention.live", "-expiryAlertsEnabled", "NO"]
        let app = launch(["-uiTestEmptyFridge"] + live, korean: korean)
        let first = app.buttons[korean ? "첫 재료 추가" : "Add first ingredient"]
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.tap()
        let manual = app.buttons[korean ? "직접 입력" : "Add by hand"]
        XCTAssertTrue(manual.waitForExistence(timeout: 6))
        manual.tap()
        let name = app.textFields[korean ? "이름" : "Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 6))
        name.tap()
        name.typeText("Milk")
        let save = app.buttons[korean ? "저장" : "Save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        let titleText = korean ? "상하기 전에 알려드릴까요?" : "Want a heads-up before food turns?"
        let title = app.staticTexts[titleText]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The first registration asks for alerts")
        XCTAssertTrue(element(app, "retention.alertPreview").exists)
        XCTAssertFalse(app.buttons[korean ? "켜기" : "Turn on"].exists, "The home banner yields to the dialog")
        sleep(1)   // 딤·카드 등장이 끝난 화면을 남긴다(스크린샷 전용)
        attach(app, "retention-first-registration-\(language)")
        dialogButton(app, korean ? "나중에" : "Not now").tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))

        app.terminate()
        let again = launch(live, korean: korean)
        XCTAssertTrue(again.buttons["home.primaryAction"].waitForExistence(timeout: 15))
        XCTAssertFalse(again.staticTexts[titleText].waitForExistence(timeout: 4),
                       "The suggestion is asked once per install")
    }
}
