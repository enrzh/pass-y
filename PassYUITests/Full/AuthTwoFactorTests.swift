import XCTest

/// Two-step login (authenticator) of the 2FA test account (`enable_2fa.py`).
final class AuthTwoFactorTests: PassYUITestCase {
    /// Two-step login (authenticator, other methods, recovery code) of the 2FA test account; run after a fresh install
    /// (it starts at the intro or the login screen).
    /// Formerly `PassYUiR6ShotsTests.test_auth2FAScreens`.
    func test_twoStepLoginScreens() {
        let mode = ProcessInfo.processInfo.environment["PASSY_MODE"] ?? "light"
        setPassYAppearance(mode == "dark" ? .dark : .light)
        let app = launchApp()
        let pw = app.secureTextFields["LoginMasterPasswordEntry"]
        if !pw.waitForExistence(timeout: 5) {
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
            email.replaceText("passy-2fa@example.test")
            app.buttons["ContinueButton"].tap()
        }
        XCTAssertTrue(pw.waitForExistence(timeout: 15), "login screen")
        // The simulator can drop characters of a masked field (Vaultwarden log: "Username or password is incorrect" for the
        // 2FA account), so the password is typed into the revealed (plain) field.
        let eye = app.buttons["PasswordVisibilityToggle"]
        if eye.waitForExistence(timeout: 5) { eye.tap(); sleep(1) }
        let plainPw = app.textFields["LoginMasterPasswordEntry"]
        if plainPw.waitForExistence(timeout: 5) { plainPw.tap(); plainPw.typeText(TestAccount.password) } else { pw.replaceText(TestAccount.password) }
        app.buttons["LogInWithMasterPasswordButton"].tap()
        let code = app.textFields["VerificationCodeEntry"]
        XCTAssertTrue(code.waitForExistence(timeout: 20), "two-step login (authenticator) screen")
        shot(app, 44, "\(mode)-2fa-authenticator")
        print("R6REACH 2fa buttons: " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        let other = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'another method' OR label CONTAINS[c] 'other method'")).firstMatch
        let opts = app.buttons.matching(identifier: "Options").allElementsBoundByIndex.last(where: { $0.isHittable })
        if other.exists { other.tap() } else { opts?.tap() }
        sleep(2)
        shot(app, 45, "\(mode)-2fa-methods")
        print("R6REACH 2fa methods: " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
              + " / " + app.menuItems.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        let another = app.buttons["Use another two-step login method"].firstMatch
        if another.exists { another.tap(); sleep(2); shot(app, 48, "\(mode)-2fa-method-sheet") }
        print("R6REACH 2fa sheet: " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
              + " / " + app.sheets.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        // ui-r9: the recovery code (it opened the web vault in Safari) is not offered any more.
        let recovery = app.buttons["Recovery code"].exists ? app.buttons["Recovery code"] : app.menuItems["Recovery code"]
        XCTAssertFalse(recovery.exists, "the recovery code (web vault link) must not be offered")
        setPassYAppearance(.light)
    }
}
