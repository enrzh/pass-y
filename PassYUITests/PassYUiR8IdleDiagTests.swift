import XCTest

/// Diagnosis (ui-r8): where does the XCUITest "wait for idle" stall (60 s per action) come from? Measures the duration of
/// simple actions in several states of a large vault, with and without the stack poll timer.
final class PassYUiR8IdleDiagTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func timed(_ label: String, _ block: () -> Void) {
        let start = Date()
        block()
        print("IDLEDIAG \(label) \(String(format: "%.2f", Date().timeIntervalSince(start))) s")
    }

    private func scenario(_ extra: [String]) {
        let app = launchApp(extraArguments: extra)
        ensureUnlockedVault(app)
        _ = waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch, timeout: 60)
        let tag = extra.isEmpty ? "poll" : "nopoll"
        for i in 0 ..< 3 { timed("\(tag) home tap title \(i)") { app.staticTexts["My vault"].firstMatch.tap() } }
        timed("\(tag) focus search") { app.searchFields.firstMatch.tap() }
        timed("\(tag) type P") { app.typeText("P") }
        timed("\(tag) type e") { app.typeText("e") }
        timed("\(tag) type rf") { app.typeText("rf") }
        timed("\(tag) delete x3") { app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3)) }
        if app.buttons["VaultSearchCancel"].exists { timed("\(tag) cancel") { app.buttons["VaultSearchCancel"].tap() } }
        timed("\(tag) swipe up") { app.swipeUp() }
    }

    func test_idle_withPoll() { scenario([]) }
    func test_idle_withoutPoll() { scenario(["-passyDisableStackPoll", "YES"]) }
}
