import XCTest

/// ui-r8 before/after: identical test code on `main` (v1.24) and on ui-r8, against the same 2000 item vault and the same
/// simulator. Prints `R8CMP <name> ...` lines (wall clock, includes XCUITest overhead: compare the two trees only).
final class PassYUiR8CompareTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func line(_ name: String, _ values: [Double], extra: String = "") {
        let sorted = values.sorted()
        let median = sorted.isEmpty ? -1 : sorted[sorted.count / 2]
        print("R8CMP \(name) n=\(values.count) median=\(String(format: "%.2f", median)) all=\(values.map { String(format: "%.2f", $0) }) \(extra)")
    }

    /// Unlock until the first list row exists (2000 items).
    func test_cmp_unlockToFirstRow() {
        var values: [Double] = []
        let first = launchApp()
        ensureUnlockedVault(first)
        for _ in 0 ..< 3 {
            first.terminate()
            let app = launchApp()
            let pw = app.secureTextFields["MasterPasswordEntry"]
            XCTAssertTrue(waitFor(pw))
            pw.focus(); pw.typeText(TestAccount.password)
            let start = Date()
            app.buttons["UnlockVaultButton"].tap()
            let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Perf Item'")).firstMatch
            XCTAssertTrue(waitFor(row, timeout: 60))
            values.append(Date().timeIntervalSince(start))
            app.terminate()
        }
        line("unlock_to_first_row", values)
    }

    /// Tile tap until the first row of the list page exists.
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
