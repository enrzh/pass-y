import XCTest

/// Screenshots of the item view, edit and add forms (every type), Apple Passwords comparison. Never gating.
final class ShotsItemTests: PassYUITestCase {
    /// Item view, edit (login), "..." menu, attachments, password history, add forms for every item type.
    /// Formerly `PassYUiR4ShotsTests.test_item`.
    func test_itemViewAndEdit() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
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
        setPassYAppearance(.light)
    }

    /// The add form for every item type.
    /// Formerly `PassYUiR4ShotsTests.test_addTypes`.
    func test_addFormOfEveryType() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
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
                if type == "Login" {
                    let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
                    for _ in 0 ..< 3 { list.swipeUp(velocity: .fast); usleep(400_000) }
                    shot(app, mode, n, "add-login-bottom"); n += 1
                }
                cancelOrClose(app); discardIfAsked(app)
            }
            app.terminate()
        }
        setPassYAppearance(.light)
    }

    /// Home, item list and item view in the current light/dark appearance for the Apple Passwords comparison.
    /// Formerly `PassYUiR5ShotsTests.test_compare`.
    func test_appleComparison() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            XCTAssertTrue(app.buttons["CategoryTile_login"].waitForExistence(timeout: 10))
            shot(app, 1, "\(mode)-home")
            app.buttons["CategoryTile_login"].tap(); sleep(2)
            shot(app, 2, "\(mode)-list")
            let row = app.buttons["VaultListItemRowButton"].firstMatch
            if row.waitForExistence(timeout: 8) {
                row.tap(); sleep(2)
                shot(app, 3, "\(mode)-detail")
                let edit = app.buttons["Edit"].firstMatch
                if edit.exists { edit.tap(); sleep(2); shot(app, 4, "\(mode)-edit"); closeSheet(app) }
            }
            app.terminate()
        }
        setPassYAppearance(.light)
    }

    /// Edit form of every item type the app can create (SSH keys can only be imported: render only), light and dark.
    /// Items are created through the add forms (name only) and found again by searching "Qzx".
    /// Formerly `PassYUiR7ShotsTests.test_editFormOfEveryType`.
    func test_editFormOfEveryType() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PASSY_KNOWN_ISSUE_TESTS"] == "1",
                          "shot collector: opening the 3rd/4th item from the search results is unreliable (no Edit button), and the items it creates have no username (they break test_rowChevronContextMenuSwipe); see README")
        let types = ["Login", "Card", "Identity", "Secure note", "Bank account", "Passport", "License"]
        let token = Int(Date().timeIntervalSince1970) % 100000
        var app = launchApp()
        ensureUnlockedVault(app)
        for type in types {
            XCTAssertTrue(openAdd(app, type), "add menu has \(type)")
            let name = app.textFields["ItemNameEntry"]
            XCTAssertTrue(name.waitForExistence(timeout: 10))
            let ok = app.alerts.buttons["OK"]
            if ok.waitForExistence(timeout: 2) { ok.tap() }
            name.tap(); name.typeText("AA Qzx \(type.replacingOccurrences(of: " ", with: "")) \(token)")
            app.buttons["SaveButton"].firstMatch.tap()
            _ = app.buttons["Close"].waitForExistence(timeout: 8)
            let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
            if close.exists { close.firstMatch.tap() }
            sleep(2)
        }
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            app.terminate()
            app = launchApp()
            ensureUnlockedVault(app)
            var n = 20
            for type in types {
                let itemName = "AA Qzx \(type.replacingOccurrences(of: " ", with: "")) \(token)"
                if (app.searchFields.firstMatch.value as? String) != "Qzx" {
                    focusSearch(app)
                    for ch in "Qzx" { app.typeText(String(ch)); usleep(150_000) }
                }
                let row = app.staticTexts[itemName]
                XCTAssertTrue(row.waitForExistence(timeout: 10), "search finds \(itemName)")
                row.tap()
                let edit = app.buttons["EditItemButton"]
                XCTAssertTrue(edit.waitForExistence(timeout: 8)); edit.tap(); sleep(2)
                shot(app, n, "\(mode)-edit-\(type.lowercased().replacingOccurrences(of: " ", with: "-"))"); n += 1
                closeSheet(app); sleep(1)
                closeSheet(app); sleep(1)
                let clear = app.buttons["Clear text"].firstMatch
                if clear.exists, clear.isHittable { clear.tap() }
            }
        }
        setPassYAppearance(.light)
    }
}
