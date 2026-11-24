import XCTest

/// First launch: the server is asked for first and there is no cloud preset. Needs a fresh install (the core step starts with one; this class sorts first).
final class AuthLandingTests: PassYUITestCase {
    // MARK: 01 Landing: server first, no cloud preset
    /// Formerly `PassYFlowTests.test01_landingAsksForServerAndHasNoCloudPreset`.
    func test_landingAsksForServerAndHasNoCloudPreset() {
        let app = launchApp()
        let logIn = app.buttons["Log in"]
        XCTAssertTrue(waitFor(logIn), "intro screen shows 'Log in'")
        logIn.tap()
        // The server settings are presented automatically on first launch.
        XCTAssertTrue(waitFor(app.textFields["ServerUrlEntry"]), "server settings appear automatically")
        let preset = app.textFields["ServerUrlEntry"].value as? String ?? ""
        XCTAssertTrue(preset.isEmpty || preset == "Server URL", "no preset server URL, got \(preset)")
        attach(app, "01-server-settings")
        let all = app.debugDescription
        XCTAssertFalse(all.contains("bitwarden.com"), "no Bitwarden cloud host visible")
        XCTAssertFalse(all.contains("bitwarden.eu"), "no Bitwarden EU host visible")
        app.buttons["CancelButton"].firstMatch.tap()
        XCTAssertTrue(waitFor(app.buttons["RegionSelectorDropdown"]))
        XCTAssertTrue(app.buttons["RegionSelectorDropdown"].label.contains("Not set"))
        XCTAssertFalse(app.buttons["ContinueButton"].isEnabled, "continue disabled without email")
        attach(app, "01-landing-no-server")
    }
}
