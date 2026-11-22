import XCTest

/// The bottom search bar: search, open a result, cancel.
final class SearchTests: PassYUITestCase {
    /// Searching and cancelling returns to the normal vault with the add button visible and the keyboard closed.
    /// Formerly `PassYFlowTests.test09_searchCancelRestoresVault`.
    func test_cancelRestoresVault() {
        let app = launchApp()
        ensureUnlockedVault(app)
        focusSearch(app)
        for ch in "Perf" { app.typeText(String(ch)); usleep(150_000) }
        XCTAssertFalse(app.buttons["AddItemFloatingActionButton"].exists, "add button is hidden while searching")
        let cancel = app.buttons["VaultSearchCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "cancel button of the search bar")
        cancel.tap(); sleep(2)
        attach(app, "09-after-cancel")
        XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5), "add button is back after cancel")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "keyboard is closed after cancel")
    }

    /// Open a search result, close the item, cancel the search: the vault is back to normal.
    /// Formerly `PassYFlowTests.test10_searchOpenCloseCancel`.
    func test_openResultCloseThenCancel() {
        let app = launchApp()
        ensureUnlockedVault(app)
        focusSearch(app)
        for ch in "GitHub" { app.typeText(String(ch)); usleep(150_000) }
        let hit = app.staticTexts["GitHub"].firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 20), "search finds GitHub")
        hit.tap()
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        XCTAssertTrue(close.firstMatch.waitForExistence(timeout: 10), "item sheet is open")
        close.firstMatch.tap(); sleep(2)
        attach(app, "10-after-item-close")
        let cancel = app.buttons["VaultSearchCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "search bar cancel is still there")
        cancel.tap(); sleep(2)
        attach(app, "10-after-cancel")
        XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5), "add button is back after cancel")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "keyboard is closed after cancel")
    }
}
