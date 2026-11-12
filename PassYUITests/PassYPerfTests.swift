import XCTest

/// Wall-clock measurements against a large throwaway vault (see Scripts-passy/vaultwarden/seed_ciphers.py).
/// Prints `PERF <name> <seconds>` lines (3 iterations each) so before/after runs can be compared.
final class PassYPerfTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func report(_ name: String, _ values: [Double]) {
        let sorted = values.sorted()
        print("PERF \(name) median=\(String(format: "%.2f", sorted[sorted.count / 2])) all=\(values.map { String(format: "%.2f", $0) })")
    }

    func test_perf_unlockToVault() {
        var values: [Double] = []
        let first = launchApp()
        ensureUnlockedVault(first)
        for _ in 0 ..< 3 {
            first.terminate()
            let app = launchApp()
            let pw = app.secureTextFields["MasterPasswordEntry"]
            XCTAssertTrue(waitFor(pw))
            pw.tap(); pw.typeText(TestAccount.password)
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

    func test_perf_search() {
        let app = launchApp()
        ensureUnlockedVault(app)
        _ = waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60)
        var values: [Double] = []
        for _ in 0 ..< 3 {
            let search = app.searchFields.firstMatch
            search.tap(); sleep(1)
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
}
