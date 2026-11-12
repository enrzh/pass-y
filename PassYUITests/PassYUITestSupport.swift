import XCTest

/// Throwaway test account on a local Vaultwarden (see Scripts-passy/vaultwarden/seed_account.py).
enum TestAccount {
    static let server = "http://localhost:8088"
    static let email = "passy-test@example.test"
    static let password = "PassY-Test-Only-2026!"
}

extension XCTestCase {
    func launchApp(extraArguments: [String] = [], appearance: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extraArguments
        app.launch()
        return app
    }

    func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @discardableResult
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Brings the app to the unlocked vault list from any of: intro, login, unlock, vault.
    func ensureUnlockedVault(_ app: XCUIApplication) {
        let fab = app.buttons["AddItemFloatingActionButton"]
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if fab.exists { return }
            if app.buttons["Log in"].exists { app.buttons["Log in"].tap() }
            let server = app.textFields["ServerUrlEntry"]
            if server.exists {
                server.tap()
                server.typeText(TestAccount.server)
                app.buttons["SaveButton"].firstMatch.tap()
                sleep(2)
                continue
            }
            let email = app.textFields["LoginEmailAddressEntry"]
            if email.exists {
                if app.buttons["RegionSelectorDropdown"].label.contains("Not set") {
                    // The server sheet is presented automatically; wait until the selector is tappable.
                    if app.buttons["RegionSelectorDropdown"].isHittable { app.buttons["RegionSelectorDropdown"].tap() }
                } else if email.isHittable {
                    email.tap()
                    email.typeText(TestAccount.email)
                    app.buttons["ContinueButton"].tap()
                }
            }
            let loginPw = app.secureTextFields["LoginMasterPasswordEntry"]
            if loginPw.exists {
                loginPw.tap()
                loginPw.typeText(TestAccount.password)
                app.buttons["LogInWithMasterPasswordButton"].tap()
            }
            let unlockPw = app.secureTextFields["MasterPasswordEntry"]
            if unlockPw.exists {
                unlockPw.tap()
                unlockPw.typeText(TestAccount.password)
                app.buttons["UnlockVaultButton"].tap()
            }
            sleep(2)
        }
        XCTFail("Could not reach the vault list")
    }
}

extension XCUIApplication {
    /// Dismisses the "learn about new logins" intro card if it is visible.
    func dismissNewLoginCard() {
        let dismiss = buttons["Dismiss"]
        if dismiss.exists, dismiss.isHittable { dismiss.tap() }
    }

    /// All visible text labels joined, for content assertions that ignore accessibility identifiers.
    var allLabels: String {
        staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
            + "\n" + buttons.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
    }
}

extension XCTestCase {
    /// Creates a login through the add-item UI and returns to the vault list.
    func addLogin(_ app: XCUIApplication, name: String, user: String, password: String, totp: String? = nil) {
        app.buttons["AddItemFloatingActionButton"].tap()
        app.buttons["Login"].firstMatch.tap()
        let nameField = app.textFields["ItemNameEntry"]
        XCTAssertTrue(waitFor(nameField))
        app.dismissNewLoginCard()
        nameField.tap(); nameField.typeText(name)
        if let totp {
            let setup = app.buttons["SetupTotpButton"]
            if !setup.exists { app.swipeUp() }
            let field = app.secureTextFields["LoginTotpEntry"].exists
                ? app.secureTextFields["LoginTotpEntry"] : app.textFields["LoginTotpEntry"]
            if !field.waitForExistence(timeout: 3) {
                for _ in 0 ..< 4 where !field.exists { app.swipeUp() }
            }
            if !field.exists, setup.exists { setup.tap() }
            if field.waitForExistence(timeout: 10) { field.tap(); field.typeText(totp) }
        }
        if totp != nil { app.swipeDown() }
        let userField = app.textFields["LoginUsernameEntry"]
        userField.tap(); userField.typeText(user)
        let pw = app.secureTextFields["LoginPasswordEntry"]
        pw.tap(); pw.typeText(password)
        app.buttons["SaveButton"].firstMatch.tap()
        _ = app.buttons["Close"].waitForExistence(timeout: 8)
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        if close.exists { close.firstMatch.tap() }
        sleep(2)
    }
}
