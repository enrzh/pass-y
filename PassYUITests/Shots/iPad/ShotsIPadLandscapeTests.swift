import XCTest

/// iPad landscape screenshots. Never gating.
final class ShotsIPadLandscapeTests: PassYUITestCase {
    /// Rotates with `XCUIDevice.orientation`, then pauses at each stage: it attaches a whole-screen shot and, when a
    /// driver runs (`TEST_RUNNER_PASSY_HOLD_DIR`, the chain's own scratch directory instead of the former shared
    /// `/tmp/r6hold`), writes a marker file `<dir>/<stage>`; `Scripts-passy/ipad_landscape_shots.sh` takes a real
    /// `simctl io screenshot` of the rotated screen at each marker and removes it. The orientation is reset in a
    /// teardown block, also after a failure.
    /// Formerly `PassYUiR6ShotsTests.test_ipadLandscapeHold`.
    func test_landscapeHold() {
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let app = launchApp()
        ensureUnlockedVault(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        let holdDir = ProcessInfo.processInfo.environment["PASSY_HOLD_DIR"]
        func hold(_ stage: String) {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "\(tag)-ipad-landscape-\(stage)-screen"; shot.lifetime = .keepAlways; add(shot)
            guard let holdDir else { return }
            try? FileManager.default.createDirectory(atPath: holdDir, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: "\(holdDir)/\(stage)", contents: Data())
            for _ in 0 ..< 40 where FileManager.default.fileExists(atPath: "\(holdDir)/\(stage)") { sleep(1) }
        }
        hold("home")
        let tile = app.buttons["CategoryTile_login"]
        if tile.waitForExistence(timeout: 5) {
            tile.tap(); sleep(2)
            hold("list")
            let row = app.buttons["VaultListItemRowButton"].firstMatch
            if row.waitForExistence(timeout: 5) {
                row.tap(); sleep(2)
                hold("detail")
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
