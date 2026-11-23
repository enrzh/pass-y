import XCTest

/// Screenshots of the settings set-up sections. Never gating.
final class ShotsSettingsTests: PassYUITestCase {
    /// Settings pages with the "set up" sections (autofill "Turn on now", account security, vault settings).
    /// Formerly `PassYUiR4ShotsTests.test_setupSections`.
    func test_setupSections() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            goTo(app, "Settings"); sleep(2)
            for (n, id, name) in [(60, "AutofillSettingsButton", "autofill"), (61, "AccountSecuritySettingsButton", "account-security"),
                                  (62, "VaultSettingsButton", "vault-settings")] {
                let row = app.buttons[id]
                if row.waitForExistence(timeout: 5) {
                    row.tap(); sleep(2)
                    shot(app, mode, n, "setup-\(name)")
                    let b = app.navigationBars.buttons["BackButton"].exists ? app.navigationBars.buttons["BackButton"] : app.navigationBars.buttons.firstMatch
                    if b.exists { b.tap(); sleep(1) }
                }
            }
            app.terminate()
        }
        setPassYAppearance(.light)
    }
}
