import XCTest

/// ui-r6: list rows with chevron, context menu, swipe actions, Select mode, detail sheet, auth pages, iPad landscape.
/// Attachment names: `<PASSY_SHOT_TAG>-<nn>-<screen>`.
final class PassYUiR6ShotsTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "r6" }

    private func shot(_ app: XCUIApplication, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(String(format: "%02d", n))-\(name)")
    }

    private func openLoginList(_ app: XCUIApplication) {
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap(); sleep(2)
        XCTAssertTrue(app.buttons["VaultListItemRowButton"].firstMatch.waitForExistence(timeout: 8))
    }

    /// Rows end with a chevron (no "..." button); the options are in the context menu and the swipe actions.
    func test_rowChevronContextMenuSwipe() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            openLoginList(app)
            XCTAssertFalse(app.buttons["CipherOptionsButton"].exists, "no '...' button in list rows")
            XCTAssertTrue(app.images["CipherDisclosureChevron"].firstMatch.exists
                          || app.descendants(matching: .any)["CipherDisclosureChevron"].exists, "rows show a chevron")
            shot(app, 1, "\(mode)-list-chevron")
            // Long press: context menu with copy actions and Delete.
            let row = app.buttons["VaultListItemRowButton"].firstMatch
            row.press(forDuration: 1.2); sleep(1)
            XCTAssertTrue(app.buttons["Copy username"].waitForExistence(timeout: 5)
                          || app.menuItems["Copy username"].exists, "context menu offers Copy username")
            XCTAssertTrue(app.buttons["Delete"].exists || app.menuItems["Delete"].exists, "context menu offers Delete")
            shot(app, 2, "\(mode)-context-menu")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.45)).tap(); sleep(2)
            XCTAssertFalse(app.buttons["Copy username"].exists || app.menuItems["Copy username"].exists, "menu dismissed")
            // Swipe: Delete + More.
            row.swipeLeft(); sleep(1)
            XCTAssertTrue(app.buttons["Delete"].exists, "swipe offers Delete")
            XCTAssertTrue(app.buttons["More options"].exists, "swipe offers More options")
            shot(app, 3, "\(mode)-swipe")
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// "N Items" subtitle and Select mode with Delete of the created items.
    func test_selectModeDelete() {
        XCUIDevice.shared.appearance = .light
        let app = launchApp()
        ensureUnlockedVault(app)
        addLogin(app, name: "R6 Zap One", user: "one@example.test", password: "x1")
        addLogin(app, name: "R6 Zap Two", user: "two@example.test", password: "x2")
        app.buttons["CategoryTile_login"].tap(); sleep(2)
        XCTAssertTrue(app.staticTexts["R6 Zap One"].waitForExistence(timeout: 8))
        let select = app.buttons["SelectButton"]
        XCTAssertTrue(select.waitForExistence(timeout: 5), "Select button in the toolbar")
        shot(app, 10, "list-subtitle")
        select.tap(); sleep(1)
        XCTAssertFalse(app.buttons["SelectDeleteButton"].isEnabled, "delete disabled without selection")
        app.staticTexts["R6 Zap One"].tap(); app.staticTexts["R6 Zap Two"].tap(); sleep(1)
        shot(app, 11, "select-mode")
        XCTAssertTrue(app.buttons["SelectDeleteButton"].isEnabled, "delete enabled with selection")
        app.buttons["SelectDeleteButton"].tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5))
        yes.tap()
        XCTAssertTrue(waitForDisappearance(of: app.staticTexts["R6 Zap One"], timeout: 15), "selected items are deleted")
        XCTAssertFalse(app.staticTexts["R6 Zap Two"].exists)
    }

    /// Swipe-Delete of a single item.
    func test_swipeDelete() {
        let app = launchApp()
        ensureUnlockedVault(app)
        addLogin(app, name: "R6 Swipe Gone", user: "s@example.test", password: "x")
        app.buttons["CategoryTile_login"].tap(); sleep(2)
        let name = app.staticTexts["R6 Swipe Gone"]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        name.swipeLeft(); sleep(1)
        app.buttons["Delete"].firstMatch.tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5)); yes.tap()
        XCTAssertTrue(waitForDisappearance(of: name, timeout: 15), "swipe delete removes the item")
    }
}
