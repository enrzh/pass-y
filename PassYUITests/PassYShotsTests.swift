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
        attach(app, "\(tag)-1b-home-landscape")
        XCUIDevice.shared.orientation = .portrait; sleep(1)
        if app.staticTexts["GitHub"].exists {
            app.staticTexts["GitHub"].firstMatch.tap()
            sleep(2)
            attach(app, "\(tag)-2-detail")
            let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
            if close.exists { close.firstMatch.tap() }
        }
        tab(app, "Generator").tap(); sleep(1)
        attach(app, "\(tag)-3-generator")
        tab(app, "Settings").tap(); sleep(1)
        attach(app, "\(tag)-4-settings")
        tab(app, "My vault").tap()
        app.buttons["AddItemFloatingActionButton"].tap()
        app.buttons["Login"].firstMatch.tap(); sleep(2)
        attach(app, "\(tag)-5-add")
    }
}
