import XCTest

/// Audit screenshots of the main screens in light and dark mode (used for the before/after comparison of ui-r3).
/// Works with the tab bar (before) and the avatar menu (after). Screenshots are kept as xcresult attachments named
/// `<PASSY_SHOT_TAG>-<light|dark>-<nn>-<screen>`. Needs the throwaway Vaultwarden and a fresh install for the first test.
final class PassYAuditShotsTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "audit" }

    /// Switches the top-level screen with the tab bar (before) or the avatar menu (after).
    private func open(_ app: XCUIApplication, _ label: String) {
        let bar = app.tabBars.buttons[label]
        if bar.exists { bar.tap(); return }
        let avatar = app.buttons["CurrentActiveAccount"]
        if avatar.waitForExistence(timeout: 10) { avatar.tap() }
        let item = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if item.waitForExistence(timeout: 5) { item.tap() }
    }

    private func shot(_ app: XCUIApplication, _ mode: String, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(mode)-\(String(format: "%02d", n))-\(name)")
    }

    private func back(_ app: XCUIApplication) {
        let b = app.navigationBars.buttons.firstMatch
        if b.exists { b.tap() }
        sleep(1)
    }

    /// Fresh install: landing, server sheet, login e-mail and master password screens.
    func test_a_onboarding() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
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
        XCUIDevice.shared.appearance = .light
    }

    /// Vault, lists, settings, generator, send, item view and add form in both appearances.
    func test_b_mainScreens() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            if !app.staticTexts["GitHub"].exists, !app.buttons["CategoryTile_login"].exists { sleep(2) }
            var n = 10
            shot(app, mode, n, "vault-home"); n += 1
            // Item list (login tile) and an item.
            let tile = app.buttons["CategoryTile_login"]
            if tile.waitForExistence(timeout: 5) {
                tile.tap(); sleep(2)
                shot(app, mode, n, "item-list"); n += 1
                let row = app.buttons["VaultListItemRowButton"].firstMatch
                if row.waitForExistence(timeout: 5) {
                    row.tap(); sleep(2)
                    shot(app, mode, n, "item-view"); n += 1
                    let edit = app.buttons["Edit"].firstMatch
                    if edit.exists { edit.tap(); sleep(2); shot(app, mode, n, "item-edit"); n += 1
                        let close = app.buttons["CancelButton"].exists ? app.buttons["CancelButton"] : app.buttons["Close"]
                        if close.exists { close.firstMatch.tap(); sleep(1) }
                        if app.buttons["Cancel"].waitForExistence(timeout: 2) { app.buttons["Cancel"].tap() }
                    } else {
                        let close = app.buttons["Close"]
                        if close.exists { close.firstMatch.tap(); sleep(1) }
                    }
                    if app.buttons["Close"].exists { app.buttons["Close"].firstMatch.tap(); sleep(1) }
                }
                back(app)
            }
            // Add form.
            if app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5) {
                app.buttons["AddItemFloatingActionButton"].tap(); sleep(1)
                shot(app, mode, n, "add-menu"); n += 1
                tapNewLoginMenuItem(app); sleep(2)
                shot(app, mode, n, "add-item-form"); n += 1
                let cancel = app.buttons["CancelButton"].firstMatch
                if cancel.exists { cancel.tap(); sleep(1) }
                if app.buttons["Cancel"].waitForExistence(timeout: 2) { app.buttons["Cancel"].tap() }
            }
            // Search.
            focusSearch(app)
            for ch in "Git" { app.typeText(String(ch)); usleep(150_000) }
            sleep(2)
            shot(app, mode, n, "search"); n += 1
            if app.buttons["VaultSearchCancel"].exists { app.buttons["VaultSearchCancel"].tap(); sleep(1) }
            // Generator, Send.
            open(app, "Generator"); sleep(1)
            shot(app, mode, n, "generator"); n += 1
            open(app, "Send"); sleep(2)
            shot(app, mode, n, "send"); n += 1
            // Settings and sub pages.
            open(app, "Settings"); sleep(2)
            shot(app, mode, n, "settings"); n += 1
            for (id, name) in [("AccountSecuritySettingsButton", "account-security"), ("AutofillSettingsButton", "autofill"),
                               ("AppearanceSettingsButton", "appearance"), ("OtherSettingsButton", "other"),
                               ("AboutSettingsButton", "about")] {
                let row = app.buttons[id]
                if row.waitForExistence(timeout: 5) {
                    row.tap(); sleep(2)
                    shot(app, mode, n, "settings-\(name)"); n += 1
                    if name == "autofill", app.buttons["AppExtensionLabel"].exists || app.buttons["App extension"].exists {
                        let ext = app.buttons["AppExtensionLabel"].exists ? app.buttons["AppExtensionLabel"] : app.buttons["App extension"]
                        ext.tap(); sleep(2)
                        shot(app, mode, n, "settings-app-extension"); n += 1
                        back(app)
                    }
                    back(app)
                }
            }
            let vaultSettings = app.buttons["VaultSettingsButton"]
            if vaultSettings.waitForExistence(timeout: 5) {
                vaultSettings.tap(); sleep(2)
                shot(app, mode, n, "settings-vault"); n += 1
                let folders = app.buttons["FoldersLabel"]
                if folders.waitForExistence(timeout: 5) {
                    folders.tap(); sleep(2)
                    shot(app, mode, n, "folders"); n += 1
                    let add = app.buttons["AddItemButton"]
                    if add.exists { add.tap(); sleep(2); shot(app, mode, n, "add-folder"); n += 1
                        let c = app.buttons["CancelButton"].firstMatch
                        if c.exists { c.tap() } }
                }
            }
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Locked vault: master password unlock screen in both appearances.
    func test_c_unlock() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            app.terminate()
            let app2 = launchApp()
            if waitFor(app2.secureTextFields["MasterPasswordEntry"], timeout: 30) {
                shot(app2, mode, 6, "unlock")
            }
            app2.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Send: add form (text) and the typed list.
    func test_d_send() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            open(app, "Send"); sleep(2)
            shot(app, mode, 39, "send-list")
            let add = app.buttons["AddItemFloatingActionButton"]
            if add.waitForExistence(timeout: 10) {
                add.tap(); sleep(1)
                let menuText = app.menuItems["Text"]
                let text = app.buttons.matching(NSPredicate(format: "label == 'Text'")).firstMatch
                if menuText.waitForExistence(timeout: 5) || text.waitForExistence(timeout: 5) {
                    (menuText.exists ? menuText : text).tap(); sleep(2)
                    shot(app, mode, 40, "send-add")
                    let c = app.buttons["CancelButton"].firstMatch
                    if c.exists { c.tap(); sleep(1) }
                    if app.buttons["Cancel"].waitForExistence(timeout: 2) { app.buttons["Cancel"].tap() }
                }
            }
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Password history, item attachments and the item "..." menu.
    func test_e_sheets() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            open(app, "Generator"); sleep(2)
            let options = app.buttons["HeaderBarOptionsButton"].exists ? app.buttons["HeaderBarOptionsButton"] : app.buttons["Options"]
            if options.waitForExistence(timeout: 5) {
                options.tap(); sleep(1)
                let hist = app.buttons["Password history"]
                if hist.waitForExistence(timeout: 3) {
                    hist.tap(); sleep(2)
                    shot(app, mode, 50, "password-history")
                    let c = app.buttons["CloseButton"].exists ? app.buttons["CloseButton"] : app.buttons["Close"]
                    if c.exists { c.firstMatch.tap(); sleep(1) }
                }
            }
            open(app, "My vault"); sleep(2)
            let tile = app.buttons["CategoryTile_login"]
            if tile.waitForExistence(timeout: 5) {
                tile.tap(); sleep(2)
                let row = app.buttons["VaultListItemRowButton"].firstMatch
                if row.waitForExistence(timeout: 5) {
                    row.tap(); sleep(2)
                    shot(app, mode, 51, "item-view-toolbar")
                    let opt = app.buttons["CipherOptionsButton"].exists ? app.buttons["CipherOptionsButton"].firstMatch : app.buttons["Options"].firstMatch
                    if opt.exists {
                        opt.tap(); sleep(1)
                        shot(app, mode, 52, "item-menu")
                        let att = app.buttons["Attachments"]
                        if att.waitForExistence(timeout: 3) {
                            att.tap(); sleep(2)
                            shot(app, mode, 53, "attachments")
                        }
                    }
                }
            }
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }
}
