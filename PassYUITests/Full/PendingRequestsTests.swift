import XCTest

/// Pending login requests, opened from the avatar menu.
final class PendingRequestsTests: PassYUITestCase {
    /// Pending login requests opens from the menu.
    /// Formerly `PassYUiR9Tests.test02_pendingRequestsFromMenu`.
    func test_opensFromAvatarMenu() {
        let app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertTrue(openAvatarMenu(app), "avatar menu opens")
        menuButton(app, id: "ProfileMenuPendingRequestsButton", label: "Pending login requests").tap()
        // The sheet is identified by its title. Its content depends on the server: "No pending requests", or the list
        // when a login-with-device request of the last 15 minutes exists (AuthScreensTests creates one). The former
        // second alternative (a "Close" button) never existed: the sheet has Cancel (`CancelButton`).
        XCTAssertTrue(app.navigationBars.staticTexts["Pending login requests"].waitForExistence(timeout: 15), "pending requests sheet")
        XCTAssertTrue(waitUntil(15) {
            app.staticTexts["No pending requests"].exists || app.descendants(matching: .any)["LoginRequestCell"].firstMatch.exists
        }, "pending requests sheet shows its empty state or its requests")
        XCTAssertTrue(app.buttons["CancelButton"].exists, "the sheet can be closed")
        shot(app, 2, "pending-requests")
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        if close.exists { close.firstMatch.tap() }
    }
}
