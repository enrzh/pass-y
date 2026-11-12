import XCTest

/// Visual checks: dark mode and very large Dynamic Type. Screenshots are kept as attachments.
final class PassYZAppearanceTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func walkScreens(_ app: XCUIApplication, prefix: String) {
        ensureUnlockedVault(app)
        attach(app, "\(prefix)-vault")
        app.tabBars.buttons["Generator"].tap(); sleep(1)
        attach(app, "\(prefix)-generator")
        app.tabBars.buttons["Send"].tap(); sleep(1)
        attach(app, "\(prefix)-send")
        app.tabBars.buttons["Settings"].tap(); sleep(1)
        attach(app, "\(prefix)-settings")
        app.tabBars.buttons["My vault"].tap()
        app.buttons["AddItemFloatingActionButton"].tap()
        app.buttons["Login"].firstMatch.tap()
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
