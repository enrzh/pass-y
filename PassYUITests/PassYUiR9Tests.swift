import XCTest

/// ui-r9: the complete design rework. Avatar menu (server URL, pending login requests, no Vault entry and no account
/// entries), Add account in Settings, no web vault links, the item opens without a spinner, the Vault button follows
/// pushes and pops without a timer, content scrolls under the bar. Needs the throwaway Vaultwarden with
/// `seed_account.py` and `seed_ciphers.py 25`. Attachment names: `<PASSY_SHOT_TAG>-<nn>-<screen>`.
final class PassYUiR9Tests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "r9" }

    private func shot(_ app: XCUIApplication, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(String(format: "%02d", n))-\(name)")
    }

    private func containing(_ app: XCUIApplication, _ text: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", text, text))
    }

    /// The avatar menu: Send, Generator, Settings, pending login requests, sync; the server URL on top; no Vault, no
    /// account entries, no Add account, no "Pass-Y".
    func test01_avatarMenu() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["CurrentActiveAccount"].tap(); sleep(1)
        for label in ["Send", "Generator", "Settings"] {
            XCTAssertTrue(avatarMenuEntry(app, label).exists, "menu entry \(label)")
        }
        XCTAssertTrue(menuButton(app, id: "ProfileMenuPendingRequestsButton", label: "Pending login requests").exists, "pending login requests in the menu")
        XCTAssertTrue(menuButton(app, id: "ProfileMenuSyncButton", label: "Sync now").exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label == %@", "My vault")).firstMatch.exists, "ui-r9: no Vault entry in the avatar menu (on the vault home the bar has no Vault button either)")
        XCTAssertFalse(app.buttons["ProfileMenuVaultButton"].exists, "no Vault entry")
        XCTAssertFalse(app.buttons["Add account"].exists, "no Add account in the menu")
        XCTAssertFalse(containing(app, "passy-test@example.test").allElementsBoundByIndex.contains { $0.elementType == .button },
                       "no signed-in account entry in the menu")
        XCTAssertGreaterThan(containing(app, "localhost").count, 0, "the connected server URL is shown")
        XCTAssertFalse(app.staticTexts["Pass-Y"].exists)
        shot(app, 1, "avatar-menu")
    }

    /// Pending login requests opens from the menu.
    func test02_pendingRequestsFromMenu() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["CurrentActiveAccount"].tap(); sleep(1)
        menuButton(app, id: "ProfileMenuPendingRequestsButton", label: "Pending login requests").tap()
        XCTAssertTrue(app.staticTexts["No pending requests"].waitForExistence(timeout: 15)
                      || app.navigationBars.buttons["Close"].waitForExistence(timeout: 5), "pending requests sheet")
        shot(app, 2, "pending-requests")
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        if close.exists { close.firstMatch.tap() }
    }

    /// Settings: the account row shows the server (not "Pass-Y") and its menu offers Add account; no watch option, no
    /// web vault links anywhere in Settings.
    func test03_settingsAccountRowAndNoWebVaultNoWatch() {
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

    /// An item opens without a spinner: right after the sheet is there, the toolbar already has the favorite button
    /// (it only exists once the item is loaded) and no activity indicator is shown.
    func test04_itemOpensWithoutSpinner() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["CategoryTile_login"].tap()
        let row = app.buttons["VaultListItemRowButton"].firstMatch
        XCTAssertTrue(waitFor(row))
        row.tap()
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["FavoriteToolbarButton"].exists, "the item is loaded in the first frame (favorite button present)")
        XCTAssertEqual(app.activityIndicators.count, 0, "no spinner while opening an item")
        shot(app, 6, "item")
    }

    /// A list page shows no spinner after opening: rows are there when the page is, the Vault button appears with the
    /// push and goes away with the pop (event driven, no timer).
    func test05_listNoSpinner_vaultButtonFollowsStack() {
        let app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertFalse(app.buttons["BottomBarVaultButton"].exists, "no Vault button on the vault home")
        app.buttons["CategoryTile_login"].tap()
        XCTAssertTrue(app.buttons["BottomBarVaultButton"].waitForExistence(timeout: 2), "Vault button appears with the push")
        XCTAssertTrue(waitFor(app.buttons["VaultListItemRowButton"].firstMatch, timeout: 10))
        XCTAssertEqual(app.activityIndicators.count, 0, "no spinner on the list page")
        shot(app, 7, "list")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(waitForDisappearance(of: app.buttons["BottomBarVaultButton"], timeout: 3), "Vault button goes away with the pop")
    }

    /// Content scrolls under the bars (soft fades, no solid strip or block); screenshots show the result.
    func test06_contentScrollsUnderBars() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["CategoryTile_login"].tap()
        XCTAssertTrue(waitFor(app.buttons["VaultListItemRowButton"].firstMatch))
        app.swipeUp(); sleep(1)
        shot(app, 8, "list-scrolled")
        // A row under the bar is still tappable above it: the fades never take touches.
        let rows = app.buttons.matching(identifier: "VaultListItemRowButton").allElementsBoundByIndex
        XCTAssertTrue(rows.contains { $0.isHittable }, "rows are tappable while the fades are there")
    }

    private func closeSheet(_ app: XCUIApplication) {
        for id in ["CancelButton", "CloseButton", "Close", "Cancel"] {
            let b = app.buttons[id].firstMatch
            if b.exists, b.isHittable { b.tap(); sleep(1); break }
        }
        let discard = app.buttons["Cancel"].firstMatch
        if discard.waitForExistence(timeout: 1) { discard.tap() }
    }

    /// Idle: the "+" menu opens, leads to the add sheet and closes 12 times per text size (normal, accessibility L, accessibility XXXL) and every round is quick. A menu whose
    /// glass animation never reports its end makes XCUITest wait 60 s per action ("App animations complete
    /// notification not received"); one such round fails this test.
    func test07_addMenuOpenCloseLoop() {
        var slowest = 0.0
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", size])
            ensureUnlockedVault(app)
            let plus = app.buttons["AddItemFloatingActionButton"]
            XCTAssertTrue(plus.waitForExistence(timeout: 20))
            for round in 1 ... 12 {
                let start = Date()
                plus.tap()
                let entry = menuButton(app, id: "none", label: "Login")
                XCTAssertTrue(entry.waitForExistence(timeout: 10), "\(size) round \(round): the add menu opens")
                // Open the add sheet through the menu and close it again (the path of the real tests).
                entry.tap()
                XCTAssertTrue(app.textFields["ItemNameEntry"].waitForExistence(timeout: 15), "\(size) round \(round): the add sheet opens")
                closeSheet(app)
                XCTAssertTrue(plus.waitForExistence(timeout: 15), "\(size) round \(round): back on the vault")
                let took = Date().timeIntervalSince(start)
                slowest = max(slowest, took)
                XCTAssertLessThan(took, 40, "\(size) round \(round) took \(took) s (idle stall)")
            }
            app.terminate()
        }
        print("ADDMENU-LOOP slowest round \(slowest)")
    }
}
