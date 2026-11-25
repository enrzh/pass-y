import XCTest

/// Customize (on-device layout preferences): hide a tile, reorder tiles, collapse a section, relaunch, and the choices
/// are still there; what is hidden stays reachable under "More". The session is shared with the other Full classes,
/// so the defaults are restored in a teardown block (Settings › Customize › Reset to defaults).
final class CustomizeTests: PassYUITestCase {
    /// The SSH key tile: no other UI test uses it.
    private let hiddenTile = "sshKey"

    func test_hideReorderCollapsePersistAcrossRelaunch() {
        var app = launchApp()
        ensureUnlockedVault(app)
        addTeardownBlock { [unowned self] in resetLayout(app) }
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_\(hiddenTile)"], timeout: 10), "SSH key tile at the defaults")
        XCTAssertFalse(app.buttons["SectionExpandButton_PassYMore"].exists, "no More section at the defaults")

        // Open Customize from the avatar menu ("Customize home…").
        XCTAssertTrue(openAvatarMenu(app), "avatar menu opens")
        menuButton(app, id: "ProfileMenuCustomizeButton", label: "Customize home…").tap()
        XCTAssertTrue(waitFor(control(app, "CustomizeTileLayoutPicker"), timeout: 10), "Customize screen opens")
        attach(app, "customize-screen")

        // Hide the SSH key tile (the tile list is below the preview).
        let tileSwitch = control(app, "CustomizeTileToggle_\(hiddenTile)")
        scrollTo(tileSwitch, in: app)
        if !tileSwitch.exists { print("CUSTOMIZE-TREE\n\(app.debugDescription)") }
        XCTAssertTrue(tileSwitch.exists, "SSH key switch")
        toggle(tileSwitch)
        XCTAssertEqual(tileSwitch.value as? String, "0", "SSH key switch is off")

        // Reorder: drag Verification codes below Login.
        let codes = control(app, "CustomizeTileToggle_totp")
        let login = control(app, "CustomizeTileToggle_login")
        scrollTo(codes, in: app)
        app.buttons["CustomizeReorderButton"].firstMatch.tap()
        let handle = reorderHandle(in: app, near: codes)
        XCTAssertTrue(handle.exists, "drag handle of Verification codes")
        let target = reorderHandle(in: app, near: login)
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.2)))
        sleep(1)
        XCTAssertGreaterThan(codes.frame.minY, login.frame.minY, "Verification codes now below Login")
        app.buttons["CustomizeReorderButton"].firstMatch.tap()
        attach(app, "customize-changed")

        // Back to the home: the tile is gone, the order changed, More holds the hidden tile.
        goTo(app, "My vault")
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"], timeout: 10))
        XCTAssertFalse(app.buttons["CategoryTile_\(hiddenTile)"].exists, "SSH key tile hidden from the home")
        assertLoginBeforeCodes(app)
        let more = app.buttons["SectionExpandButton_PassYMore"]
        scrollTo(more, in: app)
        XCTAssertTrue(more.exists, "More section for the hidden tile")
        XCTAssertTrue(sshKeyRow(app).exists, "the hidden tile is a row under More")

        // Collapse More with its chevron.
        more.tap()
        XCTAssertTrue(waitForDisappearance(of: sshKeyRow(app), timeout: 5), "More collapsed")
        XCTAssertEqual(more.value as? String, "Collapsed")
        attach(app, "home-customized")

        // Relaunch: everything persisted.
        app.terminate()
        app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"], timeout: 15))
        XCTAssertFalse(app.buttons["CategoryTile_\(hiddenTile)"].exists, "tile still hidden after the relaunch")
        assertLoginBeforeCodes(app)
        let moreAgain = app.buttons["SectionExpandButton_PassYMore"]
        scrollTo(moreAgain, in: app)
        XCTAssertEqual(moreAgain.value as? String, "Collapsed", "More still collapsed after the relaunch")
        XCTAssertFalse(sshKeyRow(app).exists)

        // Reachability: expand More and open the hidden type.
        moreAgain.tap()
        let row = sshKeyRow(app)
        XCTAssertTrue(waitFor(row, timeout: 5), "SSH key row under More")
        row.tap()
        XCTAssertTrue(waitFor(app.navigationBars.staticTexts["SSH key"].firstMatch, timeout: 10)
            || waitFor(app.staticTexts["SSH key"].firstMatch, timeout: 2), "the SSH key page opens from More")
        attach(app, "more-opens-type")
        goTo(app, "My vault")
    }

    // MARK: Helpers

    /// A Customize control by identifier, whatever element type the system gives the toggle row.
    private func control(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The SSH key group row under More.
    private func sshKeyRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'VaultListItemRowButton' AND label BEGINSWITH 'SSH key'"))
            .firstMatch
    }

    /// Login comes before Verification codes in the tile grid (reading order).
    private func assertLoginBeforeCodes(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let login = app.buttons["CategoryTile_login"].frame
        let codes = app.buttons["CategoryTile_totp"]
        guard codes.exists else { return } // no verification codes in the vault: no tile to order
        let frame = codes.frame
        let loginFirst = login.minY < frame.minY - 1 || (abs(login.minY - frame.minY) <= 1 && login.minX < frame.minX)
        XCTAssertTrue(loginFirst, "Login (\(login)) before Verification codes (\(frame))", file: file, line: line)
    }

    /// Flips a switch (taps its trailing control, not the label).
    private func toggle(_ element: XCUIElement) {
        let before = element.value as? String
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        sleep(1)
        if element.value as? String == before {
            element.switches.firstMatch.exists ? element.switches.firstMatch.tap() : element.tap()
        }
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

    /// Scrolls until the element is hittable (at most 6 swipes).
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 6 where !(element.exists && element.isHittable) {
            app.swipeUp(velocity: .slow)
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
        guard waitFor(control(app, "CustomizeTileLayoutPicker"), timeout: 10) else { return }
        scrollTo(reset, in: app)
        if reset.exists, reset.isEnabled { reset.tap() }
        goTo(app, "My vault")
    }
}
