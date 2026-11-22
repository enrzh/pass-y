import XCTest

/// iPad landscape screenshots. Never gating.
final class ShotsIPadLandscapeTests: PassYUITestCase {
    // MARK: iPad landscape (step 7)
    /// Rotates with `XCUIDevice.orientation`, then pauses at each stage and writes a marker file `/tmp/r6hold/<stage>`
    /// (the simulator shares the host's /tmp). `Scripts-passy/ipad_landscape_shots.sh` (a driver outside the test)
    /// takes a real `simctl io screenshot` of the rotated screen at each marker and removes it. No `sips` involved.
    /// Formerly `PassYUiR6ShotsTests.test_ipadLandscapeHold`.
    func test_landscapeHold() {
        let app = launchApp()
        ensureUnlockedVault(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        func hold(_ stage: String) {
            try? FileManager.default.createDirectory(atPath: "/tmp/r6hold", withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: "/tmp/r6hold/\(stage)", contents: Data())
            for _ in 0 ..< 40 where FileManager.default.fileExists(atPath: "/tmp/r6hold/\(stage)") { sleep(1) }
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
