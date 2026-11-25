import XCTest

/// Screenshots of Customize and of the vault home in three configurations (DEBUG launch preset
/// `-PassYLayoutPreset`), light and dark. Runs on the phone and the iPad simulator. Never gating; the last launch
/// restores the defaults.
final class ShotsCustomizeTests: PassYUITestCase {
    func test_customizeAndHomeConfigurations() {
        let configurations = [("default", "home-default"), ("wide", "home-wide-monochrome"), ("minimal", "home-minimal"),
                              ("list", "home-compact-list")]
        for mode in passYModes() {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            for (index, (preset, name)) in configurations.enumerated() {
                let app = launchApp(extraArguments: ["-PassYLayoutPreset", preset])
                ensureUnlockedVault(app)
                XCTAssertTrue(app.buttons["AddItemFloatingActionButton"].waitForExistence(timeout: 15))
                sleep(1)
                shot(app, mode, 80 + index, name)
                if preset == "default" {
                    XCTAssertTrue(openAvatarMenu(app))
                    menuButton(app, id: "ProfileMenuCustomizeButton", label: "Customize home…").tap()
                    XCTAssertTrue(app.switches["CustomizeTileToggle_login"].waitForExistence(timeout: 10))
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
