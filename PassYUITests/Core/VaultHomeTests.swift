import XCTest

/// The vault home: large title, category tiles, list pages.
final class VaultHomeTests: PassYUITestCase {
    /// The category tiles are large (about 180 x 96 pt on an iPhone, two per row).
    /// Formerly `PassYFlowTests.test21_categoryTilesAreLarge`.
    func test_categoryTilesAreLarge() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(tile.frame.height, 96, "tile height \(tile.frame.height)")
        XCTAssertGreaterThanOrEqual(tile.frame.width, 150, "tile width \(tile.frame.width)")
        attach(app, "21-tiles")
    }

    // MARK: 25 to 27: ui-r4
    /// Tiles in the same row have the same height; "Verification codes" does not wrap.
    /// Formerly `PassYFlowTests.test25_tilesEqualHeightNoWrap`.
    func test_tilesEqualHeightNoWrap() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let login = app.buttons["CategoryTile_login"]
        let totp = app.buttons["CategoryTile_totp"]
        XCTAssertTrue(login.waitForExistence(timeout: 10))
        XCTAssertTrue(totp.waitForExistence(timeout: 5), "verification codes tile")
        let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'CategoryTile_'")).allElementsBoundByIndex
        var rows: [CGFloat: [CGFloat]] = [:]
        for t in tiles where t.exists && t.frame.height > 0 { rows[t.frame.minY.rounded(), default: []].append(t.frame.height) }
        XCTAssertFalse(rows.isEmpty)
        for (y, heights) in rows {
            XCTAssertEqual(Set(heights.map { $0.rounded() }).count, 1, "tiles in the row at y=\(y) differ in height: \(heights)")
        }
        XCTAssertEqual(login.frame.height.rounded(), totp.frame.height.rounded(), "login vs verification codes tile height")
        attach(app, "25-tiles-equal")
    }

    /// ui-r5 (Apple Passwords look): the vault home has a left-aligned large title; the item view shows the name
    /// centered under a big icon and label/value rows on one line (value to the right of the label).
    /// Formerly `PassYFlowTests.test28_homeLargeTitleAndInlineItemRows`.
    func test_largeTitleAndInlineItemRows() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let title = app.staticTexts["My vault"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let screenWidth = app.windows.firstMatch.frame.width
        XCTAssertLessThan(title.frame.minX, screenWidth * 0.2, "large title is left-aligned: \(title.frame)")
        XCTAssertGreaterThan(title.frame.height, 30, "large title font: \(title.frame)")
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        XCTAssertLessThan(title.frame.maxY, tile.frame.minY, "title above the tiles")
        tile.tap()
        let row = app.buttons["VaultListItemRowButton"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let label = app.staticTexts["Username"].firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 10), "item view shows the Username row")
        let value = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '@'")).firstMatch
        XCTAssertTrue(value.exists)
        XCTAssertEqual(label.frame.midY, value.frame.midY, accuracy: 12, "label and value share one line")
        XCTAssertGreaterThan(value.frame.minX, label.frame.maxX, "value is right of the label")
        // Name centered over the rows.
        let name = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Item name'")).firstMatch
        if name.exists { XCTAssertEqual(name.frame.midX, screenWidth / 2, accuracy: 24, "item name centered") }
        attach(app, "28-item-view-inline")
    }

    /// A list page shows no spinner after opening: rows are there when the page is, the Vault button appears with the
    /// push and goes away with the pop (event driven, no timer).
    /// Formerly `PassYUiR9Tests.test05_listNoSpinner_vaultButtonFollowsStack`.
    func test_listNoSpinnerVaultButtonFollowsStack() {
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
}
