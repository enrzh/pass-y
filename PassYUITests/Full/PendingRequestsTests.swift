import XCTest

/// Pending login requests, opened from the avatar menu.
final class PendingRequestsTests: PassYUITestCase {
    /// Pending login requests opens from the menu.
    /// Formerly `PassYUiR9Tests.test02_pendingRequestsFromMenu`.
    func test_opensFromAvatarMenu() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["CurrentActiveAccount"].tap(); sleep(1)
        menuButton(app, id: "ProfileMenuPendingRequestsButton", label: "Pending login requests").tap()
        XCTAssertTrue(app.staticTexts["No pending requests"].waitForExistence(timeout: 15)
                      || app.navigationBars.buttons["Close"].waitForExistence(timeout: 5), "pending requests sheet")
        shot(app, 2, "pending-requests")
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        if close.exists { close.firstMatch.tap() }
    }
}
