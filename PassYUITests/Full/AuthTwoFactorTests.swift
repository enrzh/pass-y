import XCTest

/// Two-step login (authenticator) of the 2FA test account (`enable_2fa.py`).
final class AuthTwoFactorTests: PassYUITestCase {
    /// Two-step login (authenticator, other methods, recovery code) of the 2FA test account; run after a fresh install
    /// (it starts at the intro or the login screen).
    /// Formerly `PassYUiR6ShotsTests.test_auth2FAScreens`.
    func test_twoStepLoginScreens() {
        // Formerly one chain step per appearance (TEST_RUNNER_PASSY_MODE); now both in one run unless PASSY_MODE is set.
        for mode in passYModes() {
        setPassYAppearance(mode == "dark" ? .dark : .light)
        let app = launchApp()
        let pw = app.secureTextFields["LoginMasterPasswordEntry"]
        // Deterministic start from any state (vault, landing, intro, another login): log out, server, e-mail (verified).
        reachLoginPasswordScreen(app, email: TestAccount.twoFactorEmail)
        XCTAssertTrue(pw.waitForExistence(timeout: 15), "login screen")
        // The password goes into the revealed (plain) field and is verified there (`replaceText` compares the exact
        // value): the former unverified `typeText` lost a character under load, Vaultwarden answered "Username or
        // password is incorrect" and the two-step screen never came (the 2fa-dark flake of ui-r9).
        let eye = app.buttons["PasswordVisibilityToggle"]
        if eye.waitForExistence(timeout: 5) { eye.tap() }
        let plainPw = app.textFields["LoginMasterPasswordEntry"]
        if plainPw.waitForExistence(timeout: 5) { plainPw.replaceText(TestAccount.password) } else { pw.replaceText(TestAccount.password) }
        app.buttons["LogInWithMasterPasswordButton"].tap()
        let code = app.textFields["VerificationCodeEntry"]
        waitUntil(60) { code.exists || app.alerts.firstMatch.exists }
        if app.alerts.firstMatch.exists {
            print("LOGIN-ALERT 2fa: \(app.alerts.firstMatch.staticTexts.allElementsBoundByIndex.map(\.label)) load=\(passYLoad())")
        }
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
        }
        setPassYAppearance(.light)
    }
}
