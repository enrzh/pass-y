import XCTest

/// Audit screenshots of the main screens, light and dark. Never gating.
final class ShotsMainScreensTests: PassYUITestCase {
    /// Formerly `PassYShotsTests.test_shots`.
    func test_mainScreens() {
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let tag = ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "shot"
        let env = ProcessInfo.processInfo.environment
        if env["PASSY_SHOT_MODE"] == "dark" { setPassYAppearance(.dark) }
        defer { setPassYAppearance(.light) }
        let app = launchApp(extraArguments: env["PASSY_SHOT_XXXL"] == "1"
            ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : [])
        ensureUnlockedVault(app)
        // seed_ciphers.py creates GitHub (with TOTP), Netflix and Bank; only add them through the UI when missing.
        if env["PASSY_SKIP_SEED"] != "1", !app.staticTexts["GitHub"].exists,
           !app.buttons["CategoryTile_totp"].waitForExistence(timeout: 5) {
            addLogin(app, name: "GitHub", user: "octo@example.test", password: "Gh-Pass-1234", totp: "JBSWY3DPEHPK3PXP")
            addLogin(app, name: "Netflix", user: "movie@example.test", password: "Nf-Pass-5678")
            addLogin(app, name: "Bank", user: "me@example.test", password: "Bk-Pass-9012")
        }
        sleep(2)
        attach(app, "\(tag)-1-home")
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
        let land = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        land.name = "\(tag)-1b-home-landscape"; land.lifetime = .keepAlways; add(land)
        XCUIDevice.shared.orientation = .portrait; sleep(1)
        if !app.staticTexts["GitHub"].exists {
            // With a large vault the item is below the fold: find it through the bottom search bar.
            focusSearch(app)
            typeSearch(app, "GitHub")
            _ = app.staticTexts["GitHub"].waitForExistence(timeout: 20)
        }
        if app.staticTexts["GitHub"].exists {
            app.staticTexts["GitHub"].firstMatch.tap()
            sleep(2)
            attach(app, "\(tag)-2-detail")
            let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
            if close.exists { close.firstMatch.tap() }
            if app.buttons["Cancel"].waitForExistence(timeout: 3) { app.buttons["Cancel"].tap() }
        }
        goTo(app, "Generator"); sleep(1)
        attach(app, "\(tag)-3-generator")
        goTo(app, "Settings"); sleep(1)
        attach(app, "\(tag)-4-settings")
        goTo(app, "My vault")
        // iOS 26 shows the search bar cancel as an X button (label "Cancel" or "Close" depending on the OS build).
        // The cancel/X button belongs to the bottom search bar (other "Close" buttons, e.g. sheets, must not match).
        let cancel = app.buttons["VaultSearchCancel"]
        attach(app, "\(tag)-4a-before-cancel")
        if cancel.waitForExistence(timeout: 3) { cancel.tap(); sleep(2) }
        attach(app, "\(tag)-4b-before-add")
        if !app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5) {
            XCTFail("Add button missing after closing the search\n\(app.debugDescription)")
        }
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app); sleep(2)
        attach(app, "\(tag)-5-add")
    }

    /// Vault, lists, settings, generator, send, item view and add form in both appearances.
    /// Formerly `PassYAuditShotsTests.test_b_mainScreens`.
    func test_auditMainScreens() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
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
            typeSearch(app, "Git")
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
        setPassYAppearance(.light)
    }

    /// Locked vault: master password unlock screen in both appearances.
    /// Formerly `PassYAuditShotsTests.test_c_unlock`.
    func test_auditUnlock() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            app.terminate()
            let app2 = launchApp()
            if waitFor(app2.secureTextFields["MasterPasswordEntry"], timeout: 30) {
                shot(app2, mode, 6, "unlock")
            }
            app2.terminate()
        }
        setPassYAppearance(.light)
    }

    /// Send: add form (text) and the typed list.
    /// Formerly `PassYAuditShotsTests.test_d_send`.
    func test_auditSend() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
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
        setPassYAppearance(.light)
    }

    /// Password history, item attachments and the item "..." menu.
    /// Formerly `PassYAuditShotsTests.test_e_sheets`.
    func test_auditSheets() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
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
        setPassYAppearance(.light)
    }
}
