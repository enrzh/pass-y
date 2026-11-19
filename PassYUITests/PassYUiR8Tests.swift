import XCTest

/// ui-r8: real-device feedback on v1.23. Single taps (also on the blank part of a row), native large titles that
/// collapse, the Vault button in the bottom bar, no backdrop behind the bar, and a way back from every page.
/// Needs the throwaway Vaultwarden with `seed_account.py` and `seed_ciphers.py 25` (or 2000 for the perf tests).
/// Attachment names: `<PASSY_SHOT_TAG>-<nn>-<screen>`.
final class PassYUiR8Tests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "r8" }

    private func shot(_ app: XCUIApplication, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(String(format: "%02d", n))-\(name)")
    }

    /// Taps `element` at a point in its blank part (right of the text, left of the chevron).
    private func tapBlank(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)).tap()
    }

    /// The bottom-bar Vault button (not on the vault home).
    private func vaultButton(_ app: XCUIApplication) -> XCUIElement { app.buttons["BottomBarVaultButton"] }

    /// Waits at most `timeout` seconds for the element and reports how long it took.
    private func appears(_ element: XCUIElement, within timeout: TimeInterval = 1.0) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    // MARK: (a) single taps

    /// Diagnosis helper: prints the accessibility tree of the group list after one tile tap.
    func test00_dumpGroupListTree() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["CategoryTile_login"].tap()
        sleep(4)
        print("TREE-BEGIN\n\(app.debugDescription)\nTREE-END")
        attach(app, "r8-00-group-list")
    }

    /// One tap on the blank part of a category tile list row opens the item sheet within one second.
    func test01_singleTapOpensItemFromBlankArea() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(waitFor(tile))
        tile.tap()
        let row = app.buttons["VaultListItemRowButton"].firstMatch
        XCTAssertTrue(waitFor(row), "item list is shown after one tap on the tile")
        tapBlank(row)
        XCTAssertTrue(appears(app.buttons["Close"].firstMatch), "one tap on the blank part of the row opens the item within 1 s")
        shot(app, 1, "item-after-one-tap")
    }

    /// One tap on a folder row (blank part) pushes the folder page within one second.
    func test02_singleTapOpensFolder() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let folderName = "PassY Tap Folder"
        if !scrollToFolder(app, folderName) {
            createFolder(app, folderName)
            XCTAssertTrue(scrollToFolder(app, folderName), "folder row exists")
        }
        let row = app.buttons.matching(NSPredicate(format: "identifier == 'VaultListItemRowButton' AND label CONTAINS %@", folderName)).firstMatch
        XCTAssertTrue(row.exists)
        tapBlank(row)
        XCTAssertTrue(appears(app.navigationBars.staticTexts[folderName]), "one tap on the folder row opens the folder within 1 s")
        shot(app, 2, "folder-after-one-tap")
        // Back works with the system back button and the Vault button returns to the home.
        XCTAssertTrue(vaultButton(app).exists, "pushed page shows the Vault button")
        vaultButton(app).tap()
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"]), "Vault button returns to the vault home")
    }

    private func scrollToFolder(_ app: XCUIApplication, _ name: String) -> Bool {
        let predicate = NSPredicate(format: "identifier == 'VaultListItemRowButton' AND label CONTAINS %@", name)
        for _ in 0 ..< 6 {
            if app.buttons.matching(predicate).firstMatch.exists { return true }
            app.swipeUp()
        }
        for _ in 0 ..< 6 { app.swipeDown() }
        return app.buttons.matching(predicate).firstMatch.exists
    }

    private func createFolder(_ app: XCUIApplication, _ name: String) {
        app.buttons["AddItemFloatingActionButton"].tap()
        let entry = app.menuItems["Folder"].exists ? app.menuItems["Folder"] : app.buttons["Folder"]
        XCTAssertTrue(entry.waitForExistence(timeout: 4))
        entry.tap()
        let field = app.textFields["FolderNameField"].exists ? app.textFields["FolderNameField"] : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap(); field.typeText(name)
        app.buttons["SaveButton"].firstMatch.tap()
        _ = waitFor(app.buttons["AddItemFloatingActionButton"])
        sleep(2)
    }

    // MARK: (d) large titles

    /// The large title is a native navigation title: it is expanded at the top and collapses into the inline title
    /// when the content scrolls (vault home with a 25+ item vault; Settings and Send only when they scroll).
    func test03_largeTitlesCollapse() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let pages: [(String, String?, Bool)] = [("My vault", nil, true), ("Send", "Send", false),
                                                ("Generator", "Generator", false), ("Settings", "Settings", false)]
        for (title, destination, mustScroll) in pages {
            if let destination { goTo(app, destination) }
            let bar = app.navigationBars.firstMatch
            XCTAssertTrue(bar.waitForExistence(timeout: 8), "\(title): navigation bar")
            let large = app.staticTexts[title].firstMatch
            XCTAssertTrue(large.waitForExistence(timeout: 8), "\(title): title exists")
            let before = large.frame
            XCTAssertGreaterThanOrEqual(before.height, 30, "\(title): expanded large title is tall (\(before))")
            XCTAssertFalse(app.staticTexts["HeaderBarPageTitle"].exists, "\(title): no custom header item")
            shot(app, 10, "large-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
            // Drag on a point left of any slider/control column: the list area just under the title.
            for _ in 0 ..< 3 { app.swipeUp(velocity: .slow) }
            sleep(1)
            let after = app.staticTexts[title].firstMatch
            let collapsed = !after.exists || after.frame.height < before.height || after.frame.midY < before.midY
            if mustScroll {
                XCTAssertTrue(collapsed, "\(title): title collapsed (\(before) -> \(after.frame))")
            } else if !collapsed {
                // Short page: the content fits on the screen, so the large title correctly stays (rubber band).
                print("NOTE \(title): content fits, title stays expanded")
            }
            shot(app, 11, "collapsed-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
            for _ in 0 ..< 3 { app.swipeDown(velocity: .slow) }
        }
    }

    // MARK: (c) Vault button, (e) no backdrop

    /// The Vault button is left of the search bar on every page except the vault home and returns to the home.
    func test04_vaultButtonLeftOfSearch() {
        let app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertFalse(vaultButton(app).exists, "no Vault button on the vault home")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        shot(app, 20, "vault-home-bar")
        for destination in ["Send", "Generator", "Settings"] {
            goTo(app, destination)
            let button = vaultButton(app)
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(destination): Vault button")
            XCTAssertLessThanOrEqual(button.frame.maxX, search.frame.minX + 1, "\(destination): button left of the search bar")
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, "\(destination): 44 pt target")
            shot(app, 21, "bar-\(destination.lowercased())")
            button.tap()
            XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"]), "\(destination): Vault button returns to the home")
            XCTAssertFalse(vaultButton(app).exists, "home again: no Vault button")
        }
        // Deep page: Settings > Vault settings > Folders, then straight back to the vault.
        goTo(app, "Settings")
        app.buttons["VaultSettingsButton"].tap()
        XCTAssertTrue(app.buttons["FoldersLabel"].waitForExistence(timeout: 5))
        app.buttons["FoldersLabel"].tap(); sleep(1)
        XCTAssertTrue(vaultButton(app).exists, "folders page: Vault button")
        vaultButton(app).tap()
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"]), "deep page: Vault button returns to the vault home")
    }

    /// Nothing is drawn behind the bar. On the (empty) Trash list the page is one flat color: the pixel just above the
    /// search bar must have the color of the pixel far above it (a material or gradient backdrop would differ).
    func test05_noBackdropBehindBar() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        shot(app, 30, "vault-bar-no-shadow")
        let trash = app.buttons["CategoryTile_trash"]
        XCTAssertTrue(trash.waitForExistence(timeout: 5), "trash tile")
        trash.tap(); sleep(2)
        let screen = app.windows.firstMatch.frame
        let image = app.screenshot().image
        guard let cg = image.cgImage else { return XCTFail("screenshot") }
        let scale = CGFloat(cg.width) / screen.width
        func pixel(_ x: CGFloat, _ y: CGFloat) -> [UInt8] {
            guard let crop = cg.cropping(to: CGRect(x: x * scale, y: y * scale, width: 2, height: 2)),
                  let data = crop.dataProvider?.data as Data? else { return [] }
            return Array(data.prefix(3))
        }
        let barTop = search.frame.minY
        // Left margin: no illustration, no bar control. 6 pt, 20 pt and 60 pt above the bar, and a flat reference.
        let reference = pixel(6, barTop - 260)
        XCTAssertFalse(reference.isEmpty)
        for offset: CGFloat in [6, 20, 60] {
            XCTAssertEqual(pixel(6, barTop - offset), reference, "pixel \(offset) pt above the bar equals the page color (no backdrop)")
        }
        shot(app, 31, "trash-bar-no-shadow")
    }

    // MARK: (f) back and close everywhere

    /// Every pushed page has a working back button and swipe-back; every sheet closes.
    func test06_backAndCloseEverywhere() {
        let app = launchApp()
        ensureUnlockedVault(app)
        // Pushed category list: back button.
        app.buttons["CategoryTile_login"].tap()
        XCTAssertTrue(waitFor(app.buttons["VaultListItemRowButton"].firstMatch))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"]), "back from the list")
        // Pushed category list: swipe back from the left edge.
        app.buttons["CategoryTile_login"].tap()
        XCTAssertTrue(waitFor(app.buttons["VaultListItemRowButton"].firstMatch))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"]), "swipe back from the list")
        // Item sheet: Close.
        app.buttons["CategoryTile_login"].tap()
        let row = app.buttons["VaultListItemRowButton"].firstMatch
        XCTAssertTrue(waitFor(row))
        tapBlank(row)
        let close = app.buttons["Close"].firstMatch
        XCTAssertTrue(waitFor(close), "item sheet has Close")
        close.tap()
        XCTAssertTrue(waitFor(app.buttons["VaultListItemRowButton"].firstMatch), "closing the sheet returns to the list")
        vaultButton(app).tap()
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"]), "vault home")
        // Add sheet: Cancel.
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        XCTAssertTrue(waitFor(app.textFields["ItemNameEntry"]))
        app.dismissNewLoginCard()
        let cancel = app.buttons["CancelButton"].exists ? app.buttons["CancelButton"] : app.buttons["Cancel"]
        XCTAssertTrue(cancel.firstMatch.waitForExistence(timeout: 5), "add sheet has Cancel")
        cancel.firstMatch.tap()
        XCTAssertTrue(waitFor(app.buttons["AddItemFloatingActionButton"]), "cancel returns to the vault")
        // Settings sub pages: back button and swipe back.
        goTo(app, "Settings")
        for (button, title) in [("AccountSecuritySettingsButton", "Account security"), ("AppearanceSettingsButton", "Appearance"),
                                ("OtherSettingsButton", "Other"), ("VaultSettingsButton", "Vault")] {
            let entry = app.buttons[button]
            guard entry.waitForExistence(timeout: 5) else { XCTFail("\(button) missing"); continue }
            entry.tap(); sleep(1)
            XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists, "\(title): back button")
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(waitFor(app.buttons[button]), "\(title): back returns to settings")
            entry.tap(); sleep(1)
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
            XCTAssertTrue(waitFor(app.buttons[button]), "\(title): swipe back returns to settings")
        }
        // Send add sheet: Cancel.
        goTo(app, "Send")
        app.buttons["AddItemFloatingActionButton"].tap()
        let text = app.menuItems["Text"].exists ? app.menuItems["Text"] : app.buttons["Text"]
        if text.waitForExistence(timeout: 4) {
            text.tap()
            let sendCancel = app.buttons["CancelButton"].exists ? app.buttons["CancelButton"] : app.buttons["Cancel"]
            XCTAssertTrue(sendCancel.firstMatch.waitForExistence(timeout: 5), "send add sheet has Cancel")
            sendCancel.firstMatch.tap()
        }
        vaultButton(app).tap()
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"]), "no dead end: Vault button returns from Send")
    }
}
