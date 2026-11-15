import XCTest

/// Throwaway test account on a local Vaultwarden (see Scripts-passy/vaultwarden/seed_account.py).
enum TestAccount {
    /// Defaults to port 8088; override with `TEST_RUNNER_PASSY_SERVER=http://localhost:<port>` (alias: `PASSY_VW_URL`) for a parallel Vaultwarden.
    static let server = ProcessInfo.processInfo.environment["PASSY_SERVER"]
        ?? ProcessInfo.processInfo.environment["PASSY_VW_URL"]
        ?? "http://localhost:8088"
    static let email = "passy-test@example.test"
    static let password = "PassY-Test-Only-2026!"
}

extension XCUIElement {
    /// Clears a text/secure field (a failed login attempt leaves the typed text in the field) and types `text`.
    func replaceText(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty, current != (placeholderValue ?? "") {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}

extension XCTestCase {
    /// Taps the search field and makes sure the soft keyboard is up (the simulator occasionally ignores the first tap).
    func focusSearch(_ app: XCUIApplication) {
        let search = app.searchFields.firstMatch
        search.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 4) {
            search.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 6), "keyboard shows after tapping the search field")
        }
        sleep(1)
    }

    /// Taps "Login" in the open add menu (on iPad the category tile of the same name is also visible behind it).
    func tapNewLoginMenuItem(_ app: XCUIApplication) {
        let menuItem = app.menuItems["Login"]
        if menuItem.waitForExistence(timeout: 4) { menuItem.tap(); return }
        let predicate = NSPredicate(format: "label == 'Login' AND NOT (identifier BEGINSWITH 'CategoryTile')")
        let button = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Login entry of the add menu\n\(app.debugDescription)")
        button.tap()
    }

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
                loginPw.replaceText(TestAccount.password)
                app.buttons["LogInWithMasterPasswordButton"].tap()
            }
            let unlockPw = app.secureTextFields["MasterPasswordEntry"]
            if unlockPw.exists {
                unlockPw.replaceText(TestAccount.password)
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
        tapNewLoginMenuItem(app)
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

/// Opens the avatar menu (top right) and returns the entry for a destination ("My vault", "Send", "Generator",
/// "Settings"). There is no tab bar: these entries are the only way to switch top-level screens.
func avatarMenuEntry(_ app: XCUIApplication, _ label: String) -> XCUIElement {
    let ids = ["My vault": "ProfileMenuVaultButton", "Send": "ProfileMenuSendButton",
               "Generator": "ProfileMenuGeneratorButton", "Settings": "ProfileMenuSettingsButton"]
    func lookup() -> XCUIElement? {
        let byId = app.buttons[ids[label] ?? label]
        if byId.exists { return byId }
        let byLabel = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if byLabel.exists { return byLabel }
        let item = app.menuItems[label]
        return item.exists ? item : nil
    }
    if let found = lookup() { return found }
    // The menu is closed: open it (once) and look again.
    let avatar = app.buttons["CurrentActiveAccount"]
    if avatar.waitForExistence(timeout: 10) { avatar.tap() }
    for _ in 0 ..< 10 {
        if let found = lookup() { return found }
        usleep(300_000)
    }
    return app.buttons[ids[label] ?? label]
}

/// Switches to a top-level screen through the avatar menu.
func goTo(_ app: XCUIApplication, _ label: String) {
    avatarMenuEntry(app, label).tap()
}
