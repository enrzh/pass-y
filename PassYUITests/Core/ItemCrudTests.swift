import XCTest

/// Add, open, edit and delete an item (the critical item paths).
final class ItemCrudTests: PassYUITestCase {
    // MARK: 05 Generator
    /// The add (+) menu in the bottom bar opens and offers the item types and Folder (iPhone and iPad).
    /// Formerly `PassYFlowTests.test08_addMenuOpensWithEntries`.
    func test_addMenuOpensWithEntries() {
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

    // MARK: 03 Create, search, edit, delete
    /// Formerly `PassYFlowTests.test03_createSearchEditDelete`.
    func test_createSearchEditDelete() {
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
        focusSearch(app) // the first tap on the bottom search bar is sometimes ignored; make sure the keyboard is up
        // Type slowly: with a 2000-item vault the main thread is busy after each keystroke and fast typing drops characters.
        for ch in itemName { app.typeText(String(ch)); usleep(150_000) }
        attach(app, "03-search")
        let hit = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", itemName)).firstMatch
        XCTAssertTrue(waitFor(hit), "search finds the item (search field value: \(search.value as? String ?? "nil"))")

        // Open (straight from the search results; the bottom search bar keeps the results visible) + edit
        app.staticTexts[itemName].firstMatch.tap()
        XCTAssertTrue(waitFor(app.buttons["CipherOptionsButton"].exists ? app.buttons["CipherOptionsButton"] : app.buttons["Options"]))
        attach(app, "03-view-item")
        let edit = app.buttons["EditItemButton"]
        if edit.waitForExistence(timeout: 5) { edit.tap() } else {
            app.buttons["CipherOptionsButton"].tap(); app.buttons["Edit"].tap()
        }
        let editName = app.textFields["ItemNameEntry"]
        XCTAssertTrue(waitFor(editName))
        // ui-r7: edit rows are right-aligned (Apple style), so a tap in the middle of the field puts the caret in the
        // middle of the text; tap at the trailing edge to put the caret at the end, then append.
        editName.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        editName.typeText(" Edited")
        app.buttons["SaveButton"].firstMatch.tap()
        XCTAssertTrue(waitFor(app.staticTexts["\(itemName) Edited"]), "edit saved")
        attach(app, "03-edited")

        // Delete
        deleteCurrentItem(app)
        XCTAssertFalse(app.staticTexts["\(itemName) Edited"].exists, "item deleted from list")
        attach(app, "03-after-delete")
    }

    /// An item opens without a spinner: right after the sheet is there, the toolbar already has the favorite button
    /// (it only exists once the item is loaded) and no activity indicator is shown.
    /// Formerly `PassYUiR9Tests.test04_itemOpensWithoutSpinner`.
    func test_itemOpensWithoutSpinner() {
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

    /// One tap on the blank part of a category tile list row opens the item sheet within one second.
    /// Formerly `PassYUiR8Tests.test01_singleTapOpensItemFromBlankArea`.
    func test_singleTapOnBlankAreaOpensItem() {
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
}
