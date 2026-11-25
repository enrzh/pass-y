import XCTest

/// Before/after screenshots of the settings and auth pages for the PassYDesign work (settings main and its sub-pages,
/// the unlock screen, the landing and login screens): light and dark, plus Accessibility XXXL for settings and unlock.
/// Runs on the phone or the iPad simulator, never gating (run by name; `STEP_ENV="PASSY_DESIGN_TAG=<set>"` names the
/// set). A missing element skips that screen instead of failing the whole set.
final class SettingsAuthShotsTests: PassYUITestCase {
    private var set: String { ProcessInfo.processInfo.environment["PASSY_DESIGN_TAG"] ?? "shots" }

    /// The settings sub-pages: row identifier and shot name.
    private let subPages = [
        ("AccountSecuritySettingsButton", "account-security"),
        ("AutofillSettingsButton", "autofill"),
        ("VaultSettingsButton", "vault"),
        ("AppearanceSettingsButton", "appearance"),
        ("OtherSettingsButton", "other"),
        ("AboutSettingsButton", "about"),
    ]

    func test_settingsAndAuthPages() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            settingsPages(app, mode)
            // A cold start locks the vault: the unlock screen.
            app.terminate()
            let relaunched = launchApp()
            if relaunched.secureTextFields["MasterPasswordEntry"].waitForExistence(timeout: 20) {
                capture(relaunched, mode, 20, "unlock")
            }
            ensureUnlockedVault(relaunched)
            logOutIfLoggedIn(relaunched)
            sleep(2)
            capture(relaunched, mode, 21, "landing")
            reachLoginPasswordScreen(relaunched, email: TestAccount.email)
            sleep(1)
            capture(relaunched, mode, 22, "login")
            ensureUnlockedVault(relaunched)
            relaunched.terminate()
        }
        setPassYAppearance(.light)
        let app = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        ensureUnlockedVault(app)
        goTo(app, "Settings"); sleep(2)
        capture(app, "light-ax", 1, "settings")
        if tapIfPresent(app.buttons["AccountSecuritySettingsButton"]) {
            sleep(2); capture(app, "light-ax", 2, "account-security"); back(app)
        }
        app.terminate()
        let relaunched = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        if relaunched.secureTextFields["MasterPasswordEntry"].waitForExistence(timeout: 20) {
            capture(relaunched, "light-ax", 20, "unlock")
        }
        ensureUnlockedVault(relaunched)
        relaunched.terminate()
    }

    /// Settings main and every sub-page reachable from it.
    private func settingsPages(_ app: XCUIApplication, _ mode: String) {
        goTo(app, "Settings"); sleep(2)
        capture(app, mode, 1, "settings")
        app.swipeUp(); sleep(1)
        capture(app, mode, 2, "settings-scrolled")
        app.swipeDown(); sleep(1)
        for (index, page) in subPages.enumerated() {
            guard tapIfPresent(app.buttons[page.0]) else { continue }
            sleep(2)
            capture(app, mode, 3 + index, page.1)
            back(app)
            _ = app.buttons["AccountSecuritySettingsButton"].waitForExistence(timeout: 5)
        }
    }

    private func tapIfPresent(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 8) else { return false }
        for _ in 0 ..< 4 where !element.isHittable { XCUIApplication().swipeUp() }
        guard element.isHittable else { return false }
        element.tap()
        return true
    }

    private func capture(_ app: XCUIApplication, _ mode: String, _ n: Int, _ name: String) {
        sleep(1)
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "phone"
        attachUnchecked(app, "\(set)-\(device)-\(mode)-\(String(format: "%02d", n))-\(name)")
    }
}
