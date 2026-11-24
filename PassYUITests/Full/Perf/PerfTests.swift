import XCTest

/// Wall-clock measurements against the 2000 item perf account (`seed_ciphers.py 2000`, PASSY_EMAIL=passy-perf@example.test). Prints `PERF <name> ...`.
final class PerfTests: PassYUITestCase {
    /// Formerly `PassYPerfTests.test_perf_unlockToVault`.
    func test_perf_unlockToVault() {
        var values: [Double] = []
        let first = launchApp()
        ensureUnlockedVault(first)
        for _ in 0 ..< 3 {
            first.terminate()
            let app = launchApp()
            let pw = app.secureTextFields["MasterPasswordEntry"]
            XCTAssertTrue(waitFor(pw))
            pw.replaceText(TestAccount.password) // verified typing: a dropped character would only show "Invalid master password"
            let start = Date()
            app.buttons["UnlockVaultButton"].tap()
            XCTAssertTrue(waitFor(app.buttons["AddItemFloatingActionButton"], timeout: 60))
            // wait until the list itself is populated
            XCTAssertTrue(waitFor(app.staticTexts["Perf Item 0000"].exists ? app.staticTexts["Perf Item 0000"] : app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60))
            values.append(Date().timeIntervalSince(start))
            app.terminate()
        }
        report("unlock_to_vault", values)
    }

    /// Formerly `PassYPerfTests.test_perf_scroll`.
    func test_perf_scroll() {
        let app = launchApp()
        ensureUnlockedVault(app)
        _ = waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60)
        var values: [Double] = []
        for _ in 0 ..< 3 {
            let start = Date()
            for _ in 0 ..< 15 { app.swipeUp(velocity: .fast) }
            for _ in 0 ..< 15 { app.swipeDown(velocity: .fast) }
            values.append(Date().timeIntervalSince(start))
        }
        report("scroll_30_fast_swipes", values)
    }

    /// Formerly `PassYPerfTests.test_perf_search`.
    func test_perf_search() {
        let app = launchApp()
        ensureUnlockedVault(app)
        _ = waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60)
        var values: [Double] = []
        for _ in 0 ..< 3 {
            focusSearch(app)
            let start = Date()  // includes the 120 ms/char typing delay; compare before/after only
            for ch in "Perf Item 1999" { app.typeText(String(ch)); usleep(120_000) }
            let hit = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Perf Item 1999")).firstMatch
            XCTAssertTrue(waitFor(hit, timeout: 30))
            values.append(Date().timeIntervalSince(start))
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
            if app.buttons["Clear text"].exists { app.buttons["Clear text"].tap() }
            sleep(1)
        }
        report("search_exact_1999", values)
    }

    /// XCTest metrics (clock, CPU time, peak memory) while scrolling a large vault; XCTest prints the averages in the log.
    /// Formerly `PassYPerfTests.test_perf_scrollMetrics`.
    func test_perf_scrollMetrics() {
        let app = launchApp()
        ensureUnlockedVault(app)
        _ = waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60)
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            for _ in 0 ..< 5 { app.swipeUp(velocity: .fast) }
            for _ in 0 ..< 5 { app.swipeDown(velocity: .fast) }
        }
    }

    /// ui-r8: the app signposts (`PassYPerf`): tap-to-push, measured by `XCTOSSignpostMetric`
    /// together with the wall clock. A single tap must open the item list page (asserted within 1 s).
    /// Formerly `PassYPerfTests.test_perf_tapToPush_signposts`.
    func test_perf_tapToPush_signposts() {
        let app = launchApp()
        ensureUnlockedVault(app)
        _ = waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60)
        let options = XCTMeasureOptions(); options.iterationCount = 5
        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTOSSignpostMetric(subsystem: "de.aiity.passy", category: "perf", name: "TapToPush"),
            // No `VaultListLoad` here any more: that interval came from the vault home reloading its whole list on every
            // back, which it no longer does (the stream keeps running, `PerfUnlockAndBackTests.test_cmp_backFromGroup`).
        ]
        measure(metrics: metrics, options: options) {
            app.buttons["CategoryTile_login"].tap()
            XCTAssertTrue(app.buttons["VaultListItemRowButton"].firstMatch.waitForExistence(timeout: 1.0), "one tap opens the list within 1 s")
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["CategoryTile_login"].waitForExistence(timeout: 2.0))
        }
    }

    /// ui-r8: 30 single taps on the blank part of a row open the item sheet each time (1 s budget each).
    /// Formerly `PassYPerfTests.test_perf_singleTapOpensItem_2000`.
    func test_perf_singleTapOpensItem_2000() {
        let app = launchApp()
        ensureUnlockedVault(app)
        _ = waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60)
        app.buttons["CategoryTile_login"].tap()
        let row = app.buttons["VaultListItemRowButton"].firstMatch
        XCTAssertTrue(waitFor(row))
        var durations: [Double] = []
        for index in 0 ..< 30 {
            let start = Date()
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)).tap()
            let opened = app.buttons["Close"].firstMatch.waitForExistence(timeout: 1.0)
            durations.append(Date().timeIntervalSince(start))
            XCTAssertTrue(opened, "tap \(index): item opened within 1 s")
            if opened { app.buttons["Close"].firstMatch.tap() }
            XCTAssertTrue(waitFor(row, timeout: 3))
        }
        report("single_tap_opens_item", durations)
    }
}
