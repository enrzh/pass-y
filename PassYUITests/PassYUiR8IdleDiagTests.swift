import XCTest

/// Diagnosis (ui-r8): the first action after unlock sometimes waits 60 s for idle ("App animations complete notification
/// not received"). The app logs every running layer animation (`-passyDumpAnimations YES`); this test just waits.
final class PassYUiR8IdleDiagTests: XCTestCase {
    func test_idleAfterUnlock() {
        let app = launchApp(extraArguments: ["-passyDumpAnimations", "YES"])
        ensureUnlockedVault(app)
        _ = waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60)
        print("IDLEDIAG ready \(Date())")
        let start = Date()
        app.buttons["CategoryTile_login"].tap()
        print("IDLEDIAG first tile tap took \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
        sleep(10)
    }
}
