import XCTest

/// List row actions: chevron, context menu, swipe, Select mode delete (list and search results).
final class ItemListActionsTests: PassYUITestCase {
    /// Rows end with a chevron (no "..." button); the options are in the context menu and the swipe actions.
    /// Formerly `PassYUiR6ShotsTests.test_rowChevronContextMenuSwipe`.
    func test_rowChevronContextMenuSwipe() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            openLoginList(app)
            XCTAssertFalse(app.buttons["CipherOptionsButton"].exists, "no '...' button in list rows")
            XCTAssertTrue(app.images["CipherDisclosureChevron"].firstMatch.exists
                          || app.descendants(matching: .any)["CipherDisclosureChevron"].exists, "rows show a chevron")
            shot(app, 1, "\(mode)-list-chevron")
            // Long press: context menu with copy actions and Delete.
            let row = app.buttons["VaultListItemRowButton"].firstMatch
            row.press(forDuration: 1.2); sleep(1)
            XCTAssertTrue(app.buttons["Copy username"].waitForExistence(timeout: 5)
                          || app.menuItems["Copy username"].exists, "context menu offers Copy username")
            XCTAssertTrue(app.buttons["Delete"].exists || app.menuItems["Delete"].exists, "context menu offers Delete")
            shot(app, 2, "\(mode)-context-menu")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.45)).tap()
            waitUntil(5) { !app.buttons["Copy username"].exists && !app.menuItems["Copy username"].exists }
            XCTAssertFalse(app.buttons["Copy username"].exists || app.menuItems["Copy username"].exists, "menu dismissed")
            // Swipe: Delete + More (the row must be on screen and clear of the bottom bar for the swipe to reach it).
            for _ in 0 ..< 4 where !row.isHittable { app.swipeDown() }
            row.swipeLeft()
            _ = app.buttons["Delete"].waitForExistence(timeout: 5)
            XCTAssertTrue(app.buttons["Delete"].exists, "swipe offers Delete")
            XCTAssertTrue(app.buttons["More options"].exists, "swipe offers More options")
            shot(app, 3, "\(mode)-swipe")
            app.terminate()
        }
        setPassYAppearance(.light)
    }

    /// "N Items" subtitle and Select mode with Delete of the created items.
    /// Formerly `PassYUiR6ShotsTests.test_selectModeDelete`.
    func test_selectModeDelete() {
        setPassYAppearance(.light)
        let token = Int(Date().timeIntervalSince1970) % 100000
        let one = "AA R6 Zap \(token) One", two = "AA R6 Zap \(token) Two"
        let app = launchApp()
        ensureUnlockedVault(app)
        addLogin(app, name: one, user: "one@example.test", password: "x1")
        addLogin(app, name: two, user: "two@example.test", password: "x2")
        app.buttons["CategoryTile_login"].tap(); sleep(2)
        XCTAssertTrue(app.staticTexts[one].waitForExistence(timeout: 8))
        let select = app.buttons["SelectButton"]
        XCTAssertTrue(select.waitForExistence(timeout: 5), "Select button in the toolbar")
        shot(app, 10, "list-subtitle")
        select.tap(); sleep(1)
        XCTAssertFalse(app.buttons["SelectDeleteButton"].isEnabled, "delete disabled without selection")
        app.staticTexts[one].tap(); app.staticTexts[two].tap(); sleep(1)
        shot(app, 11, "select-mode")
        XCTAssertTrue(app.buttons["SelectDeleteButton"].isEnabled, "delete enabled with selection")
        app.buttons["SelectDeleteButton"].tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5))
        yes.tap()
        XCTAssertTrue(waitForDisappearance(of: app.staticTexts[one], timeout: 15), "selected items are deleted")
        XCTAssertFalse(app.staticTexts[two].exists)
    }

    /// Swipe-Delete of a single item.
    /// Formerly `PassYUiR6ShotsTests.test_swipeDelete`.
    func test_swipeDelete() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let gone = "AA R6 Swipe \(Int(Date().timeIntervalSince1970) % 100000)"
        addLogin(app, name: gone, user: "s@example.test", password: "x")
        app.buttons["CategoryTile_login"].tap(); sleep(2)
        let name = app.staticTexts[gone]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        name.swipeLeft(); sleep(1)
        app.buttons["Delete"].firstMatch.tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5)); yes.tap()
        XCTAssertTrue(waitForDisappearance(of: name, timeout: 15), "swipe delete removes the item")
    }

    /// Swipe-Delete asks first: while the confirmation is up the row stays in the list, "Cancel" keeps it, and only
    /// "Yes" removes it. (A `role: .destructive` swipe button made the list drop the row on the tap, before the
    /// confirmation; the later real removal then hit a list that no longer matched its data.)
    func test_swipeDeleteKeepsRowUntilConfirmed() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let target = "AA Swipe Keep \(Int(Date().timeIntervalSince1970) % 100000)"
        addLogin(app, name: target, user: "k@example.test", password: "x")
        app.buttons["CategoryTile_login"].tap()
        let name = app.staticTexts[target]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        let rowsBefore = app.buttons.matching(identifier: "VaultListItemRowButton").count
        for attempt in 1 ... 2 {
            name.swipeLeft()
            let delete = app.buttons["Delete"].firstMatch
            XCTAssertTrue(delete.waitForExistence(timeout: 5), "swipe offers Delete (attempt \(attempt))")
            delete.tap()
            XCTAssertTrue(app.alerts.buttons["Cancel"].waitForExistence(timeout: 5), "delete asks first")
            sleep(1)   // the removal animation of a destructive swipe button takes about 0.3 s
            XCTAssertTrue(name.exists, "the row stays while the confirmation is up (attempt \(attempt))")
            XCTAssertEqual(app.buttons.matching(identifier: "VaultListItemRowButton").count, rowsBefore,
                           "no row was removed before the confirmation (attempt \(attempt))")
            app.alerts.buttons["Cancel"].tap()
            XCTAssertTrue(waitForDisappearance(of: app.alerts.firstMatch, timeout: 5))
            sleep(1)
            XCTAssertTrue(name.exists, "Cancel keeps the row (attempt \(attempt))")
            XCTAssertEqual(app.buttons.matching(identifier: "VaultListItemRowButton").count, rowsBefore,
                           "Cancel keeps the row count (attempt \(attempt))")
        }
        name.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Delete"].firstMatch.tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5)); yes.tap()
        XCTAssertTrue(waitForDisappearance(of: name, timeout: 15), "Yes removes the row")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2), "the app is still running (no list diff crash)")
    }

    // MARK: Step 4: home search results
    /// Home search: context menu with Delete, swipe Delete, Select mode; cancelling the confirmation keeps Select mode.
    /// Formerly `PassYUiR7ShotsTests.test_homeSearchSelectDelete`.
    func test_searchResultsContextMenuSelectSwipeDelete() {
        setPassYAppearance(.light)
        let token = Int(Date().timeIntervalSince1970) % 100000
        let a = "AA Qzx Find \(token) One", b = "AA Qzx Find \(token) Two", c = "AA Qzx Find \(token) Three"
        let app = launchApp()
        ensureUnlockedVault(app)
        addLogin(app, name: a, user: "a@example.test", password: "x1")
        addLogin(app, name: b, user: "b@example.test", password: "x2")
        addLogin(app, name: c, user: "c@example.test", password: "x3")
        focusSearch(app)
        typeSearch(app, "Qzx")
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
