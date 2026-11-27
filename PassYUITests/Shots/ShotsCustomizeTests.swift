import XCTest

/// Screenshots of Customize, of the vault home in three configurations (DEBUG launch preset `-PassYLayoutPreset`) and
/// of the long-press menu of a card, light and dark. Runs on the phone and the iPad simulator. Never gating; the last
/// launch restores the defaults.
final class ShotsCustomizeTests: PassYUITestCase {
    func test_customizeAndHomeConfigurations() {
        let configurations = [("default", "home-default"), ("filled", "home-filled"), ("minimal", "home-minimal"),
                              ("rows", "home-type-rows")]
        for mode in passYModes() {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            for (index, (preset, name)) in configurations.enumerated() {
                let app = launchApp(extraArguments: ["-PassYLayoutPreset", preset])
                ensureUnlockedVault(app)
                XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 15))
                sleep(1)
                shot(app, mode, 80 + index, name)
                if preset == "default" || preset == "filled" {
                    folderAsCard(app, mode, preset == "default" ? 84 : 85, "\(name)-folder-card")
                }
                if preset == "default" {
                    goTo(app, "Settings")
                    app.buttons["CustomizeSettingsButton"].tap()
                    XCTAssertTrue(app.descendants(matching: .any)["CustomizeCardColorsPicker"].waitForExistence(timeout: 10))
                    shot(app, mode, 79, "customize")
                    app.swipeUp(velocity: .slow)
                    shot(app, mode, 78, "customize-rows")
                    // Last: the long-press menu of a card (the app is terminated with the menu open).
                    goTo(app, "My vault")
                    XCTAssertTrue(app.buttons["CategoryTile_login"].waitForExistence(timeout: 10))
                    app.buttons["CategoryTile_login"].press(forDuration: 1.0)
                    sleep(1)
                    shot(app, mode, 77, "home-card-menu")
                }
                app.terminate()
            }
        }
        // Back to the defaults for whatever runs next.
        let app = launchApp(extraArguments: ["-PassYLayoutPreset", "default"])
        app.terminate()
        setPassYAppearance(.light)
    }

    /// Switches the first folder row to a card through its long-press menu (shot of the row menu, then of the home with
    /// the folder card). Nothing happens when the vault has no folder.
    private func folderAsCard(_ app: XCUIApplication, _ mode: String, _ n: Int, _ name: String) {
        let row = app.buttons.matching(NSPredicate(
            format: "identifier == 'VaultListItemRowButton' AND label CONTAINS 'Folder'",
        )).firstMatch
        let bar = app.searchFields.firstMatch
        for _ in 0 ..< 8 where !(row.exists && row.isHittable && row.frame.maxY <= bar.frame.minY - 4) {
            app.swipeUp(velocity: .slow)
        }
        guard row.exists else { return }
        row.press(forDuration: 1.0)
        sleep(1)
        shot(app, mode, n + 10, "home-row-menu")
        let asCard = app.buttons["Show as Card"]
        guard asCard.waitForExistence(timeout: 5) else { return }
        asCard.tap()
        for _ in 0 ..< 8 where !app.buttons["CategoryTile_login"].isHittable { app.swipeDown() }
        sleep(1)
        app.swipeUp(velocity: .slow)
        sleep(1)
        shot(app, mode, n, name)
    }
}
