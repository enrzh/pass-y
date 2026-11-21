import XCTest

/// Visual checks: dark mode and very large Dynamic Type. Screenshots are kept as attachments.
final class PassYZAppearanceTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func walkScreens(_ app: XCUIApplication, prefix: String) {
        ensureUnlockedVault(app)
        attach(app, "\(prefix)-vault")
        goTo(app, "Generator"); sleep(1)
        attach(app, "\(prefix)-generator")
        goTo(app, "Send"); sleep(1)
        attach(app, "\(prefix)-send")
        goTo(app, "Settings"); sleep(1)
        attach(app, "\(prefix)-settings")
        goTo(app, "My vault")
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        XCTAssertTrue(waitFor(app.textFields["ItemNameEntry"]))
        attach(app, "\(prefix)-add-login")
        app.buttons["CancelButton"].firstMatch.tap()
    }

    func test_darkMode() {
        setPassYAppearance(.dark)
        defer { setPassYAppearance(.light) }
        walkScreens(launchApp(), prefix: "dark")
    }

    func test_largeText() {
        let app = launchApp(extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        walkScreens(app, prefix: "xxxl")
    }
}
