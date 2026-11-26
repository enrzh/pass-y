import XCTest

/// The verification codes page (PassYDesign): code rows with name, account and the code, one shared live countdown for
/// the page; a tap copies the code and shows the "copied" toast. Uses the seeded GitHub login (authenticator key) and
/// the seeded Perf Items with authenticator keys.
final class VerificationCodesTests: PassYUITestCase {
    func test_tapCopiesCodeWithToastAndCountdownRuns() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_totp"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "verification codes tile")
        tile.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier == 'VaultListItemRowButton' AND label BEGINSWITH 'GitHub'"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the GitHub code row")
        attach(app, "codes-page")

        // The label reads name, account, the code digit by digit and the seconds left (from the page clock).
        let first = row.label
        XCTAssertTrue(first.contains("octo@example.test"), "account in '\(first)'")
        XCTAssertNotNil(first.range(of: #"Code (\d ){5}\d"#, options: .regularExpression), "six spaced digits in '\(first)'")
        let seconds = secondsLeft(first)
        XCTAssertNotNil(seconds, "seconds left in '\(first)'")
        XCTAssertTrue((1 ... 30).contains(seconds ?? 0), "seconds left in range: \(String(describing: seconds))")
        // The countdown runs: within 3 s the seconds left change.
        waitUntil(4) { self.secondsLeft(row.label) != seconds }
        XCTAssertNotEqual(secondsLeft(row.label), seconds, "the countdown advances ('\(row.label)')")

        // A tap copies (no item view opens) and shows the copied toast.
        row.tap()
        let toast = app.descendants(matching: .any)["ToastElement"].firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "copied toast after the tap")
        XCTAssertTrue(toast.label.localizedCaseInsensitiveContains("copied"), "toast text '\(toast.label)'")
        attach(app, "codes-copied-toast")
        XCTAssertFalse(app.buttons["EditItemButton"].exists, "the tap copied instead of opening the item")
        XCTAssertTrue(row.exists, "still on the codes page")

        // The context menu offers Copy, View and Edit.
        XCTAssertTrue(waitForDisappearance(of: toast, timeout: 10), "toast goes away")
        row.press(forDuration: 1.2)
        let copy = app.buttons["Copy"].exists ? app.buttons["Copy"] : app.menuItems["Copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5), "context menu offers Copy")
        XCTAssertTrue(app.buttons["Edit"].exists || app.menuItems["Edit"].exists, "context menu offers Edit")
        attach(app, "codes-context-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.2)).tap()
        waitUntil(5) { !app.buttons["Copy"].exists && !app.menuItems["Copy"].exists }
    }

    /// One shared countdown ring instead of one per row: beside the large title while it is shown, at the trailing
    /// end of the navigation bar once the title has collapsed, back beside the title after scrolling up. It reads the
    /// seconds left to VoiceOver and counts down. Light and dark (screenshots for both title states). The seeded test
    /// account has 13 codes (Perf Item 0011 with a 60 s period), so the page scrolls.
    func test_sharedRingInBothTitleStates() {
        for mode in passYModes() {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            let tile = app.buttons["CategoryTile_totp"]
            for _ in 0 ..< 4 where !tile.isHittable { app.swipeDown() }
            XCTAssertTrue(tile.waitForExistence(timeout: 10), "verification codes tile")
            tile.tap()
            let large = app.descendants(matching: .any)["SharedCountdownLarge"]
            let bar = app.descendants(matching: .any)["SharedCountdownBar"]
            XCTAssertTrue(large.waitForExistence(timeout: 10), "\(mode): the shared ring beside the large title")
            XCTAssertFalse(bar.exists, "\(mode): no ring in the bar while the large title is shown")
            let title = app.navigationBars.staticTexts["Verification codes"].firstMatch
            XCTAssertTrue(title.exists, "\(mode): large title")
            let width = app.windows.firstMatch.frame.width
            XCTAssertGreaterThan(large.frame.midX, width * 0.75, "\(mode): ring at the trailing end (\(large.frame))")
            XCTAssertGreaterThan(large.frame.minX, title.frame.maxX, "\(mode): ring right of the title (\(title.frame))")
            XCTAssertLessThan(abs(large.frame.midY - title.frame.maxY), 34, "\(mode): ring beside the title (\(large.frame) / \(title.frame))")
            let seconds = secondsLeft(large.label)
            XCTAssertNotNil(seconds, "\(mode): the ring reads the seconds left ('\(large.label)')")
            waitUntil(4) { self.secondsLeft(large.label) != seconds }
            XCTAssertNotEqual(secondsLeft(large.label), seconds, "\(mode): the shared ring counts down")
            attach(app, "codes-shared-ring-large-\(mode)")

            // Collapse the title: the ring moves into the bar.
            app.swipeUp()
            XCTAssertTrue(bar.waitForExistence(timeout: 5), "\(mode): the ring in the bar once the title collapsed")
            XCTAssertTrue(waitForDisappearance(of: large, timeout: 5), "\(mode): no ring beside the collapsed title")
            let navBar = app.navigationBars.firstMatch.frame
            XCTAssertTrue(navBar.contains(CGPoint(x: bar.frame.midX, y: bar.frame.midY)), "\(mode): ring inside the bar (\(bar.frame) / \(navBar))")
            XCTAssertGreaterThan(bar.frame.midX, width * 0.75, "\(mode): ring at the trailing end of the bar")
            XCTAssertNotNil(secondsLeft(bar.label), "\(mode): the bar ring reads the seconds left ('\(bar.label)')")
            sleep(1)
            attach(app, "codes-shared-ring-collapsed-\(mode)")

            // Back to the top: the ring returns beside the large title.
            app.swipeDown(); app.swipeDown()
            XCTAssertTrue(large.waitForExistence(timeout: 5), "\(mode): the ring returns beside the large title")
            XCTAssertTrue(waitForDisappearance(of: bar, timeout: 5), "\(mode): the bar ring goes away again")
            app.terminate()
        }
        setPassYAppearance(.light)
    }

    /// The seconds left in a code row label ("..., 14 seconds left").
    private func secondsLeft(_ label: String) -> Int? {
        guard let range = label.range(of: #"(\d+) seconds? left"#, options: .regularExpression) else { return nil }
        return Int(label[range].prefix { $0.isNumber })
    }
}
