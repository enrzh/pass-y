import XCTest

/// ui-r6: list rows with chevron, context menu, swipe actions, Select mode, detail sheet, auth pages, iPad landscape.
/// Attachment names: `<PASSY_SHOT_TAG>-<nn>-<screen>`.
final class PassYUiR6ShotsTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "r6" }

    private func shot(_ app: XCUIApplication, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(String(format: "%02d", n))-\(name)")
    }

    private func openLoginList(_ app: XCUIApplication) {
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap(); sleep(2)
        XCTAssertTrue(app.buttons["VaultListItemRowButton"].firstMatch.waitForExistence(timeout: 8))
    }

    /// Rows end with a chevron (no "..." button); the options are in the context menu and the swipe actions.
    func test_rowChevronContextMenuSwipe() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            openLoginList(app)
            XCTAssertFalse(app.buttons["CipherOptionsButton"].exists, "no '...' button in list rows")
            XCTAssertTrue(app.images["CipherDisclosureChevron"].firstMatch.exists
                          || app.descendants(matching: .any)["CipherDisclosureChevron"].exists, "rows show a chevron")
            shot(app, 1, "\(mode)-list-chevron")
            // Long press: context menu with copy actions and Delete.
            let row = app.buttons["VaultListItemRowButton"].firstMatch
            row.press(forDuration: 1.2); sleep(1)
            XCTAssertTrue(app.buttons["Copy username"].waitForExistence(timeout: 5)
                          || app.menuItems["Copy username"].exists, "context menu offers Copy username")
            XCTAssertTrue(app.buttons["Delete"].exists || app.menuItems["Delete"].exists, "context menu offers Delete")
            shot(app, 2, "\(mode)-context-menu")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.45)).tap(); sleep(2)
            XCTAssertFalse(app.buttons["Copy username"].exists || app.menuItems["Copy username"].exists, "menu dismissed")
            // Swipe: Delete + More.
            row.swipeLeft(); sleep(1)
            XCTAssertTrue(app.buttons["Delete"].exists, "swipe offers Delete")
            XCTAssertTrue(app.buttons["More options"].exists, "swipe offers More options")
            shot(app, 3, "\(mode)-swipe")
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// "N Items" subtitle and Select mode with Delete of the created items.
    func test_selectModeDelete() {
        XCUIDevice.shared.appearance = .light
        let app = launchApp()
        ensureUnlockedVault(app)
        addLogin(app, name: "AA R6 Zap One", user: "one@example.test", password: "x1")
        addLogin(app, name: "AA R6 Zap Two", user: "two@example.test", password: "x2")
        app.buttons["CategoryTile_login"].tap(); sleep(2)
        XCTAssertTrue(app.staticTexts["AA R6 Zap One"].waitForExistence(timeout: 8))
        let select = app.buttons["SelectButton"]
        XCTAssertTrue(select.waitForExistence(timeout: 5), "Select button in the toolbar")
        shot(app, 10, "list-subtitle")
        select.tap(); sleep(1)
        XCTAssertFalse(app.buttons["SelectDeleteButton"].isEnabled, "delete disabled without selection")
        app.staticTexts["AA R6 Zap One"].tap(); app.staticTexts["AA R6 Zap Two"].tap(); sleep(1)
        shot(app, 11, "select-mode")
        XCTAssertTrue(app.buttons["SelectDeleteButton"].isEnabled, "delete enabled with selection")
        app.buttons["SelectDeleteButton"].tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5))
        yes.tap()
        XCTAssertTrue(waitForDisappearance(of: app.staticTexts["AA R6 Zap One"], timeout: 15), "selected items are deleted")
        XCTAssertFalse(app.staticTexts["AA R6 Zap Two"].exists)
    }

    /// Swipe-Delete of a single item.
    func test_swipeDelete() {
        let app = launchApp()
        ensureUnlockedVault(app)
        addLogin(app, name: "AA R6 Swipe Gone", user: "s@example.test", password: "x")
        app.buttons["CategoryTile_login"].tap(); sleep(2)
        let name = app.staticTexts["AA R6 Swipe Gone"]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        name.swipeLeft(); sleep(1)
        app.buttons["Delete"].firstMatch.tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5)); yes.tap()
        XCTAssertTrue(waitForDisappearance(of: name, timeout: 15), "swipe delete removes the item")
    }

    // MARK: Auth pages in the running app (step 6)

    private func leaveScreen(_ app: XCUIApplication) {
        for id in ["CancelButton", "CloseButton", "Close", "Cancel", "Back"] {
            let b = app.buttons[id].firstMatch
            if b.exists, b.isHittable { b.tap(); sleep(2); return }
        }
        let nav = app.navigationBars.buttons.firstMatch
        if nav.exists, nav.isHittable { nav.tap(); sleep(2) }
    }

    /// Reaches the login sub-screens (password hint, login with device, SSO) and the two-step login screens
    /// (authenticator and recovery code) of the 2FA test account (`enable_2fa.py`), light and dark. Needs a fresh install.
    /// What is reachable is printed as `R6REACH`; each screen found is asserted.
    func test_authPagesInRunningApp() {
        let mode = ProcessInfo.processInfo.environment["PASSY_MODE"] ?? "light"
        XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
        let app = launchApp()
        let logIn = app.buttons["Log in"]
        XCTAssertTrue(logIn.waitForExistence(timeout: 20)); logIn.tap()
        let server = app.textFields["ServerUrlEntry"]
        if server.waitForExistence(timeout: 10) {
            server.tap(); server.typeText(TestAccount.server)
            app.buttons["SaveButton"].firstMatch.tap(); sleep(2)
        }
        let email = app.textFields["LoginEmailAddressEntry"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        for _ in 0 ..< 10 where !email.isHittable { sleep(1) }
        email.tap(); email.typeText("passy-2fa@example.test")
        app.buttons["ContinueButton"].tap()
        let pw = app.secureTextFields["LoginMasterPasswordEntry"]
        XCTAssertTrue(pw.waitForExistence(timeout: 15), "login screen")
        shot(app, 40, "\(mode)-login")

        let hint = app.buttons["GetMasterPasswordHintLabel"]
        if hint.exists {
            hint.tap(); sleep(2)
            print("R6REACH password-hint: \(app.textFields.count) fields")
            shot(app, 41, "\(mode)-password-hint")
            leaveScreen(app)
        }
        let device = app.buttons["LogInWithAnotherDeviceButton"]
        print("R6REACH login-with-device button: \(device.exists)")
        if device.exists {
            device.tap(); sleep(3)
            shot(app, 42, "\(mode)-login-with-device")
            leaveScreen(app)
        }
        let sso = app.buttons["LogInWithSsoButton"]
        if sso.exists {
            sso.tap(); sleep(2)
            shot(app, 43, "\(mode)-sso")
            leaveScreen(app)
        }
        XCTAssertTrue(pw.waitForExistence(timeout: 10), "back on the login screen")
        pw.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) { pw.tap() }
        sleep(1)
        pw.typeText(TestAccount.password)
        app.buttons["LogInWithMasterPasswordButton"].tap()
        let code = app.textFields["VerificationCodeEntry"]
        XCTAssertTrue(code.waitForExistence(timeout: 20), "two-step login (authenticator) screen")
        shot(app, 44, "\(mode)-2fa-authenticator")
        print("R6REACH 2fa buttons: " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        let other = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'another method' OR label CONTAINS[c] 'other method'")).firstMatch
        let opts = app.navigationBars.buttons["Options"]
        if other.exists { other.tap() } else if opts.exists { opts.tap() }
        sleep(2)
        shot(app, 45, "\(mode)-2fa-methods")
        print("R6REACH 2fa methods: " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
              + " / " + app.menuItems.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        let recovery = app.buttons["Recovery code"].exists ? app.buttons["Recovery code"] : app.menuItems["Recovery code"]
        if recovery.exists {
            recovery.tap(); sleep(2)
            shot(app, 46, "\(mode)-2fa-recovery")
        }
        XCUIDevice.shared.appearance = .light
    }
}
