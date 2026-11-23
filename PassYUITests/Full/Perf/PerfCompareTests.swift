import XCTest

/// Before/after comparison against the 2000 item perf account. Prints `R8CMP <name> ...`.
final class PerfCompareTests: PassYUITestCase {
    /// Unlock until the first list row exists (2000 items).
    /// Formerly `PassYUiR8CompareTests.test_cmp_unlockToFirstRow`.
    func test_cmp_unlockToFirstRow() {
        var values: [Double] = []
        let first = launchApp()
        ensureUnlockedVault(first)
        for _ in 0 ..< 3 {
            first.terminate()
            let app = launchApp()
            let pw = app.secureTextFields["MasterPasswordEntry"]
            XCTAssertTrue(waitFor(pw))
            // Verified typing (`replaceText`): a dropped keystroke otherwise unlocks with a wrong password and the
            // test only sees "no row" (v1.27 recheck: plain `typeText`, an alert was still up in the next test).
            // The clock starts at the Unlock tap, so the retype does not count into the measurement.
            pw.replaceText(TestAccount.password)
            let start = Date()
            app.buttons["UnlockVaultButton"].tap()
            let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Perf Item'")).firstMatch
            guard waitFor(row, timeout: 60) else {
                let alert = app.alerts.firstMatch
                let texts = alert.exists ? alert.staticTexts.allElementsBoundByIndex.map(\.label) : []
                return XCTFail("no 'Perf Item' row 60 s after Unlock (alert: \(alert.exists) \(texts))\n\(app.debugDescription)")
            }
            values.append(Date().timeIntervalSince(start))
            app.terminate()
        }
        line("unlock_to_first_row", values)
    }

    /// Tile tap until the first row of the list page exists.
    /// Formerly `PassYUiR8CompareTests.test_cmp_tileTapToList`.
    func test_cmp_tileTapToList() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(waitFor(tile, timeout: 60))
        var values: [Double] = []
        for _ in 0 ..< 10 {
            let start = Date()
            tile.tap()
            let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN {'VaultListItemRowButton','CipherCell'}")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 20))
            values.append(Date().timeIntervalSince(start))
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(waitFor(tile, timeout: 10))
        }
        line("tile_tap_to_list", values)
    }

    /// Row tap on the name (left) and on the blank middle (0.72): how many of 10 single taps open the item, and how long.
    /// Formerly `PassYUiR8CompareTests.test_cmp_rowTapOpensItem`.
    func test_cmp_rowTapOpensItem() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["CategoryTile_login"].tap()
        let rowQuery = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN {'VaultListItemRowButton','CipherCell'}"))
        XCTAssertTrue(rowQuery.firstMatch.waitForExistence(timeout: 30))
        for (name, dx) in [("name", 0.25), ("blank", 0.72)] {
            var opened = 0
            var values: [Double] = []
            for _ in 0 ..< 10 {
                let row = rowQuery.firstMatch
                let start = Date()
                row.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).tap()
                if app.buttons["Close"].firstMatch.waitForExistence(timeout: 1.5) {
                    opened += 1
                    values.append(Date().timeIntervalSince(start))
                    app.buttons["Close"].firstMatch.tap()
                    _ = row.waitForExistence(timeout: 5)
                }
            }
            line("row_tap_\(name)_opens_within_1_5s", values, extra: "opened=\(opened)/10")
        }
    }
}
