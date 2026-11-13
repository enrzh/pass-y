import XCTest

/// End-to-end UI tests against a throwaway local Vaultwarden (see README). Tests run in name order and share
/// the simulator's app state; run them on a freshly installed app.
final class PassYFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func dump(_ app: XCUIApplication, _ why: String) {
        print("DUMP[\(why)]:\n" + app.debugDescription)
    }

    /// Opens the item options menu on the view-item screen and deletes the item.
    private func deleteCurrentItem(_ app: XCUIApplication) {
        _ = app.buttons["CipherOptionsButton"].firstMatch.waitForExistence(timeout: 5)
        // Several "options" buttons can exist (list rows behind the sheet); use the first hittable one.
        let all = app.buttons.matching(NSPredicate(format: "identifier == 'CipherOptionsButton' OR label == 'Options'"))
        guard let opts = all.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            dump(app, "no options button"); return XCTFail("no hittable item options button")
        }
        opts.tap()
        let delete = app.buttons["Delete item"].exists ? app.buttons["Delete item"] : app.buttons["Delete"]
        guard waitFor(delete, timeout: 5) else { dump(app, "no delete"); return XCTFail("no delete action") }
        delete.tap()
        let confirm = app.alerts.buttons["Yes"].exists ? app.alerts.buttons["Yes"] : app.alerts.buttons.element(boundBy: 1)
        XCTAssertTrue(waitFor(confirm, timeout: 5))
        confirm.tap()
        sleep(3)
    }

    private func tabBarButton(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.tabBars.buttons[label]
    }

    // MARK: 01 Landing: server first, no cloud preset

    func test01_landingAsksForServerAndHasNoCloudPreset() {
        let app = launchApp()
        let logIn = app.buttons["Log in"]
        XCTAssertTrue(waitFor(logIn), "intro screen shows 'Log in'")
        logIn.tap()
        // The server settings are presented automatically on first launch.
        XCTAssertTrue(waitFor(app.textFields["ServerUrlEntry"]), "server settings appear automatically")
        let preset = app.textFields["ServerUrlEntry"].value as? String ?? ""
        XCTAssertTrue(preset.isEmpty || preset == "Server URL", "no preset server URL, got \(preset)")
        attach(app, "01-server-settings")
        let all = app.debugDescription
        XCTAssertFalse(all.contains("bitwarden.com"), "no Bitwarden cloud host visible")
        XCTAssertFalse(all.contains("bitwarden.eu"), "no Bitwarden EU host visible")
        app.buttons["CancelButton"].firstMatch.tap()
        XCTAssertTrue(waitFor(app.buttons["RegionSelectorDropdown"]))
        XCTAssertTrue(app.buttons["RegionSelectorDropdown"].label.contains("Not set"))
        XCTAssertFalse(app.buttons["ContinueButton"].isEnabled, "continue disabled without email")
        attach(app, "01-landing-no-server")
    }

    // MARK: 02 Login + sync

    func test02_loginAndSync() {
        let app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertTrue(app.staticTexts["My vault"].exists)
        attach(app, "02-vault")
    }

    // MARK: 03 Create, search, edit, delete

    func test03_createSearchEditDelete() {
        let itemName = "PassY UITest \(Int.random(in: 1000 ... 9999))"
        let app = launchApp()
        ensureUnlockedVault(app)

        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        let name = app.textFields["ItemNameEntry"]
        XCTAssertTrue(waitFor(name))
        app.dismissNewLoginCard()
        name.tap(); name.typeText(itemName)
        let user = app.textFields["LoginUsernameEntry"]
        user.tap(); user.typeText("tester@example.test")
        let pw = app.secureTextFields["LoginPasswordEntry"]
        pw.tap(); pw.typeText("Sup3r-Secret-Pass")
        attach(app, "03-add-login")
        app.buttons["SaveButton"].firstMatch.tap()

        XCTAssertTrue(waitFor(app.staticTexts["\(itemName)"]), "saved item is shown")
        attach(app, "03-item-after-save")
        // After saving, the item view sheet is shown; close it to get back to the list.
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        XCTAssertTrue(waitFor(close, timeout: 5))
        close.firstMatch.tap()
        // The vault list is a LazyVStack sorted by name, so a new "PassY UITest ..." row is usually below the fold and
        // not part of the accessibility tree until scrolled to; the search step below is the reliable lookup.
        XCTAssertTrue(waitFor(app.buttons["AddItemFloatingActionButton"]), "back on the vault list")
        attach(app, "03-vault-with-item")

        // Search
        let search = app.searchFields.firstMatch
        search.tap(); sleep(2)
        // Type slowly: with a 2000-item vault the main thread is busy after each keystroke and fast typing drops characters.
        for ch in itemName { app.typeText(String(ch)); usleep(150_000) }
        attach(app, "03-search")
        let hit = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", itemName)).firstMatch
        XCTAssertTrue(waitFor(hit), "search finds the item (search field value: \(search.value as? String ?? "nil"))")

        // Open (straight from the search results; the bottom search bar keeps the results visible) + edit
        app.staticTexts[itemName].firstMatch.tap()
        XCTAssertTrue(waitFor(app.buttons["CipherOptionsButton"].exists ? app.buttons["CipherOptionsButton"] : app.buttons["Options"]))
        attach(app, "03-view-item")
        let edit = app.buttons["EditItemFloatingActionButton"]
        if edit.waitForExistence(timeout: 5) { edit.tap() } else {
            app.buttons["CipherOptionsButton"].tap(); app.buttons["Edit"].tap()
        }
        let editName = app.textFields["ItemNameEntry"]
        XCTAssertTrue(waitFor(editName))
        editName.tap()
        editName.typeText(" Edited")
        app.buttons["SaveButton"].firstMatch.tap()
        XCTAssertTrue(waitFor(app.staticTexts["\(itemName) Edited"]), "edit saved")
        attach(app, "03-edited")

        // Delete
        deleteCurrentItem(app)
        XCTAssertFalse(app.staticTexts["\(itemName) Edited"].exists, "item deleted from list")
        attach(app, "03-after-delete")
    }

    // MARK: 04 TOTP

    func test04_totpCodeShown() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        let name = app.textFields["ItemNameEntry"]
        XCTAssertTrue(waitFor(name))
        app.dismissNewLoginCard()
        name.tap(); name.typeText("PassY TOTP Item")
        let setup = app.buttons["SetupTotpButton"]
        if !setup.exists { app.swipeUp() }
        let totp = app.secureTextFields["LoginTotpEntry"].exists ? app.secureTextFields["LoginTotpEntry"] : app.textFields["LoginTotpEntry"]
        if !totp.waitForExistence(timeout: 3) {
            for _ in 0 ..< 4 where !totp.exists { app.swipeUp() }
        }
        if !totp.exists, setup.exists { setup.tap() }
        guard totp.waitForExistence(timeout: 10) else { dump(app, "totp"); return XCTFail("no TOTP field") }
        totp.tap(); totp.typeText("JBSWY3DPEHPK3PXP")
        attach(app, "04-add-totp")
        app.buttons["SaveButton"].firstMatch.tap()
        XCTAssertTrue(waitFor(app.staticTexts["PassY TOTP Item"]))
        app.staticTexts["PassY TOTP Item"].firstMatch.tap()
        let code = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{3} ?[0-9]{3}$")).firstMatch
        XCTAssertTrue(waitFor(code, timeout: 10), "view item shows a 6-digit TOTP code")
        attach(app, "04-totp-code")
        // Clean up
        deleteCurrentItem(app)
    }

    // MARK: 05 Generator

    /// The add (+) menu in the bottom bar opens and offers the item types and Folder (iPhone and iPad).
    func test08_addMenuOpensWithEntries() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let add = app.buttons["AddItemFloatingActionButton"]
        XCTAssertTrue(waitFor(add), "add button is on screen")
        XCTAssertGreaterThanOrEqual(add.frame.width, 40, "the add button exposes a full-size tap target (frame \(add.frame))")
        add.tap(); sleep(2)
        attach(app, "08-add-menu")
        for title in ["Login", "Card", "Identity", "Folder"] {
            let entry = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH 'CategoryTile')", title))
                .matching(NSPredicate(format: "elementType == %d OR elementType == %d", XCUIElement.ElementType.menuItem.rawValue, XCUIElement.ElementType.button.rawValue))
                .firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5), "menu entry \(title) exists\n\(app.debugDescription)")
        }
    }

    /// Searching and cancelling returns to the normal vault with the add button visible and the keyboard closed.
    func test09_searchCancelRestoresVault() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let search = app.searchFields.firstMatch
        search.tap(); sleep(3)
        for ch in "Perf" { app.typeText(String(ch)); usleep(150_000) }
        XCTAssertFalse(app.buttons["AddItemFloatingActionButton"].exists, "add button is hidden while searching")
        let cancel = app.otherElements["VaultSearchField"].buttons.firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "cancel button of the search bar")
        cancel.tap(); sleep(2)
        attach(app, "09-after-cancel")
        XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5), "add button is back after cancel")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "keyboard is closed after cancel")
    }

    /// Open a search result, close the item, cancel the search: the vault is back to normal.
    func test10_searchOpenCloseCancel() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let search = app.searchFields.firstMatch
        search.tap(); sleep(3)
        for ch in "GitHub" { app.typeText(String(ch)); usleep(150_000) }
        let hit = app.staticTexts["GitHub"].firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 20), "search finds GitHub")
        hit.tap()
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        XCTAssertTrue(close.firstMatch.waitForExistence(timeout: 10), "item sheet is open")
        close.firstMatch.tap(); sleep(2)
        attach(app, "10-after-item-close")
        let cancel = app.otherElements["VaultSearchField"].buttons.firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "search bar cancel is still there")
        cancel.tap(); sleep(2)
        attach(app, "10-after-cancel")
        XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5), "add button is back after cancel")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "keyboard is closed after cancel")
    }

    /// Search, open a result, close it, switch tabs and back, then cancel: the vault is back to normal in one tap.
    func test11_searchTabSwitchCancel() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let search = app.searchFields.firstMatch
        search.tap(); sleep(3)
        for ch in "GitHub" { app.typeText(String(ch)); usleep(150_000) }
        let hit = app.staticTexts["GitHub"].firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 20), "search finds GitHub")
        hit.tap()
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        XCTAssertTrue(close.firstMatch.waitForExistence(timeout: 10), "item sheet is open")
        close.firstMatch.tap(); sleep(2)
        tabBarButton(app, "Generator").tap(); sleep(1)
        tabBarButton(app, "My vault").tap(); sleep(2)
        XCTAssertFalse(app.keyboards.firstMatch.exists, "keyboard stays closed after returning to the vault tab")
        let cancel = app.otherElements["VaultSearchField"].buttons.firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "search bar cancel is still there")
        cancel.tap(); sleep(2)
        attach(app, "11-after-cancel")
        XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5), "add button is back after one cancel tap")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "keyboard is closed after cancel")
    }

    func test05_generator() {
        let app = launchApp()
        ensureUnlockedVault(app)
        tabBarButton(app, "Generator").tap()
        let label = app.staticTexts["GeneratedPasswordLabel"]
        XCTAssertTrue(waitFor(label), "generated password is shown")
        let first = label.label
        XCTAssertGreaterThanOrEqual(first.count, 8)
        attach(app, "05-generator")
        let regen = app.buttons["RegeneratePasswordButton"].exists ? app.buttons["RegeneratePasswordButton"] : app.buttons["Generate password"]
        if regen.exists {
            regen.tap(); sleep(1)
            XCTAssertNotEqual(app.staticTexts["GeneratedPasswordLabel"].label, first, "regenerate changes password")
        }
        tabBarButton(app, "My vault").tap()
    }

    // MARK: 06 Settings and no upsell

    func test06_settingsHasNoPremiumUpsell() {
        let app = launchApp()
        ensureUnlockedVault(app)
        tabBarButton(app, "Settings").tap()
        XCTAssertTrue(waitFor(app.buttons["AccountSecuritySettingsButton"]))
        attach(app, "06-settings")
        let all = app.allLabels.lowercased()
        XCTAssertFalse(all.contains("premium"), "no premium upsell in settings")
        XCTAssertFalse(all.contains("bitwarden"), "no Bitwarden branding in settings:\n\(all)")
        tabBarButton(app, "My vault").tap()
    }

    // MARK: 07 Lock and unlock

    func test07_lockAndUnlock() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.terminate()
        let app2 = launchApp()
        let unlockPw = app2.secureTextFields["MasterPasswordEntry"]
        XCTAssertTrue(waitFor(unlockPw), "vault is locked after restart")
        attach(app2, "07-locked")
        unlockPw.tap(); unlockPw.typeText("wrong-password")
        app2.buttons["UnlockVaultButton"].tap()
        XCTAssertTrue(waitFor(app2.alerts.firstMatch, timeout: 15), "wrong password is rejected")
        app2.alerts.buttons.firstMatch.tap()
        ensureUnlockedVault(app2)
        XCTAssertTrue(app2.staticTexts["My vault"].exists)
        attach(app2, "07-unlocked")
    }
}
