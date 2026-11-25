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
            let (s, t) = measure("close_item_view", close, edge: 21, shown: { !close.exists }, settled: { row.isHittable })
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
            let save = app.buttons["SaveButton"].firstMatch
            assertHitTarget(save, "SaveButton")
            if shown.isEmpty {
                // Save on the empty form, tapped 21 pt left of its center: the validation alert proves the touch hit.
                edgeTap(save, -21)
                let alert = app.alerts.firstMatch
                XCTAssertTrue(alert.waitForExistence(timeout: 5), "Save reacts to a tap 21 pt beside its center")
                alert.buttons.firstMatch.tap()
                XCTAssertTrue(waitForDisappearance(of: alert, timeout: 5))
            }
            let (s, t) = measure("cancel_add_item", cancel, edge: 21, shown: { !cancel.exists }, settled: { tile.isHittable })
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
            edgeTap(add, -21) // 21 pt beside the center: the touch target is at least 42 pt wide
            let cancel = app.buttons["CancelButton"].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 10), "add folder sheet is open")
            sleep(1)
            assertHitTarget(cancel, "CancelButton (folder)")
            let (s, t) = measure("cancel_add_folder", cancel, edge: 21, shown: { !cancel.exists }, settled: { add.isHittable })
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
            let (s, t) = measure("cancel_search", cancel, edge: -21, shown: { tile.exists }, settled: { !cancel.exists && tile.isHittable })
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
            let (s, t) = measure("vault_button_from_group", vault, edge: -21, shown: { tile.exists }, settled: { tile.frame.minX >= 15.5 && tile.isHittable })
            shown.append(s)
            settled.append(t)
        }
        report("vault_button_from_group", shown, settled)
    }

    // MARK: Helpers

    /// Taps `button` `edge` points right (negative: left) of its center (so every run also proves a touch target of
    /// at least 2 x |edge| pt) and returns (seconds until `shown()` holds, seconds until `settled()` also holds),
    /// polled every 10 ms from just before the tap.
    private func measure(
        _ name: String,
        _ button: XCUIElement,
        edge: CGFloat,
        shown: () -> Bool,
        settled: () -> Bool,
    ) -> (Double, Double) {
        let start = Date()
        // Same clock as the app's `startup mark=... t=` and `touchprobe ... t=` lines (simulator = host clock).
        print("PASSY-MARK buttonTap \(name) t=\(String(format: "%.3f", start.timeIntervalSinceReferenceDate))")
        edgeTap(button, edge)
        var shownAt: Double?
        // 15 s from the end of the tap call (XCUITest's idle wait inside the tap can be long on a loaded machine).
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if shownAt == nil, shown() { shownAt = Date().timeIntervalSince(start) }
            if shownAt != nil, settled() { break }
            usleep(10000)
        }
        let settledAt = Date().timeIntervalSince(start)
        XCTAssertNotNil(shownAt, "\(name): previous screen shown within 15 s of the tap \(edge) pt beside the center")
        return (shownAt ?? 15, settledAt)
    }

    /// Taps `element` `dx` points beside its center.
    private func edgeTap(_ element: XCUIElement, _ dx: CGFloat) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: dx, dy: 0)).tap()
    }

    /// Prints both lines and checks the regression ceiling of the "shown" median.
    private func report(_ name: String, _ shown: [Double], _ settled: [Double]) {
        line("\(name)_shown", shown)
        line("\(name)_settled", settled)
        let median = shown.sorted()[shown.count / 2]
        XCTAssertLessThan(median, shownCeiling, "\(name): median \(median) s from the tap until the previous screen is shown")
    }

    /// Prints the control's accessibility frame (`HITTARGET <name> w=... h=...`). Information only: a navigation bar
    /// item's touch target is larger than its glass frame (UIKit), so the edge taps of `measure` are the check.
    private func assertHitTarget(_ element: XCUIElement, _ name: String) {
        guard element.exists else { return XCTFail("\(name) exists") }
        let frame = element.frame
        print("HITTARGET \(name) w=\(String(format: "%.1f", frame.width)) h=\(String(format: "%.1f", frame.height))")
    }
}
