import XCTest

/// iPad first launch (own simulator, fresh install; this class sorts before `IPadTests`, which log in).
final class IPadLandingTests: PassYUITestCase {
    /// After the automatically presented server sheet is cancelled, "Server: Not set" opens it again, also twice.
    func test_serverSheetReopensAfterCancel() {
        let app = launchApp()
        let logIn = app.buttons["Log in"]
        XCTAssertTrue(waitFor(logIn), "intro screen shows 'Log in'")
        logIn.tap()
        let server = app.textFields["ServerUrlEntry"]
        XCTAssertTrue(waitFor(server), "server settings appear automatically")
        app.buttons["CancelButton"].firstMatch.tap()
        XCTAssertTrue(waitForDisappearance(of: server, timeout: 10), "Cancel closes the server sheet")
        let selector = app.buttons["RegionSelectorDropdown"]
        XCTAssertTrue(waitFor(selector))
        XCTAssertTrue(selector.label.contains("Not set"))
        for attempt in 1 ... 2 {
            XCTAssertTrue(waitUntil(5) { selector.isHittable }, "selector tappable (attempt \(attempt))")
            selector.tap()
            XCTAssertTrue(server.waitForExistence(timeout: 5), "the selector opens the server sheet (attempt \(attempt))")
            attach(app, "ipad-server-sheet-reopened-\(attempt)")
            app.buttons["CancelButton"].firstMatch.tap()
            XCTAssertTrue(waitForDisappearance(of: server, timeout: 10), "Cancel closes it again (attempt \(attempt))")
        }
    }
}
