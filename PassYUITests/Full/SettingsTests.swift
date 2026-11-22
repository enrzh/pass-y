import XCTest

/// Settings: account row and menu, sub-screens, autofill set-up section, no upsell/branding/web vault/watch, export.
final class SettingsTests: PassYUITestCase {
    // MARK: 06 Settings and no upsell
    /// Formerly `PassYFlowTests.test06_settingsHasNoPremiumUpsell`.
    func test_noPremiumUpsellNoBranding() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        XCTAssertTrue(waitFor(app.buttons["AccountSecuritySettingsButton"]))
        attach(app, "06-settings")
        let all = app.allLabels.lowercased()
        XCTAssertFalse(all.contains("premium"), "no premium upsell in settings")
        XCTAssertFalse(all.contains("bitwarden"), "no Bitwarden branding in settings:\n\(all)")
        goTo(app, "My vault")
    }

    /// Real taps in Settings: the account row menu offers Lock and Log out; Log out asks for confirmation.
    /// Formerly `PassYFlowTests.test13_settingsAccountMenu`.
    func test_accountRowMenuLockAndLogoutConfirm() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        let row = app.buttons["SettingsAccountRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "account row exists")
        XCTAssertTrue(app.staticTexts["passy-test@example.test"].exists, "account row shows the e-mail")
        row.tap(); sleep(2)
        attach(app, "13-account-menu")
        XCTAssertTrue(app.buttons["Lock now"].waitForExistence(timeout: 5), "menu offers Lock now")
        let logout = app.buttons["Log out"]
        XCTAssertTrue(logout.exists, "menu offers Log out")
        logout.tap(); sleep(2)
        attach(app, "13-logout-confirmation")
        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "log out asks for confirmation")
        cancel.tap()
        XCTAssertTrue(app.buttons["SettingsAccountRow"].waitForExistence(timeout: 5), "still logged in after cancelling")
    }

    /// Real taps through the native settings sub-screens (Appearance form, Other form, Vault list, Folders list).
    /// Formerly `PassYFlowTests.test14_settingsSubscreens`.
    func test_subscreensAppearanceOtherVaultFolders() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        func back() { app.navigationBars.buttons.firstMatch.tap(); sleep(1) }

        let appearance = app.buttons["AppearanceSettingsButton"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 10), "settings list shows Appearance")
        appearance.tap(); sleep(2)
        let theme = app.buttons["ThemeChooser"]
        XCTAssertTrue(theme.waitForExistence(timeout: 5), "Appearance form has the theme picker")
        attach(app, "14-appearance")
        theme.tap(); sleep(1)
        attach(app, "14-appearance-theme-menu")
        XCTAssertTrue(app.buttons["Dark"].waitForExistence(timeout: 5), "theme menu offers Dark")
        app.buttons["Dark"].tap(); sleep(1)
        attach(app, "14-appearance-dark")
        app.buttons["ThemeChooser"].tap(); sleep(1)
        if app.buttons["Default (System)"].exists { app.buttons["Default (System)"].tap() } else { app.buttons["Light"].tap() }
        sleep(1)
        back()

        app.buttons["OtherSettingsButton"].tap(); sleep(2)
        XCTAssertTrue(app.buttons["SyncNowButton"].waitForExistence(timeout: 5), "Other form has Sync now")
        attach(app, "14-other")
        back()

        app.buttons["VaultSettingsButton"].tap(); sleep(2)
        let folders = app.buttons["FoldersLabel"]
        XCTAssertTrue(folders.waitForExistence(timeout: 5), "Vault settings list has My folders")
        attach(app, "14-vault-settings")
        folders.tap(); sleep(2)
        XCTAssertTrue(app.buttons["FolderCell"].firstMatch.waitForExistence(timeout: 10)
            || app.staticTexts["NoFoldersLabel"].exists, "folders list or empty state is shown")
        attach(app, "14-folders")
    }

    /// Real taps through the native Account security, Autofill and About forms (identifiers checked, rows tapped).
    /// Formerly `PassYFlowTests.test16_settingsAccountSecurityAutofillAbout`.
    func test_accountSecurityAutofillAbout() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        func noOptional(_ page: String) { XCTAssertFalse(app.allLabels.contains("Optional("), "\(page) shows Optional( in visible text") }
        func back() { app.navigationBars.buttons.firstMatch.tap(); sleep(1) }

        let accountSecurity = app.buttons["AccountSecuritySettingsButton"]
        XCTAssertTrue(accountSecurity.waitForExistence(timeout: 10), "settings list shows Account security")
        accountSecurity.tap(); sleep(2)
        XCTAssertTrue(app.buttons["VaultTimeoutChooser"].waitForExistence(timeout: 5), "Account security has the timeout picker")
        XCTAssertTrue(app.buttons["VaultTimeoutActionChooser"].exists, "Account security has the timeout action picker")
        XCTAssertFalse(app.buttons["TwoStepLoginLinkItemView"].exists || app.staticTexts["Two-step login"].exists, "ui-r9: no two-step login row (web vault link)")
        attach(app, "16-account-security"); noOptional("account-security")
        app.buttons["VaultTimeoutChooser"].tap(); sleep(1)
        attach(app, "16-account-security-timeout-menu")
        XCTAssertTrue(app.buttons["1 minute"].waitForExistence(timeout: 5), "timeout menu offers 1 minute")
        app.buttons["1 minute"].tap(); sleep(1)
        app.swipeUp(); sleep(1)
        XCTAssertTrue(app.buttons["LogOutLabel"].exists, "Account security has Log out")
        XCTAssertTrue(app.buttons["DeleteAccountLabel"].exists, "Account security has Delete account")
        attach(app, "16-account-security-bottom"); noOptional("account-security-bottom")
        app.buttons["LogOutLabel"].tap(); sleep(1)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Log out asks for confirmation")
        app.alerts.firstMatch.buttons["Cancel"].tap(); sleep(1)
        back()

        app.buttons["AutofillSettingsButton"].tap(); sleep(2)
        XCTAssertTrue(app.buttons["DefaultUriMatchDetectionChooser"].waitForExistence(timeout: 5), "Autofill has the URI match picker")
        XCTAssertTrue(app.switches["CopyTotpAutomaticallySwitch"].exists, "Autofill has the copy TOTP switch")
        attach(app, "16-autofill"); noOptional("autofill")
        back()

        app.buttons["AboutSettingsButton"].tap(); sleep(2)
        XCTAssertTrue(app.switches["SubmitCrashLogsSwitch"].waitForExistence(timeout: 5), "About has the crash logs switch")
        XCTAssertTrue(app.switches["FlightRecorderSwitch"].exists, "About has the flight recorder switch")
        attach(app, "16-about"); noOptional("about")
        let privacy = app.buttons["Privacy Policy"]
        XCTAssertTrue(privacy.exists, "About has the privacy policy row")
        let version = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Version'")).firstMatch
        XCTAssertTrue(version.exists, "About shows the version row")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Web vault' OR label CONTAINS[c] 'Webtresor'")).firstMatch.exists,
                       "ui-r9: no web vault link in About")
        version.tap(); sleep(1)
        attach(app, "16-about-version-copied")
    }

    /// The autofill "set up" prompt is a native section (no Bitwarden action card): action, learn-more and dismiss rows.
    /// A fresh install shows it; tapping Dismiss removes it.
    /// Formerly `PassYFlowTests.test27_setupSectionIsNativeRows`.
    func test_autofillSetupSectionNativeAndDismissPersists() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        app.buttons["AutofillSettingsButton"].tap()
        let action = app.buttons["SetupSectionActionButton"]
        XCTAssertTrue(action.waitForExistence(timeout: 10), "the set-up section is shown on a fresh install\n\(app.debugDescription)")
        XCTAssertTrue(app.buttons["SetupSectionDismissButton"].exists, "dismiss row")
        XCTAssertTrue(app.staticTexts["SetupSectionTitle"].exists || app.staticTexts["Autofill with Pass-Y"].exists, "headline row")
        XCTAssertTrue(app.collectionViews.firstMatch.exists || app.tables.firstMatch.exists, "native list")
        let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
        XCTAssertTrue(list.buttons["SetupSectionActionButton"].exists, "the action is a row of the native list, not a card outside it")
        XCTAssertTrue(list.buttons["SetupSectionDismissButton"].exists, "the dismiss row is part of the native list")
        attach(app, "27-setup-section")
        app.buttons["SetupSectionDismissButton"].tap()
        XCTAssertTrue(waitForDisappearance(of: action, timeout: 8), "dismiss removes the section")
        // The dismissal is persisted: after a relaunch the same page loads (it still has its toggle/rows) without the section.
        app.terminate()
        let app2 = launchApp()
        ensureUnlockedVault(app2)
        goTo(app2, "Settings")
        app2.buttons["AutofillSettingsButton"].tap()
        XCTAssertTrue(app2.switches.firstMatch.waitForExistence(timeout: 10), "autofill page loaded after relaunch")
        XCTAssertFalse(app2.buttons["SetupSectionActionButton"].exists, "dismissed section stays dismissed")
    }

    /// Settings: the account row shows the server (not "Pass-Y") and its menu offers Add account; no watch option, no
    /// web vault links anywhere in Settings.
    /// Formerly `PassYUiR9Tests.test03_settingsAccountRowAndNoWebVaultNoWatch`.
    func test_accountRowServerAddAccountNoWebVaultNoWatch() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        let row = app.buttons["SettingsAccountRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("localhost"), "account row shows the server: \(row.label)")
        XCTAssertFalse(row.label.contains("Pass-Y"))
        shot(app, 3, "settings")
        row.tap(); sleep(1)
        XCTAssertTrue(app.buttons["SettingsAddAccountButton"].waitForExistence(timeout: 5), "Add account in the Settings account menu")
        shot(app, 4, "settings-account-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap(); sleep(1)

        func noWebVault(_ page: String) {
            XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'web vault' OR label CONTAINS[c] 'Webtresor' OR label CONTAINS[c] 'Two-step'")).firstMatch.exists, "\(page): no web vault link")
        }
        for (id, name) in [("AccountSecuritySettingsButton", "account security"), ("VaultSettingsButton", "vault"),
                           ("OtherSettingsButton", "other"), ("AboutSettingsButton", "about")] {
            app.buttons[id].tap(); sleep(1)
            noWebVault(name)
            XCTAssertFalse(containing(app, "watch").allElementsBoundByIndex.contains { $0.elementType == .switch }, "\(name): no watch switch")
            if name == "other" { shot(app, 5, "other") }
            app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        }
    }

    /// Settings > Vault > Export vault > Export to a file: format picker, encrypted file password fields.
    /// Formerly `PassYImportRegShotsTests.test_exportVault`.
    func test_exportVaultForm() {
        let t = tag
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        let vault = app.buttons["VaultSettingsButton"]
        XCTAssertTrue(waitFor(vault, timeout: 10)); vault.tap()
        let export = app.buttons["ExportVaultLabel"]
        XCTAssertTrue(waitFor(export, timeout: 10)); export.tap()
        let toFile = app.buttons["ExportVaultToAFileLabel"]
        XCTAssertTrue(waitFor(toFile, timeout: 10), "export settings list")
        attach(app, "\(t)-export-settings-light")
        setPassYAppearance(.dark)
        sleep(2)
        attachDarkIfRendered(app, "\(t)-export-settings-dark")
        setPassYAppearance(.light)
        toFile.tap()
        let picker = app.buttons["FileFormatPicker"]
        XCTAssertTrue(waitFor(picker, timeout: 10), "export form shows the file format picker")
        attach(app, "\(t)-export-form-light")
        picker.tap(); sleep(1)
        let enc = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Password protected'")).firstMatch
        let encItem = app.menuItems.matching(NSPredicate(format: "label CONTAINS 'Password protected'")).firstMatch
        XCTAssertTrue(enc.waitForExistence(timeout: 5) || encItem.exists, "picker offers encrypted json")
        (encItem.exists ? encItem : enc).tap(); sleep(1)
        XCTAssertTrue(app.secureTextFields["FilePasswordEntry"].firstMatch.waitForExistence(timeout: 5),
                      "file password fields appear for encrypted json")
        attach(app, "\(t)-export-form-encrypted-light")
        setPassYAppearance(.dark)
        sleep(2)
        attachDarkIfRendered(app, "\(t)-export-form-encrypted-dark")
        setPassYAppearance(.light)
        let mp = app.secureTextFields["MasterPasswordEntry"]
        XCTAssertTrue(mp.exists, "master password field")
        app.buttons["ExportVaultButton"].tap()
        sleep(2)
        attach(app, "\(t)-export-tap-without-input")
    }
}
