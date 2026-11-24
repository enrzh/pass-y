import XCTest

/// Button response against the 2000 item perf account (`PASSY_EMAIL=passy-perf@example.test`): Close, Cancel, the
/// search cancel and the Vault button, from the tap until the previous screen is shown again (`shown`) and until it
/// is settled and hittable (`settled`). Prints `R8CMP <name> n=... median=...` like `PerfUnlockAndBackTests` (which
/// covers back from a group and from a settings page), so before/after runs compare line by line.
///
/// Each tap is preceded by `PASSY-MARK buttonTap <name> t=<absolute seconds>`. The app's DEBUG probes log the touch
/// itself (`touchprobe phase=down|up`), the action (`nav.pop`, `nav.dismiss`, `bar.cancelSearch`, `bar.vault`) and the
/// first frame of the transition (`nav.firstFrame`), so the XCUITest overhead (element lookup and the synthesized
/// touch, ~0.5 s) can be split from the app's own share: touch-up -> action -> first frame.
///
/// The ceilings are regression guards with room for a loaded machine, not targets.
final class PerfButtonResponseTests: PassYUITestCase {
    /// Runs per button (the medians need at least seven).
    private let runs = 8

    /// Wall clock ceiling of a median "shown" (XCUITest overhead included).
    private let shownCeiling = 2.5

    /// Controls whose hit area was below 44 x 44 pt (checked at the end, so the numbers are printed anyway).
    private var smallTargets: [String: CGSize] = [:]

    // MARK: Tests

    /// Item view (sheet) -> Close: until the list row is hittable again.
    func test_cmp_closeItemView() {
        let app = launchApp()
        ensureUnlockedVault(app)
        openLoginList(app)
        let row = app.buttons.matching(identifier: "VaultListItemRowButton").firstMatch
        var shown: [Double] = []
        var settled: [Double] = []
        for _ in 0 ..< runs {
            row.tap()
            let close = app.buttons["CloseButton"].firstMatch
            XCTAssertTrue(close.waitForExistence(timeout: 10), "item view is open")
            sleep(1)
            assertHitTarget(close, "CloseButton")
            let (s, t) = measure("close_item_view", close, shown: { !close.exists }, settled: { row.isHittable })
            shown.append(s)
            settled.append(t)
        }
        report("close_item_view", shown, settled)
    }

