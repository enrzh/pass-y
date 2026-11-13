import XCTest

/// Visual checks: dark mode and very large Dynamic Type. Screenshots are kept as attachments.
final class PassYZAppearanceTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func walkScreens(_ app: XCUIApplication, prefix: String) {
        ensureUnlockedVault(app)
        attach(app, "\(prefix)-vault")
        tab(app, "Generator").tap(); sleep(1)
        attach(app, "\(prefix)-generator")
        tab(app, "Send").tap(); sleep(1)
        attach(app, "\(prefix)-send")
        tab(app, "Settings").tap(); sleep(1)
        attach(app, "\(prefix)-settings")
        tab(app, "My vault").tap()
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        XCTAssertTrue(waitFor(app.textFields["ItemNameEntry"]))
        attach(app, "\(prefix)-add-login")
        app.buttons["CancelButton"].firstMatch.tap()
    }

    func test_darkMode() {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        walkScreens(launchApp(), prefix: "dark")
    }

    func test_largeText() {
        let app = launchApp(extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        walkScreens(app, prefix: "xxxl")
    }
}
