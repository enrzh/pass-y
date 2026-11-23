import XCTest

/// iPad (own simulator): the avatar-menu shell portrait and landscape, main screens light and dark.
final class IPadTests: PassYUITestCase {
    /// iPad shots in the simulator's current appearance, portrait and landscape (no sidebar: avatar menu shell).
    /// Formerly `PassYUiR5ShotsTests.test_ipadShell`.
    func test_shellPortraitAndLandscape() {
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let app = launchApp()
        ensureUnlockedVault(app)
        for (name, orientation) in [("portrait", UIDeviceOrientation.portrait), ("landscape", UIDeviceOrientation.landscapeLeft)] {
            XCUIDevice.shared.orientation = orientation
            sleep(2)
            func take(_ n: Int, _ what: String) {
                if name == "portrait" { shot(app, n, "ipad-\(name)-\(what)") } else { screenShot(n, "ipad-\(name)-\(what)") }
            }
            take(name == "portrait" ? 1 : 10, "home")
            let tile = app.buttons["CategoryTile_login"]
            if tile.waitForExistence(timeout: 5) {
                tile.tap(); sleep(2)
                take(name == "portrait" ? 2 : 11, "list")
                let row = app.buttons["VaultListItemRowButton"].firstMatch
                if row.waitForExistence(timeout: 5) {
                    row.tap(); sleep(2)
                    take(name == "portrait" ? 3 : 12, "detail")
                    closeSheet(app)
                    let close = app.buttons["Close"].firstMatch
                    if close.exists, close.isHittable { close.tap(); sleep(1) }
                }
                let back = app.navigationBars.buttons.firstMatch
                if back.exists, back.isHittable { back.tap(); sleep(1) }
            }
            goTo(app, "Settings"); sleep(2)
            take(name == "portrait" ? 4 : 13, "settings")
            goTo(app, "My vault"); sleep(1)
        }
        XCUIDevice.shared.orientation = .portrait
    }

    /// iPad: vault, item view/edit, send, settings (run with an iPad destination).
    /// Formerly `PassYUiR4ShotsTests.test_ipad`.
    func test_mainScreensLightAndDark() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            sleep(2)
            shot(app, mode, 80, "ipad-vault")
            let tile = app.buttons["CategoryTile_login"]
            if tile.waitForExistence(timeout: 5) {
                tile.tap(); sleep(2)
                shot(app, mode, 81, "ipad-item-list")
                let row = app.buttons["VaultListItemRowButton"].firstMatch
                if row.waitForExistence(timeout: 5) {
                    row.tap(); sleep(2)
                    shot(app, mode, 82, "ipad-item-view")
                    let edit = app.buttons["Edit"].firstMatch
                    if edit.exists { edit.tap(); sleep(2); shot(app, mode, 83, "ipad-item-edit"); cancelOrClose(app); discardIfAsked(app) }
                    cancelOrClose(app)
                }
                let back = app.navigationBars.buttons.firstMatch
                if back.waitForExistence(timeout: 5) { back.tap(); sleep(1) }
            }
            goTo(app, "Send"); sleep(2)
            shot(app, mode, 84, "ipad-send")
            goTo(app, "Settings"); sleep(2)
            shot(app, mode, 85, "ipad-settings")
            app.terminate()
        }
        setPassYAppearance(.light)
    }
}
