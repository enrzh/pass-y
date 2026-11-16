import XCTest

/// ui-r7: native Apple-style edit rows (label left, value right), home search results with context menu, swipe and
/// Select mode, auth pages. Attachment names: `<PASSY_SHOT_TAG>-<nn>-<screen>`.
final class PassYUiR7ShotsTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "r7" }

    private func shot(_ app: XCUIApplication, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(String(format: "%02d", n))-\(name)")
    }

    private func closeSheet(_ app: XCUIApplication) {
        for id in ["CancelButton", "CloseButton", "Close", "Cancel"] {
            let b = app.buttons[id].firstMatch
            if b.exists, b.isHittable { b.tap(); sleep(1); break }
        }
        let discard = app.buttons["Cancel"].firstMatch
        if discard.waitForExistence(timeout: 1) { discard.tap() }
    }

    private func openAdd(_ app: XCUIApplication, _ type: String) -> Bool {
        let fab = app.buttons["AddItemFloatingActionButton"]
        guard fab.waitForExistence(timeout: 8) else { return false }
        fab.tap(); sleep(1)
        let item = app.menuItems.matching(NSPredicate(format: "label BEGINSWITH %@", type)).firstMatch
        let btn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT (identifier BEGINSWITH 'CategoryTile')", type)).firstMatch
        if item.waitForExistence(timeout: 3) { item.tap() } else if btn.waitForExistence(timeout: 2) { btn.tap() } else { app.tap(); return false }
        sleep(2)
        return true
    }

    // MARK: Step 2: add and edit forms

    /// Add forms for every item type are Apple rows: the label stands left, the value right of it (not stacked).
    func test_addEditFormsAreInlineRows() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            var n = 1
            for type in ["Login", "Card", "Identity", "Secure note", "Bank account", "Passport", "License"] {
                XCTAssertTrue(openAdd(app, type), "add menu has \(type)")
                if type == "Login" {
                    let name = app.textFields["ItemNameEntry"]
                    XCTAssertTrue(name.waitForExistence(timeout: 10))
                    app.dismissNewLoginCard()
                    let ok = app.alerts.buttons["OK"]
                    if ok.waitForExistence(timeout: 3) { ok.tap(); sleep(1) }
                    // Stacked rows start at the leading edge (x = 20); inline rows start after the label.
                    XCTAssertGreaterThan(name.frame.minX, 100, "name field sits right of its label (inline row)")
                    XCTAssertLessThan(name.frame.height, 50)
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
        XCUIDevice.shared.appearance = .light
    }

    // MARK: Step 4: home search results

    /// Home search: context menu with Delete, swipe Delete, Select mode; cancelling the confirmation keeps Select mode.
    func test_homeSearchSelectDelete() {
        XCUIDevice.shared.appearance = .light
        let token = Int(Date().timeIntervalSince1970) % 100000
        let a = "AA Qzx Find \(token) One", b = "AA Qzx Find \(token) Two", c = "AA Qzx Find \(token) Three"
        let app = launchApp()
        ensureUnlockedVault(app)
        addLogin(app, name: a, user: "a@example.test", password: "x1")
        addLogin(app, name: b, user: "b@example.test", password: "x2")
        addLogin(app, name: c, user: "c@example.test", password: "x3")
        focusSearch(app)
        app.searchFields.firstMatch.typeText("Qzx")
        XCTAssertTrue(app.staticTexts[a].waitForExistence(timeout: 10), "search finds the items")
        shot(app, 1, "search-results")
        // Context menu: Delete is offered.
        app.staticTexts[a].press(forDuration: 1.2); sleep(1)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5) || app.menuItems["Delete"].exists,
                      "context menu offers Delete")
        shot(app, 2, "search-context-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap(); sleep(2)
        // Select mode.
        let select = app.buttons["SelectButton"]
        XCTAssertTrue(select.waitForExistence(timeout: 5), "Select button while searching")
        select.tap(); sleep(1)
        XCTAssertFalse(app.buttons["SelectDeleteButton"].isEnabled, "delete disabled without selection")
        app.staticTexts[a].tap(); app.staticTexts[b].tap(); sleep(1)
        XCTAssertTrue(app.buttons["SelectDeleteButton"].isEnabled)
        shot(app, 3, "search-select-mode")
        // Cancel keeps Select mode and the rows.
        app.buttons["SelectDeleteButton"].tap()
        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap(); sleep(1)
        XCTAssertTrue(app.buttons["SelectDeleteButton"].exists, "Select mode stays after cancelling")
        XCTAssertTrue(app.buttons["SelectDeleteButton"].isEnabled, "selection stays after cancelling")
        XCTAssertTrue(app.staticTexts[a].exists && app.staticTexts[b].exists)
        // Confirm deletes the two selected items, the third stays.
        app.buttons["SelectDeleteButton"].tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5)); yes.tap()
        XCTAssertTrue(waitForDisappearance(of: app.staticTexts[a], timeout: 15), "selected items are deleted")
        XCTAssertFalse(app.staticTexts[b].exists)
        XCTAssertTrue(app.staticTexts[c].exists, "the unselected item stays")
        // Swipe delete the last one.
        let last = app.staticTexts[c]
        last.swipeLeft(); sleep(1)
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.alerts.buttons["Yes"].waitForExistence(timeout: 5)); app.alerts.buttons["Yes"].tap()
        XCTAssertTrue(waitForDisappearance(of: last, timeout: 15), "swipe delete on a search result")
    }
}
