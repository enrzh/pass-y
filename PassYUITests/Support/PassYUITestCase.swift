import XCTest

/// Base class of every Pass-Y UI test: stops a test at its first failure and holds the helpers shared by the
/// feature classes (moved from the former per-round classes).
class PassYUITestCase: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Prefix of attachment names (`PASSY_SHOT_TAG`, default `passy`).
    var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "passy" }

    /// Switches the top-level screen with the tab bar (before) or the avatar menu (after).
    func open(_ app: XCUIApplication, _ label: String) {
        let bar = app.tabBars.buttons[label]
        if bar.exists { bar.tap(); return }
        let avatar = app.buttons["CurrentActiveAccount"]
        if avatar.waitForExistence(timeout: 10) { avatar.tap() }
        let item = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if item.waitForExistence(timeout: 5) { item.tap() }
    }

    func shot(_ app: XCUIApplication, _ mode: String, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(mode)-\(String(format: "%02d", n))-\(name)")
    }

    func back(_ app: XCUIApplication) {
        let b = app.navigationBars.buttons.firstMatch
        if b.exists { b.tap() }
        sleep(1)
    }

    func dump(_ app: XCUIApplication, _ why: String) {
        print("DUMP[\(why)]:\n" + app.debugDescription)
    }

    /// Opens the item options menu on the view-item screen and deletes the item.
    func deleteCurrentItem(_ app: XCUIApplication) {
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
        // State driven instead of a fixed 3 s: the item sheet closes after the delete went through.
        _ = waitUntil(20) { !app.buttons["CipherOptionsButton"].exists && !app.alerts.firstMatch.exists }
        usleep(500_000)
    }

    /// Opens the seeded "GitHub" login through the bottom search bar and returns once the item sheet is up.
    func openGitHubViaSearch(_ app: XCUIApplication) {
        focusSearch(app)
        for ch in "GitHub" { app.typeText(String(ch)); usleep(150_000) }
        let hit = app.staticTexts["GitHub"].firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 20), "search finds GitHub")
        hit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["LoginUsernameEntry"].waitForExistence(timeout: 10), "item view is open")
    }

    func report(_ name: String, _ values: [Double]) {
        let sorted = values.sorted()
        print("PERF \(name) median=\(String(format: "%.2f", sorted[sorted.count / 2])) all=\(values.map { String(format: "%.2f", $0) })")
    }

    /// Whole-screen shot (system menus are not part of the app screenshot).
    func screenShot(_ mode: String, _ n: Int, _ name: String) {
        sleep(1)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "\(tag)-\(mode)-\(String(format: "%02d", n))-\(name)"
        a.lifetime = .keepAlways
        add(a)
    }

    func cancelOrClose(_ app: XCUIApplication) {
        for id in ["CancelButton", "CloseButton", "Close", "Cancel"] {
            let b = app.buttons[id].firstMatch
            if b.exists, b.isHittable { b.tap(); sleep(1); return }
        }
    }

    func discardIfAsked(_ app: XCUIApplication) {
        let c = app.buttons["Cancel"].firstMatch
        if c.waitForExistence(timeout: 1) { c.tap() }
    }

    func shot(_ app: XCUIApplication, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(String(format: "%02d", n))-\(name)")
    }

    /// Whole-screen shot (the app screenshot of a rotated iPad simulator is cropped and turned by 90 degrees).
    func screenShot(_ n: Int, _ name: String) {
        sleep(2)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "\(tag)-\(String(format: "%02d", n))-\(name)"
        a.lifetime = .keepAlways
        add(a)
    }

    func closeSheet(_ app: XCUIApplication) {
        for id in ["CancelButton", "CloseButton", "Close", "Cancel"] {
            let b = app.buttons[id].firstMatch
            if b.exists, b.isHittable { b.tap(); sleep(1); break }
        }
        let discard = app.buttons["Cancel"].firstMatch
        if discard.waitForExistence(timeout: 1) { discard.tap() }
    }

    func openAdd(_ app: XCUIApplication, _ type: String) -> Bool {
        let fab = app.buttons["AddItemFloatingActionButton"]
        guard fab.waitForExistence(timeout: 8) else { return false }
        fab.tap(); sleep(1)
        let item = app.menuItems.matching(NSPredicate(format: "label BEGINSWITH %@", type)).firstMatch
        let btn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT (identifier BEGINSWITH 'CategoryTile')", type)).firstMatch
        if item.waitForExistence(timeout: 3) { item.tap() } else if btn.waitForExistence(timeout: 2) { btn.tap() } else { app.tap(); return false }
        sleep(2)
        return true
    }

    func openLoginList(_ app: XCUIApplication) {
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap(); sleep(2)
        XCTAssertTrue(app.buttons["VaultListItemRowButton"].firstMatch.waitForExistence(timeout: 8))
    }

    // MARK: Auth pages in the running app (step 6)
    func leaveScreen(_ app: XCUIApplication) {
        for id in ["CancelButton", "CloseButton", "Close", "Cancel", "Back"] {
            let b = app.buttons[id].firstMatch
            if b.exists, b.isHittable { b.tap(); sleep(2); return }
        }
        let nav = app.navigationBars.buttons.firstMatch
        if nav.exists, nav.isHittable { nav.tap(); sleep(2) }
    }

    /// Types a whole password into the login form: the authenticator key is shown first (with two masked fields
    /// XCUITest `typeText` keeps only the last character, see `revealAuthenticatorKey`), the eye is switched on, the
    /// text is typed into the plain field and the eye is switched off again. No product behaviour is changed.
    func typePassword(_ app: XCUIApplication, _ password: String) {
        revealAuthenticatorKey(app)
        let eye = app.buttons["ViewPasswordButton"].firstMatch
        XCTAssertTrue(eye.waitForExistence(timeout: 8))
        eye.tap(); sleep(1)
        let plain = app.textFields["LoginPasswordEntry"]
        XCTAssertTrue(plain.waitForExistence(timeout: 8), "password shown as a plain field")
        plain.tap()
        plain.typeText(password)
        eye.tap(); sleep(1)
    }

    func line(_ name: String, _ values: [Double], extra: String = "") {
        let sorted = values.sorted()
        let median = sorted.isEmpty ? -1 : sorted[sorted.count / 2]
        print("R8CMP \(name) n=\(values.count) median=\(String(format: "%.2f", median)) all=\(values.map { String(format: "%.2f", $0) }) \(extra)")
    }

    /// Taps `element` at a point in its blank part (right of the text, left of the chevron).
    func tapBlank(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)).tap()
    }

    /// The bottom-bar Vault button (not on the vault home).
    func vaultButton(_ app: XCUIApplication) -> XCUIElement { app.buttons["BottomBarVaultButton"] }

    /// Waits at most `timeout` seconds for the element and reports how long it took.
    func appears(_ element: XCUIElement, within timeout: TimeInterval = 1.0) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Scrolls until the folder row is hittable and lies fully above the bottom bar (a row that merely exists in the
    /// tree may sit under the bar or outside the screen). Returns whether it is in a tappable position.
    func scrollToFolder(_ app: XCUIApplication, _ name: String) -> Bool {
        let predicate = NSPredicate(format: "identifier == 'VaultListItemRowButton' AND label CONTAINS %@", name)
        let search = app.searchFields.firstMatch
        func tappable() -> Bool {
            let row = app.buttons.matching(predicate).firstMatch
            return row.exists && row.isHittable && row.frame.maxY <= search.frame.minY - 4
        }
        for _ in 0 ..< 8 {
            if tappable() { return true }
            app.swipeUp()
        }
        for _ in 0 ..< 8 {
            if tappable() { return true }
            app.swipeDown()
        }
        return tappable()
    }

    func createFolder(_ app: XCUIApplication, _ name: String) {
        app.buttons["AddItemFloatingActionButton"].tap()
        let entry = app.menuItems["Folder"].exists ? app.menuItems["Folder"] : app.buttons["Folder"]
        XCTAssertTrue(entry.waitForExistence(timeout: 4))
        entry.tap()
        let field = app.textFields["FolderNameField"].exists ? app.textFields["FolderNameField"] : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.replaceText(name)
        app.buttons["SaveButton"].firstMatch.tap()
        _ = waitFor(app.buttons["AddItemFloatingActionButton"])
        sleep(2)
    }

    func containing(_ app: XCUIApplication, _ text: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", text, text))
    }

    func walkScreens(_ app: XCUIApplication, prefix: String) {
        ensureUnlockedVault(app)
        attach(app, "\(prefix)-vault")
        goTo(app, "Generator"); sleep(1)
        attach(app, "\(prefix)-generator")
        goTo(app, "Send"); sleep(1)
        attach(app, "\(prefix)-send")
        goTo(app, "Settings"); sleep(1)
        attach(app, "\(prefix)-settings")
        goTo(app, "My vault")
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        XCTAssertTrue(waitFor(app.textFields["ItemNameEntry"]))
        attach(app, "\(prefix)-add-login")
        app.buttons["CancelButton"].firstMatch.tap()
    }
}
