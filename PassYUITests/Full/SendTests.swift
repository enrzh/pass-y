import XCTest

/// Send: add menu, create a text send, the list.
final class SendTests: PassYUITestCase {
    /// Real taps in Send: the Send tab opens, the add menu offers the send types and Text opens the add form.
    /// Formerly `PassYFlowTests.test15_sendTabAddMenu`.
    func test_addMenuOffersTextAndOpensForm() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Send")
        let add = app.buttons["AddItemFloatingActionButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Send tab shows the add button")
        attach(app, "15-send-list")
        add.tap(); sleep(2)
        attach(app, "15-send-add-menu")
        let text = app.buttons.matching(NSPredicate(format: "label == 'Text'")).firstMatch
        let menuText = app.menuItems["Text"]
        XCTAssertTrue(menuText.waitForExistence(timeout: 5) || text.waitForExistence(timeout: 5), "add menu offers Text")
        (menuText.exists ? menuText : text).tap(); sleep(2)
        attach(app, "15-send-add-form")
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10) || app.buttons["SaveButton"].exists
            || app.navigationBars.firstMatch.exists, "add send form is shown")
    }

    /// Creates a text send through the UI (real taps), restarts the app and shows the native populated Send list.
    /// Formerly `PassYFlowTests.test16_createSendAndShowList`.
    func test_createTextSendAndList() {
        var app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Send")
        // A unique name proves this run created the send (earlier runs leave sends with fixed names behind).
        let name = "PassY Send \(Int(Date().timeIntervalSince1970) % 100000)"
        let add = app.buttons["AddItemFloatingActionButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "add control in the Send bottom bar")
        add.tap(); sleep(1)
        let menuText = app.menuItems["Text"]
        let text = app.buttons.matching(NSPredicate(format: "label == 'Text'")).firstMatch
        XCTAssertTrue(menuText.waitForExistence(timeout: 5) || text.waitForExistence(timeout: 5), "add menu offers Text")
        (menuText.exists ? menuText : text).tap()
        let nameField = app.textFields["SendNameEntry"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "send name field")
        nameField.replaceText(name)
        let body = app.textViews["SendTextContentEntry"]
        if !body.exists { for _ in 0 ..< 3 where !body.exists { app.swipeUp() } }
        body.replaceText("secret for \(name)")
        app.buttons["SaveButton"].firstMatch.tap()
        sleep(4)
        attach(app, "16-after-save-share-sheet")
        // The system share sheet for the new link is shown after saving; a relaunch starts from a clean screen.
        app.terminate()
        app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Send")
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 15), "the send is listed")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Optional('")).firstMatch.exists,
                       "section headers show plain names")
        XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].exists, "add control stays reachable below the list")
        sleep(1)
        attach(app, "16-send-list")
    }
}
