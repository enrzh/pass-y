import XCTest

/// Login sub-screens (password hint, login with device, SSO), log in with device after a logout, registration start.
final class AuthScreensTests: PassYUITestCase {
    /// Reaches the login sub-screens (password hint, login with device, SSO) and the two-step login screens
    /// (authenticator and recovery code) of the 2FA test account (`enable_2fa.py`), light and dark. Needs a fresh install.
    /// What is reachable is printed as `R6REACH`; each screen found is asserted.
    /// Formerly `PassYUiR6ShotsTests.test_authPagesInRunningApp`.
    func test_loginSubscreens() {
        // Formerly one chain step per appearance (TEST_RUNNER_PASSY_MODE); now both in one run unless PASSY_MODE is set.
        for mode in passYModes() {
        setPassYAppearance(mode == "dark" ? .dark : .light)
        let app = launchApp()
        // Deterministic start from any state: log out if needed, set the server, enter the e-mail (verified). The intro
        // ("Log in") and the server sheet of a fresh install are asserted by AuthLandingTests.
        reachLoginPasswordScreen(app, email: TestAccount.twoFactorEmail)
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
            let ok = app.alerts.buttons["OK"]
            if ok.waitForExistence(timeout: 3) { ok.tap(); sleep(1); shot(app, 47, "\(mode)-sso-after-alert") }
            leaveScreen(app)
        }
        }
        setPassYAppearance(.light)
    }

    /// "Log in with device" is only offered for a known device: after a normal login and a log out of the test account the
    /// server knows this app id, so the login screen shows the button and the screen can be opened and shot.
    /// Formerly `PassYUiR6ShotsTests.test_loginWithDeviceAfterLogout`.
    func test_loginWithDeviceAfterLogout() {
        // Formerly four chain steps (light, dark, light-b, dark-b); now light and dark in one run unless PASSY_MODE is set.
        for mode in passYModes() {
        setPassYAppearance(mode == "dark" ? .dark : .light)
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        let row = app.buttons["SettingsAccountRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["Log out"].waitForExistence(timeout: 5), "account menu offers Log out")
        app.buttons["Log out"].tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5)); yes.tap()
        let email = app.textFields["LoginEmailAddressEntry"]
        let logIn = app.buttons["Log in"]
        if !email.waitForExistence(timeout: 15), logIn.waitForExistence(timeout: 5) { logIn.tap() }
        XCTAssertTrue(email.waitForExistence(timeout: 15))
        waitUntil(10) { email.isHittable }
        email.replaceText(TestAccount.email)
        PassYSession.loginEmail = TestAccount.email
        app.buttons["ContinueButton"].tap()
        let device = app.buttons["LogInWithAnotherDeviceButton"]
        let offered = device.waitForExistence(timeout: 30)
        if !offered { print("DEVICE-BUTTON-MISSING \(Date()) tree:\n\(app.debugDescription)") }
        XCTAssertTrue(offered, "known device: Log in with device is offered")
        shot(app, 50, "\(mode)-login-known-device")
        device.tap(); sleep(4)
        shot(app, 51, "\(mode)-login-with-device")
        print("R6REACH login-with-device screen buttons: " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        }
        setPassYAppearance(.light)
    }

    /// Landing -> Create account: start registration form, fill, press Continue (no mail server: error or check-email).
    /// Formerly `PassYImportRegShotsTests.test_registrationStart`.
    func test_registrationStart() {
        let t = tag
        let app = launchApp()
        // Runs after other tests in the same app: log out first (the landing then has the server set already).
        logOutIfLoggedIn(app)
        // A fresh install starts on the intro carousel; "Log in" leads to the landing screen.
        if app.buttons["Log in"].waitForExistence(timeout: 3) { app.buttons["Log in"].tap() }
        // The server sheet is presented automatically on a fresh install (state driven: sheet or landing, no fixed 40 s).
        let server = app.textFields["ServerUrlEntry"]
        waitUntil(40) { server.exists || app.buttons["CreateAccountButton"].exists }
        if server.exists {
            server.replaceText(TestAccount.server)
            app.buttons["SaveButton"].firstMatch.tap()
        }
        let create = app.buttons["CreateAccountButton"]
        XCTAssertTrue(waitFor(create), "landing offers Create account")
        create.tap()
        let email = app.textFields["EmailAddressEntry"]
        XCTAssertTrue(waitFor(email), "start registration shows the email field")
        sleep(1)
        attach(app, "\(t)-reg-start-light")
        setPassYAppearance(.dark)
        sleep(2)
        attachDarkIfRendered(app, "\(t)-reg-start-dark")
        setPassYAppearance(.light)
        email.replaceText("passy-ir-new@example.test")
        let name = app.textFields["NameEntry"]
        name.replaceText("IR Test")
        attach(app, "\(t)-reg-start-filled")
        // Return through the focused field, not the on-screen key: when the simulator's software keyboard is hidden
        // (reported off screen, e.g. {300.7, 1087.0}, while a hardware keyboard is considered connected) the key button
        // exists but cannot be tapped; typed input still reaches the focused field.
        name.typeText("\n")
        // The landing screen below the registration form also has a "ContinueButton": take the visible, hittable one.
        _ = app.buttons["ContinueButton"].firstMatch.waitForExistence(timeout: 5)
        guard let cont = app.buttons.matching(identifier: "ContinueButton").allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("no hittable ContinueButton"); return
        }
        cont.tap()
        sleep(4)
        attach(app, "\(t)-reg-start-after-continue")
    }
}
