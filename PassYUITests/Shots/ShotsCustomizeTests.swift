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
                if preset == "default" {
                    app.buttons["CategoryTile_login"].press(forDuration: 1.0)
                    sleep(1)
                    shot(app, mode, 77, "home-card-menu")
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
                    sleep(1)
                    goTo(app, "Settings")
                    app.buttons["CustomizeSettingsButton"].tap()
                    XCTAssertTrue(app.descendants(matching: .any)["CustomizeCardColorsPicker"].waitForExistence(timeout: 10))
                    shot(app, mode, 79, "customize")
                    app.swipeUp(velocity: .slow)
                    shot(app, mode, 78, "customize-rows")
                }
                app.terminate()
            }
        }
        // Back to the defaults for whatever runs next.
        let app = launchApp(extraArguments: ["-PassYLayoutPreset", "default"])
        app.terminate()
        setPassYAppearance(.light)
    }
}
