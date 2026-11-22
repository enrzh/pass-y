import XCTest

/// The shell: large titles, the bottom bar (search, Vault button), back and close everywhere, rows clear of the bar.
final class NavigationTests: PassYUITestCase {
    // MARK: (d) large titles
    /// The large title is a native navigation title: it is expanded at the top and collapses into the inline title
    /// when the content scrolls (vault home with a 25+ item vault; Settings and Send only when they scroll).
    /// Formerly `PassYUiR8Tests.test03_largeTitlesCollapse`.
    func test_largeTitlesCollapse() {
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
    /// Formerly `PassYUiR8Tests.test04_vaultButtonLeftOfSearch`.
    func test_vaultButtonLeftOfSearch() {
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

    // MARK: (f) back and close everywhere
    /// Every pushed page has a working back button and swipe-back; every sheet closes.
    /// Formerly `PassYUiR8Tests.test06_backAndCloseEverywhere`.
    func test_backAndCloseEverywhere() {
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

    /// The search field stays at the bottom of the screen on every page: root screens and pushed pages.
    /// Formerly `PassYFlowTests.test20_searchBarPersistentAtBottom`.
    func test_searchBarPersistentAtBottom() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let screen = app.windows.firstMatch.frame
        func assertBarAtBottom(_ page: String) {
            let fields = app.searchFields
            XCTAssertTrue(fields.firstMatch.waitForExistence(timeout: 10), "\(page): search field exists")
            XCTAssertEqual(fields.count, 1, "\(page): exactly one search field (single container)")
            let frame = fields.firstMatch.frame
            XCTAssertGreaterThan(frame.maxY, screen.height - 90, "\(page): search field at the bottom (maxY \(frame.maxY) of \(screen.height))")
            XCTAssertGreaterThan(frame.minY, screen.height * 0.8, "\(page): search field in the lower fifth")
            XCTAssertLessThanOrEqual(frame.height, 56, "\(page): single capsule height \(frame.height)")
        }
        assertBarAtBottom("vault")
        attach(app, "20-vault-bar")
        // Pushed page of the vault: a category list.
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "login tile")
        tile.tap(); sleep(2)
        assertBarAtBottom("item list")
        attach(app, "20-item-list-bar")
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        // Root screens.
        goTo(app, "Send"); sleep(1)
        assertBarAtBottom("send")
        goTo(app, "Generator"); sleep(1)
        assertBarAtBottom("generator")
        attach(app, "20-generator-bar")
        // Settings and pushed settings pages.
        goTo(app, "Settings"); sleep(1)
        assertBarAtBottom("settings")
        app.buttons["VaultSettingsButton"].tap(); sleep(2)
        assertBarAtBottom("vault settings")
        let folders = app.buttons["FoldersLabel"]
        XCTAssertTrue(folders.waitForExistence(timeout: 5))
        folders.tap(); sleep(2)
        assertBarAtBottom("folders")
        attach(app, "20-folders-bar")
        // Typing in the bar on a page that cannot search opens the vault search with results.
        focusSearch(app)
        for ch in "GitHub" { app.typeText(String(ch)); usleep(150_000) }
        XCTAssertTrue(app.staticTexts["GitHub"].firstMatch.waitForExistence(timeout: 20), "searching from a pushed settings page shows vault results")
        XCTAssertTrue(app.staticTexts["My vault"].waitForExistence(timeout: 5), "search routed to the vault")
        attach(app, "20-search-from-folders")
        let cancel = app.buttons["VaultSearchCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap(); sleep(1)
        assertBarAtBottom("vault after cancel")
    }

    /// The bottom search bar exists at the bottom on the vault, generator and send pages (screenshots show the
    /// uniform backdrop; the colour itself is not asserted).
    /// Formerly `PassYFlowTests.test23_barBackdropIsPageIndependent`.
    func test_barBackdropIsPageIndependent() {
        let app = launchApp()
        ensureUnlockedVault(app)
        for place in ["My vault", "Generator", "Send"] {
            goTo(app, place); sleep(1)
            let bar = app.searchFields.firstMatch
            XCTAssertTrue(bar.waitForExistence(timeout: 10), "\(place) has the bottom bar")
            XCTAssertGreaterThan(bar.frame.midY, app.windows.firstMatch.frame.height * 0.8, "\(place): bar at the bottom")
            attach(app, "23-bar-\(place)")
        }
    }

    /// Walks the main screens and asserts that no visible text contains a leaked Optional (`Optional("...")`), and that
    /// the last row of the vault search results and of the Send list can be scrolled clear of the bottom bar.
    /// Formerly `PassYFlowTests.test18_noOptionalTextAndLastRowsClearOfBar`.
    func test_noOptionalTextAndLastRowsClearOfBar() {
        let app = launchApp()
        ensureUnlockedVault(app)
        func assertNoOptional(_ screen: String) {
            let leaked = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS 'Optional(' OR value CONTAINS 'Optional('")).firstMatch
            XCTAssertFalse(leaked.exists, "\(screen): visible text contains Optional(...): \(leaked.exists ? leaked.label : "")")
        }
        assertNoOptional("vault")
        // Vault search results: last row above the bottom bar.
        focusSearch(app)
        for ch in "GitHub" { app.typeText(String(ch)); usleep(150_000) }
        XCTAssertTrue(app.staticTexts["GitHub"].firstMatch.waitForExistence(timeout: 20), "search finds GitHub")
        // The search key closes the keyboard so the bar sits at the bottom again.
        let searchKey = app.keyboards.buttons["Search"]
        XCTAssertTrue(searchKey.waitForExistence(timeout: 5), "keyboard has the Search key")
        searchKey.tap(); sleep(1)
        XCTAssertFalse(app.keyboards.firstMatch.exists, "keyboard closed after the search key")
        for _ in 0 ..< 5 { app.swipeUp() }
        sleep(1)
        let hits = app.staticTexts.matching(identifier: "GitHub")
        let lastHit = hits.element(boundBy: hits.count - 1)
        let bar = app.otherElements["VaultSearchField"]
        XCTAssertTrue(bar.exists, "search bar present")
        XCTAssertLessThanOrEqual(lastHit.frame.maxY, bar.frame.minY + 1, "vault: last result (\(lastHit.frame)) above the bar (\(bar.frame))")
        assertNoOptional("vault search")
        // The search bar cancel (X, label "Close"); the first button of the field could also be its clear-text button.
        let closeX = app.buttons["VaultSearchCancel"]
        XCTAssertTrue(closeX.waitForExistence(timeout: 5), "search bar cancel (X) exists")
        closeX.tap(); sleep(2)
        XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 5), "vault back to normal after the X")
        // Send list.
        goTo(app, "Send"); sleep(2)
        assertNoOptional("send")
        for _ in 0 ..< 4 { app.swipeUp() }
        sleep(1)
        let sends = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'PassY Send'"))
        if sends.count > 0 {
            let lastSend = sends.element(boundBy: sends.count - 1)
            let sendBar = app.otherElements["VaultSearchField"]
            XCTAssertLessThanOrEqual(lastSend.frame.maxY, sendBar.frame.minY + 1, "send: last row (\(lastSend.frame)) above the bar (\(sendBar.frame))")
        }
        // Settings and its sub-screens.
        goTo(app, "Settings"); sleep(2)
        attach(app, "18-settings")
        assertNoOptional("settings")
        for id in ["AccountSecuritySettingsButton", "AutofillSettingsButton", "VaultSettingsButton", "AppearanceSettingsButton",
                   "OtherSettingsButton", "AboutSettingsButton"] {
            let row = app.buttons[id]
            guard row.waitForExistence(timeout: 5) else { XCTFail("missing settings row \(id)"); continue }
            row.tap(); sleep(2)
            assertNoOptional(id)
            app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        }
    }

    /// Content scrolls under the bars (soft fades, no solid strip or block); screenshots show the result.
    /// Formerly `PassYUiR9Tests.test06_contentScrollsUnderBars`.
    func test_contentScrollsUnderBars() {
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
}
