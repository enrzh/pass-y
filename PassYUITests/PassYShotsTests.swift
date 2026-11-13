import XCTest

/// Seeds a few items into the throwaway vault and captures screenshots of the main screens.
/// Run once per device/appearance; screenshots are kept as xcresult attachments.
final class PassYShotsTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func test_shots() {
        let tag = ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "shot"
        let env = ProcessInfo.processInfo.environment
        if env["PASSY_SHOT_MODE"] == "dark" { XCUIDevice.shared.appearance = .dark }
        defer { XCUIDevice.shared.appearance = .light }
        let app = launchApp(extraArguments: env["PASSY_SHOT_XXXL"] == "1"
            ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : [])
        ensureUnlockedVault(app)
        if !FileManager.default.fileExists(atPath: "/tmp/passy_skip_seed"), !app.staticTexts["GitHub"].exists {
            addLogin(app, name: "GitHub", user: "octo@example.test", password: "Gh-Pass-1234", totp: "JBSWY3DPEHPK3PXP")
            addLogin(app, name: "Netflix", user: "movie@example.test", password: "Nf-Pass-5678")
            addLogin(app, name: "Bank", user: "me@example.test", password: "Bk-Pass-9012")
        }
        sleep(2)
        attach(app, "\(tag)-1-home")
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
        let land = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        land.name = "\(tag)-1b-home-landscape"; land.lifetime = .keepAlways; add(land)
        XCUIDevice.shared.orientation = .portrait; sleep(1)
        if !app.staticTexts["GitHub"].exists {
            // With a large vault the item is below the fold: find it through the bottom search bar.
            let search = app.searchFields.firstMatch
            search.tap(); sleep(3)
            for ch in "GitHub" { app.typeText(String(ch)); usleep(150_000) }
            _ = app.staticTexts["GitHub"].waitForExistence(timeout: 20)
        }
        if app.staticTexts["GitHub"].exists {
            app.staticTexts["GitHub"].firstMatch.tap()
            sleep(2)
            attach(app, "\(tag)-2-detail")
            let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
            if close.exists { close.firstMatch.tap() }
            if app.buttons["Cancel"].waitForExistence(timeout: 3) { app.buttons["Cancel"].tap() }
        }
        tab(app, "Generator").tap(); sleep(1)
        attach(app, "\(tag)-3-generator")
        tab(app, "Settings").tap(); sleep(1)
        attach(app, "\(tag)-4-settings")
        tab(app, "My vault").tap()
        // iOS 26 shows the search bar cancel as an X button (label "Cancel" or "Close" depending on the OS build).
        // The cancel/X button belongs to the bottom search bar (other "Close" buttons, e.g. sheets, must not match).
        let cancel = app.otherElements["VaultSearchField"].buttons.firstMatch
        attach(app, "\(tag)-4a-before-cancel")
        if cancel.waitForExistence(timeout: 3) { cancel.tap(); sleep(2) }
        attach(app, "\(tag)-4b-before-add")
        if !app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5) {
            XCTFail("Add button missing after closing the search\n\(app.debugDescription)")
        }
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app); sleep(2)
        attach(app, "\(tag)-5-add")
    }
}