    /// Add login (sheet, untouched form) -> Cancel: until the vault home tile is hittable again.
    func test_cmp_cancelAddItem() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(waitFor(tile, timeout: 60))
        var shown: [Double] = []
        var settled: [Double] = []
        for _ in 0 ..< runs {
            let fab = app.buttons["AddItemFloatingActionButton"]
            XCTAssertTrue(fab.waitForExistence(timeout: 10))
            fab.tap()
            tapNewLoginMenuItem(app)
            let cancel = app.buttons["CancelButton"].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 10), "add item sheet is open")
            sleep(1)
            assertHitTarget(cancel, "CancelButton")
            assertHitTarget(app.buttons["SaveButton"].firstMatch, "SaveButton")
            let (s, t) = measure("cancel_add_item", cancel, shown: { !cancel.exists }, settled: { tile.isHittable })
            shown.append(s)
            settled.append(t)
        }
        report("cancel_add_item", shown, settled)
    }

    /// Settings > Vault > Folders > + (sheet) -> Cancel: a dismiss without saving, until the folders list's add
    /// button is hittable again.
    func test_cmp_cancelAddFolder() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        XCTAssertTrue(waitFor(app.buttons["VaultSettingsButton"], timeout: 10))
        app.buttons["VaultSettingsButton"].tap()
        XCTAssertTrue(waitFor(app.buttons["FoldersLabel"], timeout: 10))
        app.buttons["FoldersLabel"].tap()
        let add = app.buttons["AddItemButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "folders list")
        sleep(1)
        assertHitTarget(add, "AddItemButton (folders)")
        var shown: [Double] = []
        var settled: [Double] = []
        for _ in 0 ..< runs {
            add.tap()
            let cancel = app.buttons["CancelButton"].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 10), "add folder sheet is open")
            sleep(1)
            assertHitTarget(cancel, "CancelButton (folder)")
            let (s, t) = measure("cancel_add_folder", cancel, shown: { !cancel.exists }, settled: { add.isHittable })
            shown.append(s)
            settled.append(t)
        }
        report("cancel_add_folder", shown, settled)
        goTo(app, "My vault")
    }

    /// Search (field focused, text typed, 2000 rows filtered) -> the cancel X: until the vault home tile is hittable.
    func test_cmp_cancelSearch() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(waitFor(tile, timeout: 60))
        var shown: [Double] = []
        var settled: [Double] = []
        let cancel = app.buttons["VaultSearchCancel"]
        for _ in 0 ..< runs {
            focusSearch(app)
            typeSearch(app, "Perf 1")
            XCTAssertTrue(cancel.waitForExistence(timeout: 10), "search cancel shown")
            sleep(1)
            assertHitTarget(cancel, "VaultSearchCancel")
            let (s, t) = measure("cancel_search", cancel, shown: { tile.exists }, settled: { !cancel.exists && tile.isHittable })
            shown.append(s)
            settled.append(t)
        }
        report("cancel_search", shown, settled)
    }

    /// Category tile (2000 logins) -> the bottom bar's Vault button: until the vault home tile is hittable again.
    func test_cmp_vaultButtonFromGroup() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(waitFor(tile, timeout: 60))
        let rows = app.buttons.matching(identifier: "VaultListItemRowButton")
        let vault = app.buttons["BottomBarVaultButton"]
        var shown: [Double] = []
        var settled: [Double] = []
        for _ in 0 ..< runs {
            tile.tap()
            XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20))
            XCTAssertTrue(vault.waitForExistence(timeout: 5))
            sleep(1)
            assertHitTarget(vault, "BottomBarVaultButton")
            assertHitTarget(app.navigationBars.buttons.firstMatch, "navigation bar back button")
            let (s, t) = measure("vault_button_from_group", vault, shown: { tile.exists }, settled: { tile.frame.minX >= 15.5 && tile.isHittable })
            shown.append(s)
            settled.append(t)
        }
        report("vault_button_from_group", shown, settled)
    }

    // MARK: Helpers

    /// Taps `button` and returns (seconds until `shown()` holds, seconds until `settled()` also holds), polled every
    /// 10 ms from just before the tap.
    private func measure(_ name: String, _ button: XCUIElement, shown: () -> Bool, settled: () -> Bool) -> (Double, Double) {
        let start = Date()
        // Same clock as the app's `startup mark=... t=` and `touchprobe ... t=` lines (simulator = host clock).
        print("PASSY-MARK buttonTap \(name) t=\(String(format: "%.3f", start.timeIntervalSinceReferenceDate))")
        button.tap()
        var shownAt: Double?
        let deadline = start.addingTimeInterval(15)
        while Date() < deadline {
            if shownAt == nil, shown() { shownAt = Date().timeIntervalSince(start) }
            if shownAt != nil, settled() { break }
            usleep(10000)
        }
        let settledAt = Date().timeIntervalSince(start)
        XCTAssertNotNil(shownAt, "\(name): previous screen shown within 15 s of the tap")
        return (shownAt ?? 15, settledAt)
    }

    /// Prints both lines and checks the regression ceiling of the "shown" median.
    private func report(_ name: String, _ shown: [Double], _ settled: [Double]) {
        line("\(name)_shown", shown)
        line("\(name)_settled", settled)
        let median = shown.sorted()[shown.count / 2]
        XCTAssertTrue(smallTargets.isEmpty, "hit targets below 44 x 44 pt: \(smallTargets)")
        XCTAssertLessThan(median, shownCeiling, "\(name): median \(median) s from the tap until the previous screen is shown")
    }

    /// The control's hit area (its accessibility frame, which is the touch target of system and SwiftUI buttons) is
    /// at least 44 x 44 pt. Printed as `HITTARGET <name> w=... h=...`.
    private func assertHitTarget(_ element: XCUIElement, _ name: String) {
        guard element.exists else { return XCTFail("\(name) exists") }
        let frame = element.frame
        print("HITTARGET \(name) w=\(String(format: "%.1f", frame.width)) h=\(String(format: "%.1f", frame.height))")
        if min(frame.width, frame.height) < 43.5 { smallTargets[name] = frame.size }
    }
}
