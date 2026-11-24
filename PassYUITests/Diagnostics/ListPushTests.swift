import XCTest

/// Diagnostics, not part of any tier (run by name): drives the pushes of group pages so a screen recording
/// (`simctl io recordVideo`) can show how the title, the item count and the rows appear. Prints `PUSH-MARK` lines with
/// wall clock times and samples the navigation bar (frame, static texts) right after each push and later.
final class ListPushTests: PassYUITestCase {
    func test_groupPushes() {
        let app = launchApp()
        ensureUnlockedVault(app)
        sleep(3)
        for (n, tile) in ["login", "login", "totp", "totp"].enumerated() {
            let button = app.buttons["CategoryTile_\(tile)"]
            for _ in 0 ..< 4 where !button.isHittable { app.swipeDown() }
            XCTAssertTrue(button.waitForExistence(timeout: 10), "tile \(tile)")
            print("PUSH-MARK \(n) \(tile) tap \(Date().timeIntervalSince1970)")
            button.tap()
            var samples = [String]()
            for i in 0 ..< 6 {
                let bar = app.navigationBars.firstMatch
                let texts = bar.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|")
                samples.append("t\(i) bar=\(bar.frame) texts=\(texts)")
                usleep(250_000)
            }
            print("PUSH-NAV \(n) \(tile)\n  " + samples.joined(separator: "\n  "))
            attach(app, "push-\(n)-\(tile)")
            sleep(1)
            back(app)
            sleep(2)
        }
    }
}
