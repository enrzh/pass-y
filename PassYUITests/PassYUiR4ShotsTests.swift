import XCTest

/// Screenshots for ui-r4 (native Form/List for item, send and rare auth screens). Attachment names:
/// `<PASSY_SHOT_TAG>-<light|dark>-<nn>-<screen>`. Needs the throwaway Vaultwarden; run `test_a_*` right after an
/// uninstall only for the auth screens that need the login page.
final class PassYUiR4ShotsTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "r4" }

    private func shot(_ app: XCUIApplication, _ mode: String, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(mode)-\(String(format: "%02d", n))-\(name)")
    }

    /// Whole-screen shot (system menus are not part of the app screenshot).
    private func screenShot(_ mode: String, _ n: Int, _ name: String) {
        sleep(1)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "\(tag)-\(mode)-\(String(format: "%02d", n))-\(name)"
        a.lifetime = .keepAlways
        add(a)
    }

    private func cancelOrClose(_ app: XCUIApplication) {
        for id in ["CancelButton", "CloseButton", "Close", "Cancel"] {
            let b = app.buttons[id].firstMatch
            if b.exists, b.isHittable { b.tap(); sleep(1); return }
        }
    }

    private func discardIfAsked(_ app: XCUIApplication) {
        let c = app.buttons["Cancel"].firstMatch
        if c.waitForExistence(timeout: 1) { c.tap() }
    }

    /// Item view, edit (login), "..." menu, attachments, password history, add forms for every item type.
    func test_item() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            let tile = app.buttons["CategoryTile_login"]
            XCTAssertTrue(tile.waitForExistence(timeout: 10))
            tile.tap(); sleep(2)
            let row = app.buttons["VaultListItemRowButton"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap(); sleep(2)
            shot(app, mode, 1, "item-view")
            app.swipeUp(); sleep(1)
            shot(app, mode, 2, "item-view-bottom")
            app.swipeDown(); sleep(1)
            // "..." menu
            let opt = app.navigationBars.buttons["Options"].firstMatch
            print("R4DEBUG nav buttons: \(app.navigationBars.buttons.allElementsBoundByIndex.map { $0.label + "|" + $0.identifier })")
            if opt.waitForExistence(timeout: 3) {
                opt.tap(); sleep(1)
                screenShot(mode, 3, "item-menu")
                print("R4DEBUG menu: \(app.menuItems.allElementsBoundByIndex.map(\.label)) buttons: \(app.buttons.allElementsBoundByIndex.map(\.label))")
                let att = app.menuItems["Attachments"].exists ? app.menuItems["Attachments"] : app.buttons["Attachments"]
                if att.waitForExistence(timeout: 3) {
                    att.tap(); sleep(2)
                    shot(app, mode, 4, "attachments")
                    cancelOrClose(app); discardIfAsked(app)
                } else { app.tap() }
            }
            // Edit
            let edit = app.buttons["Edit"].firstMatch
            if edit.waitForExistence(timeout: 3) {
                edit.tap(); sleep(2)
                shot(app, mode, 5, "item-edit")
                app.swipeUp(); sleep(1)
                shot(app, mode, 6, "item-edit-bottom")
                cancelOrClose(app); discardIfAsked(app)
            }
            cancelOrClose(app)
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// The add form for every item type.
    func test_addTypes() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            var n = 10
            for type in ["Login", "Card", "Identity", "Secure note", "SSH key", "Bank account", "Passport", "Driver"] {
                let fab = app.buttons["AddItemFloatingActionButton"]
                guard fab.waitForExistence(timeout: 8) else { break }
                fab.tap(); sleep(1)
                let item = app.menuItems.matching(NSPredicate(format: "label BEGINSWITH %@", type)).firstMatch
                let btn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT (identifier BEGINSWITH 'CategoryTile')", type)).firstMatch
                if item.waitForExistence(timeout: 3) { item.tap() } else if btn.waitForExistence(timeout: 2) { btn.tap() } else { app.tap(); continue }
                sleep(2)
                shot(app, mode, n, "add-\(type.lowercased().replacingOccurrences(of: " ", with: "-"))"); n += 1
                if type == "Login" { app.swipeUp(); sleep(1); shot(app, mode, n, "add-login-bottom"); n += 1 }
                cancelOrClose(app); discardIfAsked(app)
            }
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Send type list (tap a type row in the Send list).
    func test_sendTypeList() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            goTo(app, "Send"); sleep(2)
            let row = app.staticTexts["Text"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 8))
            row.tap(); sleep(2)
            print("R4DEBUG type list texts: \(app.staticTexts.allElementsBoundByIndex.prefix(6).map(\.label)) nav: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier))")
            shot(app, mode, 21, "send-type-list")
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Send: type list, text add, file add, send view and edit; password history.
    func test_send() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            goTo(app, "Send"); sleep(2)
            shot(app, mode, 20, "send-list")
            for (i, kind) in ["Text", "File"].enumerated() {
                let add = app.buttons["AddItemFloatingActionButton"]
                guard add.waitForExistence(timeout: 8) else { break }
                add.tap(); sleep(1)
                let menuItem = app.menuItems[kind]
                let btn = app.buttons.matching(NSPredicate(format: "label == %@", kind)).firstMatch
                if !menuItem.waitForExistence(timeout: 2), !btn.exists { add.tap(); sleep(1) }
                if menuItem.waitForExistence(timeout: 3) { menuItem.tap() } else if btn.waitForExistence(timeout: 2) { btn.tap() } else {
                    print("R4DEBUG no \(kind) entry: \(app.menuItems.allElementsBoundByIndex.map(\.label)) \(app.buttons.allElementsBoundByIndex.prefix(12).map(\.label))"); app.tap(); continue }
                sleep(2)
                shot(app, mode, 22 + i, "send-add-\(kind.lowercased())")
                if i == 0 {
                    app.swipeUp(); sleep(1)
                    shot(app, mode, 24, "send-add-text-bottom")
                }
                cancelOrClose(app); discardIfAsked(app)
            }
            // Open the first existing send (view + edit) if any.
            let sendRow = app.descendants(matching: .any)["SendCell"].firstMatch
            if sendRow.waitForExistence(timeout: 3) {
                sendRow.tap(); sleep(2)
                shot(app, mode, 25, "send-view")
                let edit = app.buttons["Edit"].firstMatch
                if edit.exists { edit.tap(); sleep(2); shot(app, mode, 26, "send-edit"); cancelOrClose(app); discardIfAsked(app) }
                cancelOrClose(app)
            }
            // Password history from the generator.
            app.terminate()
            let app2 = launchApp(); ensureUnlockedVault(app2)
            goTo(app2, "Generator"); sleep(2)
            let options = app2.buttons["HeaderBarOptionsButton"].exists ? app2.buttons["HeaderBarOptionsButton"] : app2.buttons["Options"]
            if options.waitForExistence(timeout: 5) {
                options.tap(); sleep(1)
                let hist = app2.buttons["Password history"]
                if hist.waitForExistence(timeout: 3) {
                    hist.tap(); sleep(2)
                    shot(app2, mode, 30, "password-history")
                }
            }
            app2.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Vault home (category tiles) in both appearances and with larger text.
    func test_tiles() {
        for (mode, size) in [("light", ""), ("dark", ""), ("light", "UICTContentSizeCategoryXL"), ("light", "UICTContentSizeCategoryAccessibilityL")] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let extra = size.isEmpty ? [] : ["-UIPreferredContentSizeCategoryName", size]
            let app = launchApp(extraArguments: extra)
            ensureUnlockedVault(app)
            XCTAssertTrue(app.buttons["CategoryTile_totp"].waitForExistence(timeout: 10))
            shot(app, mode, size.isEmpty ? 70 : (size.contains("Accessibility") ? 72 : 71), size.isEmpty ? "tiles" : (size.contains("Accessibility") ? "tiles-accessibility" : "tiles-xl"))
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// iPad: vault, item view/edit, send, settings (run with an iPad destination).
    func test_ipad() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            sleep(2)
            shot(app, mode, 80, "ipad-vault")
            let tile = app.buttons["CategoryTile_login"]
            if tile.waitForExistence(timeout: 5) {
                tile.tap(); sleep(2)
                shot(app, mode, 81, "ipad-item-list")
                let row = app.buttons["VaultListItemRowButton"].firstMatch
                if row.waitForExistence(timeout: 5) {
                    row.tap(); sleep(2)
                    shot(app, mode, 82, "ipad-item-view")
                    let edit = app.buttons["Edit"].firstMatch
                    if edit.exists { edit.tap(); sleep(2); shot(app, mode, 83, "ipad-item-edit"); cancelOrClose(app); discardIfAsked(app) }
                    cancelOrClose(app)
                }
                let back = app.navigationBars.buttons.firstMatch
                if back.waitForExistence(timeout: 5) { back.tap(); sleep(1) }
            }
            goTo(app, "Send"); sleep(2)
            shot(app, mode, 84, "ipad-send")
            goTo(app, "Settings"); sleep(2)
            shot(app, mode, 85, "ipad-settings")
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Settings pages with the "set up" sections (autofill "Turn on now", account security, vault settings).
    func test_setupSections() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
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
        XCUIDevice.shared.appearance = .light
    }

    /// Rare auth screens reachable from the login page (needs a fresh install): password hint, login with device, SSO.
    func test_a_auth() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
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
        XCUIDevice.shared.appearance = .light
    }
}
