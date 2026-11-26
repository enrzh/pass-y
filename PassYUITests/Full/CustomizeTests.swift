import XCTest

/// Customize (on-device layout preferences) and the home's long-press menus: a card becomes a folder row (nothing
/// disappears), a card moves to the front, a folder row becomes a card that opens the folder, Customize opens from the
/// menu, the card order is dragged in Customize, a section collapses, relaunch keeps everything. The session is shared
/// with the other Full classes, so the defaults are restored in a teardown block (Settings › Customize › Reset).
final class CustomizeTests: PassYUITestCase {
    /// The SSH key tile: no other UI test uses it.
    private let switchedTile = "sshKey"

    /// The folder switched to a card (created here when the vault has none of that name).
    private let cardFolder = "PassY Card Folder"

    func test_cardMenuRowsFolderCardsPersistAcrossRelaunch() {
        var app = launchApp()
        ensureUnlockedVault(app)
        addTeardownBlock { [unowned self] in resetLayout(app) }
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_\(switchedTile)"], timeout: 10), "SSH key card at the defaults")
        XCTAssertFalse(app.buttons["SectionExpandButton_PassYTypes"].exists, "no Types rows at the defaults")
        XCTAssertFalse(app.buttons["SectionExpandButton_PassYMore"].exists, "no More section at the defaults")

        // The avatar menu has no Customize entry any more.
        XCTAssertTrue(openAvatarMenu(app), "avatar menu opens")
        XCTAssertTrue(menuButton(app, id: "ProfileMenuSyncButton", label: "Sync now").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ProfileMenuCustomizeButton"].exists, "no Customize entry in the avatar menu")
        XCTAssertFalse(app.buttons["Customize home…"].exists || app.menuItems["Customize home…"].exists)
        // Close the menu with a harmless entry (a tap outside left the menu's overlay on the home).
        menuButton(app, id: "ProfileMenuSyncButton", label: "Sync now").tap()
        sleep(2)

        // Long press on the SSH key card: the menu over the lifted card, then "Show as Folder Row".
        longPress(app.buttons["CategoryTile_\(switchedTile)"])
        let asRow = menuItem(app, id: "HomeShowAsRowButton", label: "Show as Folder Row")
        if !asRow.waitForExistence(timeout: 5) {
            attachUnchecked(app, "card-menu-missing")
            print("CUSTOMIZE-MENU-TREE\n\(app.debugDescription)")
        }
        XCTAssertTrue(asRow.exists, "card menu: show as folder row")
        XCTAssertTrue(menuItem(app, id: "HomeCustomizeButton", label: "Customize…").exists, "card menu: Customize…")
        attach(app, "card-menu")
        asRow.tap()
        XCTAssertTrue(waitForDisappearance(of: app.buttons["CategoryTile_\(switchedTile)"], timeout: 5), "card gone")
        let types = app.buttons["SectionExpandButton_PassYTypes"]
        scrollTo(types, in: app)
        XCTAssertTrue(types.exists, "Types section with the switched tile")
        XCTAssertTrue(sshKeyRow(app).exists, "the SSH key is a folder row now, not gone")
        attach(app, "type-as-row")

        // Long press on Login: "Move to Front".
        scrollHome(app, toTop: true)
        let loginCard = app.buttons["CategoryTile_login"]
        if app.buttons["CategoryTile_totp"].exists {
            longPress(loginCard)
            let front = menuItem(app, id: "HomeCardMove_toFront", label: "Move to Front")
            XCTAssertTrue(front.waitForExistence(timeout: 5), "card menu: move to front")
            front.tap()
            sleep(1)
            assertLoginBeforeCodes(app)
        }

        // A folder row becomes a card; the card opens the folder.
        if !scrollToFolder(app, cardFolder) {
            createFolder(app, cardFolder)
            XCTAssertTrue(scrollToFolder(app, cardFolder), "folder row exists")
        }
        longPress(folderRow(app))
        let asCard = menuItem(app, id: "HomeShowAsCardButton", label: "Show as Card")
        XCTAssertTrue(asCard.waitForExistence(timeout: 5), "row menu: show as card")
        asCard.tap()
        scrollHome(app, toTop: true)
        XCTAssertTrue(waitFor(folderCard(app), timeout: 5), "folder card")
        XCTAssertFalse(folderRow(app).exists, "a folder shown as a card is not also a row")
        attach(app, "folder-card")
        folderCard(app).tap()
        XCTAssertTrue(waitFor(app.navigationBars.staticTexts[cardFolder].firstMatch, timeout: 10)
            || waitFor(app.staticTexts[cardFolder].firstMatch, timeout: 2), "the folder card opens the folder")
        goTo(app, "My vault")
        scrollHome(app, toTop: true)

        // Customize… from the SSH key row menu: the switches show the state, drag Codes below Login.
        let row = sshKeyRow(app)
        scrollTo(row, in: app)
        longPress(row)
        let customize = menuItem(app, id: "HomeCustomizeButton", label: "Customize…")
        XCTAssertTrue(customize.waitForExistence(timeout: 5), "row menu: Customize…")
        customize.tap()
        XCTAssertTrue(waitFor(control(app, "CustomizeCardColorsPicker"), timeout: 10), "Customize screen opens")
        attach(app, "customize-screen")
        let tileSwitch = control(app, "CustomizeTileToggle_\(switchedTile)")
        scrollTo(tileSwitch, in: app)
        XCTAssertEqual(tileSwitch.value as? String, "0", "SSH key: folder row")
        let codes = control(app, "CustomizeTileToggle_totp")
        let login = control(app, "CustomizeTileToggle_login")
        scrollTo(codes, in: app)
        app.buttons["CustomizeReorderButton"].firstMatch.tap()
        let handle = reorderHandle(in: app, near: login)
        XCTAssertTrue(handle.exists, "drag handle of Login")
        let target = reorderHandle(in: app, near: codes)
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.2)))
        sleep(1)
        XCTAssertGreaterThan(login.frame.minY, codes.frame.minY, "Login now below Verification codes")
        app.buttons["CustomizeReorderButton"].firstMatch.tap()
        attach(app, "customize-changed")

        // Back to the home, collapse the Types section with its chevron.
        goTo(app, "My vault")
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"], timeout: 10))
        assertCodesBeforeLogin(app)
        let typesAgain = app.buttons["SectionExpandButton_PassYTypes"]
        scrollTo(typesAgain, in: app)
        typesAgain.tap()
        XCTAssertTrue(waitForDisappearance(of: sshKeyRow(app), timeout: 5), "Types collapsed")
        XCTAssertEqual(typesAgain.value as? String, "Collapsed")
        attach(app, "home-customized")

        // Relaunch: everything persisted.
        app.terminate()
        app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"], timeout: 15))
        XCTAssertFalse(app.buttons["CategoryTile_\(switchedTile)"].exists, "still a row after the relaunch")
        XCTAssertTrue(folderCard(app).exists, "folder still a card after the relaunch")
        assertCodesBeforeLogin(app)
        let typesRelaunched = app.buttons["SectionExpandButton_PassYTypes"]
        scrollTo(typesRelaunched, in: app)
        XCTAssertEqual(typesRelaunched.value as? String, "Collapsed", "Types still collapsed after the relaunch")

        // Reachability: expand Types and open the switched type.
        typesRelaunched.tap()
        let sshRow = sshKeyRow(app)
        XCTAssertTrue(waitFor(sshRow, timeout: 5), "SSH key row under Types")
        scrollTo(sshRow, in: app)
        sshRow.tap()
        XCTAssertTrue(waitFor(app.navigationBars.staticTexts["SSH key"].firstMatch, timeout: 10)
            || waitFor(app.staticTexts["SSH key"].firstMatch, timeout: 2), "the SSH key page opens from its row")
        goTo(app, "My vault")
    }

    // MARK: Helpers

    /// A Customize control by identifier, whatever element type the system gives the toggle row.
    private func control(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// An item of the open context menu by identifier or label.
    private func menuItem(_ app: XCUIApplication, id: String, label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "(identifier == %@ OR label == %@) AND NOT (identifier BEGINSWITH 'CategoryTile') "
                + "AND (elementType == %d OR elementType == %d)",
            id, label, XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue,
        )).firstMatch
    }

    /// Opens the context menu of an element.
    private func longPress(_ element: XCUIElement) {
        XCTAssertTrue(waitFor(element, timeout: 5), "element to long-press")
        element.press(forDuration: 1.0)
        sleep(1)
    }

    /// The SSH key group row (Types section).
    private func sshKeyRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'VaultListItemRowButton' AND label BEGINSWITH 'SSH key'"))
            .firstMatch
    }

    /// The row of the card folder.
    private func folderRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier == 'VaultListItemRowButton' AND label CONTAINS %@", cardFolder,
        )).firstMatch
    }

    /// The card of the card folder.
    private func folderCard(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'CategoryTile_folder:' AND label == %@", cardFolder,
        )).firstMatch
    }

    /// Login comes before Verification codes in the card grid (reading order).
    private func assertLoginBeforeCodes(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let codes = app.buttons["CategoryTile_totp"]
        guard codes.exists else { return } // no verification codes in the vault: no card to order
        XCTAssertTrue(isBefore(app.buttons["CategoryTile_login"].frame, codes.frame), "Login before codes",
                      file: file, line: line)
    }

    /// Verification codes come before Login in the card grid.
    private func assertCodesBeforeLogin(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let codes = app.buttons["CategoryTile_totp"]
        guard codes.exists else { return }
        XCTAssertTrue(isBefore(codes.frame, app.buttons["CategoryTile_login"].frame), "codes before Login",
                      file: file, line: line)
    }

    /// Reading order of two frames.
    private func isBefore(_ first: CGRect, _ second: CGRect) -> Bool {
        first.minY < second.minY - 1 || (abs(first.minY - second.minY) <= 1 && first.minX < second.minX)
    }

    /// The reorder control of the row of `element` (the drag handle at the trailing edge in edit mode).
    private func reorderHandle(in app: XCUIApplication, near element: XCUIElement) -> XCUIElement {
        let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'"))
            .allElementsBoundByIndex
            .filter { $0.identifier != "CustomizeReorderButton" }
        let midY = element.frame.midY
        return handles.min { abs($0.frame.midY - midY) < abs($1.frame.midY - midY) } ?? handles.first
            ?? app.buttons["no-handle"]
    }

    /// Scrolls until the element is hittable and clear of the bottom search bar (at most 6 swipes up, then 6 down):
    /// a long press on a row under the bar would focus the search field instead.
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        func reachable() -> Bool {
            guard element.exists, element.isHittable else { return false }
            let bar = app.searchFields.firstMatch
            return !bar.exists || element.frame.maxY <= bar.frame.minY - 4
        }
        for _ in 0 ..< 6 where !reachable() {
            app.swipeUp(velocity: .slow)
        }
        for _ in 0 ..< 6 where !reachable() {
            app.swipeDown(velocity: .slow)
        }
    }

    /// Scrolls the home back to the cards.
    private func scrollHome(_ app: XCUIApplication, toTop: Bool) {
        for _ in 0 ..< 8 where !(app.buttons["CategoryTile_login"].exists && app.buttons["CategoryTile_login"].isHittable) {
            app.swipeDown()
        }
    }

    /// Settings › Customize › Reset to defaults (the session continues with the other classes).
    private func resetLayout(_ app: XCUIApplication) {
        guard app.state == .runningForeground else { return }
        if app.secureTextFields["MasterPasswordEntry"].exists { ensureUnlockedVault(app) }
        goTo(app, "Settings")
        let row = app.buttons["CustomizeSettingsButton"]
        scrollTo(row, in: app)
        guard row.exists else { return }
        row.tap()
        let reset = app.buttons["CustomizeResetButton"]
        guard waitFor(control(app, "CustomizeCardColorsPicker"), timeout: 10) else { return }
        scrollTo(reset, in: app)
        if reset.exists, reset.isEnabled { reset.tap() }
        goTo(app, "My vault")
    }
}
