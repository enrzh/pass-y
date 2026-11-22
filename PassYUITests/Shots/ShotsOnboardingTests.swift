import XCTest

/// Screenshots of the first-launch screens (needs a fresh install: the shots tier runs this class in its own fresh step). Never gating.
final class ShotsOnboardingTests: PassYUITestCase {
    /// Formerly `PassYLandingShotsTests.test_landingShot`.
    func test1_landing() {
        let app = launchApp()
        XCTAssertTrue(waitFor(app.buttons["Log in"]))
        app.buttons["Log in"].tap()
        XCTAssertTrue(waitFor(app.textFields["ServerUrlEntry"]))
        attach(app, "\(tag)-server")
        app.buttons["CancelButton"].firstMatch.tap()
        XCTAssertTrue(waitFor(app.buttons["RegionSelectorDropdown"]))
        attach(app, "\(tag)-landing")
    }

    /// Fresh install: landing, server sheet, login e-mail and master password screens.
    /// Formerly `PassYAuditShotsTests.test_a_onboarding`.
    func test2_auditOnboarding() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            XCTAssertTrue(waitFor(app.buttons["Log in"]), "landing")
            shot(app, mode, 1, "landing")
            if app.buttons["Create account"].exists {
                app.buttons["Create account"].tap()
                if waitFor(app.textFields["EmailAddressEntry"], timeout: 10) {
                    shot(app, mode, 5, "registration")
                    let cancel = app.buttons["CancelButton"].firstMatch
                    if cancel.exists { cancel.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
                    sleep(1)
                }
            }
            app.buttons["Log in"].tap()
            if waitFor(app.textFields["ServerUrlEntry"], timeout: 10) {
                shot(app, mode, 2, "server-setup")
                app.buttons["CancelButton"].firstMatch.tap()
            }
            if mode == "light" {
                // Set the server once, then show the e-mail and password screens.
                let dropdown = app.buttons["RegionSelectorDropdown"]
                if waitFor(dropdown, timeout: 10) { dropdown.tap() }
                let server = app.textFields["ServerUrlEntry"]
                if waitFor(server, timeout: 10) {
                    server.tap(); server.typeText(TestAccount.server)
                    app.buttons["SaveButton"].firstMatch.tap(); sleep(2)
                }
            }
            let email = app.textFields["LoginEmailAddressEntry"]
            if waitFor(email, timeout: 10), email.isHittable {
                if mode == "light" { email.tap(); email.typeText(TestAccount.email) }
                shot(app, mode, 3, "login-email")
                if mode == "light", app.buttons["ContinueButton"].isEnabled {
                    app.buttons["ContinueButton"].tap()
                    if waitFor(app.secureTextFields["LoginMasterPasswordEntry"], timeout: 15) {
                        shot(app, mode, 4, "login-password")
                    }
                }
            }
            app.terminate()
        }
        setPassYAppearance(.light)
    }

    /// Rare auth screens reachable from the login page (needs a fresh install): password hint, login with device, SSO.
    /// Formerly `PassYUiR4ShotsTests.test_a_auth`.
    func test3_loginSubscreens() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            XCTAssertTrue(waitFor(app.buttons["Log in"]))
            app.buttons["Log in"].tap()
            let dropdown = app.buttons["RegionSelectorDropdown"]
            if waitFor(dropdown, timeout: 10), dropdown.label.contains("Not set") {
                dropdown.tap()
                let server = app.textFields["ServerUrlEntry"]
                if waitFor(server, timeout: 10) {
                    server.tap(); server.typeText(TestAccount.server)
                    app.buttons["SaveButton"].firstMatch.tap(); sleep(2)
                }
            }
            let email = app.textFields["LoginEmailAddressEntry"]
            if waitFor(email, timeout: 10) {
                email.tap(); email.typeText(TestAccount.email)
                app.buttons["ContinueButton"].tap()
            }
            if waitFor(app.secureTextFields["LoginMasterPasswordEntry"], timeout: 15) {
                shot(app, mode, 40, "login-password")
                let hint = app.buttons["GetMasterPasswordHintLabel"]
                if hint.exists {
                    hint.tap(); sleep(2); shot(app, mode, 41, "password-hint")
                    cancelOrClose(app); sleep(1)
                }
                let dev = app.buttons["LogInWithAnotherDeviceButton"]
                if dev.exists {
                    dev.tap(); sleep(3); shot(app, mode, 42, "login-with-device")
                    cancelOrClose(app); sleep(1)
                    if !app.secureTextFields["LoginMasterPasswordEntry"].exists { app.navigationBars.buttons.firstMatch.tap(); sleep(1) }
                }
                let sso = app.buttons["EnterpriseSingleSignOnButton"].exists ? app.buttons["EnterpriseSingleSignOnButton"]
                    : app.buttons.matching(NSPredicate(format: "label CONTAINS 'single sign-on'")).firstMatch
                if sso.exists {
                    sso.tap(); sleep(2); shot(app, mode, 43, "sso")
                    cancelOrClose(app)
                }
            }
            app.terminate()
        }
        setPassYAppearance(.light)
    }
}
