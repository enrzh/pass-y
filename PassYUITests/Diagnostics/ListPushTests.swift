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

    /// Screenshots of the list screens (home, group list, swipe actions, search results, Send) as attachments.
    func test_listShots() {
        let app = launchApp()
        ensureUnlockedVault(app)
        sleep(2)
        attachUnchecked(app, "list-01-home")
        app.swipeUp(); sleep(1)
        attachUnchecked(app, "list-02-home-scrolled")
        app.swipeDown(); app.swipeDown(); sleep(1)
        app.buttons["CategoryTile_login"].tap(); sleep(2)
        attachUnchecked(app, "list-03-logins")
        let row = app.buttons.matching(identifier: "VaultListItemRowButton").element(boundBy: 1)
        row.swipeLeft(); sleep(1)
        attachUnchecked(app, "list-04-logins-swipe")
        row.swipeRight(); sleep(1)
        focusSearch(app)
        typeSearch(app, "Perf")
        sleep(2)
        attachUnchecked(app, "list-05-group-search")
        let cancel = app.buttons["VaultSearchCancel"]
        if cancel.exists { cancel.tap() }
        sleep(1)
        back(app)
        focusSearch(app)
        typeSearch(app, "Perf")
        sleep(2)
        attachUnchecked(app, "list-06-home-search")
        if cancel.exists { cancel.tap() }
        sleep(1)
        open(app, "Send")
        sleep(2)
        attachUnchecked(app, "list-07-send")
    }
}
