import XCTest

/// Item view details (TOTP, reveal/copy, favorite, toolbar), native forms, password round trip, the add forms of every type.
final class ItemDetailTests: PassYUITestCase {
    // MARK: 04 TOTP
    /// Formerly `PassYFlowTests.test04_totpCodeShown`.
    func test_totpCodeShown() {
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

    /// Real taps in the item view (Apple style, no eye or copy icons): long press offers Reveal and Copy, tapping a row
    /// copies (toast "copied"), the breach check is a plain row, the favorite star is in the toolbar and toggles.
    /// Formerly `PassYFlowTests.test12_itemViewRevealAndCopyTaps`.
    func test_revealCopyAndFavoriteTaps() {
        let app = launchApp()
        ensureUnlockedVault(app)
        openGitHubViaSearch(app)
        let password = app.descendants(matching: .any)["LoginPasswordEntry"]
        XCTAssertTrue(password.waitForExistence(timeout: 5), "password row exists")
        XCTAssertFalse(app.buttons["ShowLoginPasswordButton"].exists, "no eye button")
        XCTAssertFalse(app.buttons["LoginCopyUsernameButton"].exists, "no copy icon")
        XCTAssertFalse(app.buttons["LoginCopyPasswordButton"].exists, "no copy icon")
        let hiddenLabel = password.label
        attach(app, "12-item-hidden")
        password.press(forDuration: 1.2); sleep(1)
        let reveal = app.buttons["Reveal"].exists ? app.buttons["Reveal"] : app.menuItems["Reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5), "context menu offers Reveal")
        attach(app, "12-item-context-menu")
        reveal.tap(); sleep(1)
        attach(app, "12-item-revealed")
        XCTAssertNotEqual(app.descendants(matching: .any)["LoginPasswordEntry"].label, hiddenLabel, "Reveal shows the password")
        let copied = NSPredicate(format: "label CONTAINS[c] 'copied'")
        let user = app.descendants(matching: .any)["LoginUsernameEntry"]
        user.press(forDuration: 1.2); sleep(1)
        let copy = app.buttons["Copy"].exists ? app.buttons["Copy"] : app.menuItems["Copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5), "context menu offers Copy")
        copy.tap(); sleep(1)
        XCTAssertTrue(app.staticTexts.matching(copied).firstMatch.waitForExistence(timeout: 5), "context menu copy shows a copied toast")
        attach(app, "12-item-copy-toast")
        sleep(4)
        app.descendants(matching: .any)["LoginUsernameEntry"].tap(); sleep(1)
        XCTAssertTrue(app.staticTexts.matching(copied).firstMatch.waitForExistence(timeout: 5), "tapping the row copies and shows the toast")
        attach(app, "12-item-row-tap-toast")
        XCTAssertTrue(app.buttons["CheckPasswordButton"].waitForExistence(timeout: 5), "breach check is a plain row")
        let star = app.buttons["FavoriteToolbarButton"]
        XCTAssertTrue(star.exists, "favorite star in the toolbar")
        let before = star.value as? String
        star.tap(); sleep(3)
        XCTAssertNotEqual(app.buttons["FavoriteToolbarButton"].value as? String, before, "tapping the star toggles favorite")
        app.buttons["FavoriteToolbarButton"].tap(); sleep(3)
        XCTAssertEqual(app.buttons["FavoriteToolbarButton"].value as? String, before, "toggled back")
    }

    // MARK: 22 to 24: ui-r3 phase B (native look)
    /// Item view: Edit is a toolbar button (no floating pencil); Send list: About Send sits in the "..." menu.
    /// Formerly `PassYFlowTests.test22_editInToolbarAndSendInfoInMenu`.
    func test_editInToolbarAndSendInfoInMenu() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        let row = app.buttons["VaultListItemRowButton"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "an item row")
        row.tap()
        let edit = app.buttons["EditItemButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Edit is a toolbar button")
        XCTAssertFalse(app.buttons["EditItemFloatingActionButton"].exists, "no floating edit button")
        XCTAssertLessThan(edit.frame.midY, 160, "Edit sits in the navigation bar: \(edit.frame)")
        attach(app, "22-item-view-toolbar")
        app.buttons["CloseButton"].firstMatch.tap()
        // Back from the item list to the vault root (the avatar menu is on root screens only).
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 5) { back.tap() }
        goTo(app, "Send")
        let options = app.buttons["HeaderBarOptionsButton"].firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 10), "Send has an options menu next to the avatar")
        XCTAssertFalse(app.buttons["About Send"].exists, "no separate info button")
        options.tap()
        XCTAssertTrue(app.buttons["About Send"].waitForExistence(timeout: 5), "menu offers About Send")
        attach(app, "22-send-menu")
    }

    /// Item view, item edit and the Send add form are native lists (collection view/table), not a plain scroll view of cards.
    /// Formerly `PassYFlowTests.test26_itemViewItemEditAndSendAddAreNativeForms`.
    func test_viewEditAndSendAddAreNativeForms() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        let row = app.buttons["VaultListItemRowButton"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["EditItemButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.collectionViews.firstMatch.exists || app.tables.firstMatch.exists, "item view is a native Form/List")
        app.buttons["Edit"].firstMatch.tap()
        XCTAssertTrue(app.textFields["ItemNameEntry"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.collectionViews.firstMatch.exists || app.tables.firstMatch.exists, "item edit is a native Form")
        attach(app, "26-item-edit-form")
        app.buttons["CancelButton"].firstMatch.tap()
        if app.buttons["Cancel"].waitForExistence(timeout: 2) { app.buttons["Cancel"].tap() }
        app.buttons["CloseButton"].firstMatch.tap()
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 5) { back.tap() }
        // Send add (text): a native Form with the name field and the deletion date row.
        goTo(app, "Send")
        let add = app.buttons["AddItemFloatingActionButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let menuText = app.menuItems["Text"]
        let text = app.buttons.matching(NSPredicate(format: "label == 'Text'")).firstMatch
        if !menuText.waitForExistence(timeout: 3), !text.exists { add.tap() }
        (menuText.waitForExistence(timeout: 3) ? menuText : text).tap()
        XCTAssertTrue(app.textFields["SendNameEntry"].waitForExistence(timeout: 10), "send add form")
        XCTAssertTrue(app.collectionViews.firstMatch.exists || app.tables.firstMatch.exists, "send add is a native Form")
        XCTAssertTrue(app.buttons["SendDeletionOptionsPicker"].exists || app.staticTexts["Deletion date"].exists, "deletion date row")
        attach(app, "26-send-add-form")
        app.buttons["CancelButton"].firstMatch.tap()
        if app.buttons["Cancel"].waitForExistence(timeout: 2) { app.buttons["Cancel"].tap() }
    }

    /// A whole password (12+ characters) survives save and reopen: masked bullet count equals its length, the revealed
    /// value equals what was typed; editing an existing item appends correctly and is saved. Needs the throwaway server.
    /// Formerly `PassYUiR7ShotsTests.test_loginPasswordSaveAndRevealRoundTrip`.
    func test_passwordSaveAndRevealRoundTrip() {
        setPassYAppearance(.light)
        let token = Int(Date().timeIntervalSince1970) % 100000
        let name = "AA Qzx Pw \(token)"
        let password = "Sup3rSecret-2026!"
        let app = launchApp()
        ensureUnlockedVault(app)
        // Create.
        XCTAssertTrue(openAdd(app, "Login"))
        let ok = app.alerts.buttons["OK"]
        if ok.waitForExistence(timeout: 3) { ok.tap() }
        let nameField = app.textFields["ItemNameEntry"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap(); nameField.typeText(name)
        let user = app.textFields["LoginUsernameEntry"]
        user.tap(); user.typeText("pw@example.test")
        typePassword(app, password)
        app.buttons["SaveButton"].firstMatch.tap()
        _ = app.buttons["Close"].waitForExistence(timeout: 8)
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        if close.exists { close.firstMatch.tap() }
        sleep(2)

        func openEdit() {
            if (app.searchFields.firstMatch.value as? String) != "Qzx" {
                focusSearch(app)
                for ch in "Qzx" { app.typeText(String(ch)); usleep(150_000) }
            }
            let row = app.staticTexts[name]
            XCTAssertTrue(row.waitForExistence(timeout: 10), "search finds the item")
            row.tap()
            let edit = app.buttons["EditItemButton"]
            XCTAssertTrue(edit.waitForExistence(timeout: 8)); edit.tap(); sleep(2)
        }
        func checkPassword(_ expected: String, _ label: String) {
            let masked = app.secureTextFields["LoginPasswordEntry"]
            XCTAssertTrue(masked.waitForExistence(timeout: 8), "masked password field (\(label))")
            XCTAssertEqual((masked.value as? String ?? "").count, expected.count, "\(label): one bullet per character")
            attach(app, "r7-60-\(label)-masked")
            app.buttons["ViewPasswordButton"].firstMatch.tap(); sleep(1)
            let revealed = app.textFields["LoginPasswordEntry"]
            XCTAssertTrue(revealed.waitForExistence(timeout: 5), "revealed password field (\(label))")
            XCTAssertEqual(revealed.value as? String, expected, "\(label): revealed value equals what was typed")
            attach(app, "r7-61-\(label)-revealed")
        }
        // Reopen after save: compare.
        openEdit()
        checkPassword(password, "saved")
        // Edit an existing item: append through the (now revealed) plain field, save, reopen, compare.
        let revealed = app.textFields["LoginPasswordEntry"]
        revealed.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        revealed.typeText("+edit")
        app.buttons["SaveButton"].firstMatch.tap()
        _ = app.buttons["Close"].waitForExistence(timeout: 8)
        let close2 = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        if close2.exists { close2.firstMatch.tap() }
        sleep(2)
        openEdit()
        checkPassword(password + "+edit", "edited")
        // Clean up: the item must not stay in the vault.
        closeSheet(app); sleep(1)
        closeSheet(app); sleep(1)
        let row = app.staticTexts[name]
        if row.waitForExistence(timeout: 8) {
            // The row can exist in the tree while it is below the fold or under the bottom bar: scroll it into view.
            for _ in 0 ..< 8 where !row.isHittable { app.swipeUp(); usleep(400_000) }
            row.swipeLeft(); sleep(1)
            app.buttons["Delete"].firstMatch.tap()
            if app.alerts.buttons["Yes"].waitForExistence(timeout: 5) { app.alerts.buttons["Yes"].tap() }
            XCTAssertTrue(waitForDisappearance(of: row, timeout: 15), "test item removed")
        }
    }

    // MARK: Step 2: add and edit forms
    /// Add forms for every item type are Apple rows: the label stands left, the value right of it (not stacked).
    /// Formerly `PassYUiR7ShotsTests.test_addEditFormsAreInlineRows`.
    func test_addEditFormsAreInlineRows() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            var n = 1
            for type in ["Login", "Card", "Identity", "Secure note", "Bank account", "Passport", "License"] {
                XCTAssertTrue(openAdd(app, type), "add menu has \(type)")
                if type == "Login" {
                    let name = app.textFields["ItemNameEntry"]
                    XCTAssertTrue(name.waitForExistence(timeout: 10))
                    let user = app.textFields["LoginUsernameEntry"]
                    app.dismissNewLoginCard()
                    let ok = app.alerts.buttons["OK"]
                    if ok.waitForExistence(timeout: 3) { ok.tap(); sleep(1) }
                    // Stacked rows start at the leading edge (x = 20); inline rows start after the label. The name is
                    // a free field without a label (its title is the placeholder), so the username row is checked.
                    XCTAssertGreaterThan(user.frame.minX, 100, "username field sits right of its label (inline row)")
                    XCTAssertLessThan(user.frame.height, 50)
                    XCTAssertLessThan(name.frame.minX, 60, "name field is a free field starting at the leading edge")
                }
                shot(app, n, "\(mode)-add-\(type.lowercased().replacingOccurrences(of: " ", with: "-"))"); n += 1
                if type == "Login" {
                    // Bottom of the form: URIs, Additional options.
                    app.swipeUp(); sleep(1)
                    let additional = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Additional options'")).firstMatch
                    if additional.waitForExistence(timeout: 3), additional.isHittable { additional.tap(); sleep(1) }
                    app.swipeUp(); sleep(1)
                    shot(app, n, "\(mode)-add-login-bottom"); n += 1
                    let newField = app.buttons["NewCustomFieldButton"]
                    if newField.exists, newField.isHittable {
                        newField.tap(); sleep(1)
                        shot(app, n, "\(mode)-add-login-custom-field-type"); n += 1
                        let text = app.buttons["Text"].firstMatch
                        if text.waitForExistence(timeout: 2) { text.tap(); sleep(1) }
                        app.swipeUp(); sleep(1)
                        shot(app, n, "\(mode)-add-login-custom-field"); n += 1
                    }
                }
                closeSheet(app)
            }
            // Edit the first login.
            app.buttons["CategoryTile_login"].tap(); sleep(2)
            let row = app.buttons["VaultListItemRowButton"].firstMatch
            if row.waitForExistence(timeout: 8) {
                row.tap(); sleep(2)
                let edit = app.buttons["EditItemButton"]
                if edit.waitForExistence(timeout: 5) {
                    edit.tap(); sleep(2)
                    shot(app, n, "\(mode)-edit-login"); n += 1
                }
            }
            app.terminate()
        }
        setPassYAppearance(.light)
    }

    /// Add forms for the types that need the `pm-32009-new-item-types` server flag (Vaultwarden
    /// `EXPERIMENTAL_CLIENT_FEATURE_FLAGS`): bank account, passport, driver's license.
    /// Formerly `PassYUiR5ShotsTests.test_newTypeForms`.
    func test_newItemTypeForms() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            var n = 1
            for type in ["Bank account", "Passport", "License"] {
                XCTAssertTrue(openAdd(app, type), "add menu has \(type) (server flag pm-32009-new-item-types)")
                shot(app, n, "\(mode)-add-\(type.lowercased().replacingOccurrences(of: " ", with: "-"))"); n += 1
                closeSheet(app)
            }
            app.terminate()
        }
        setPassYAppearance(.light)
    }
}
