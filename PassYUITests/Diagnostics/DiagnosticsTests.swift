import XCTest

/// Diagnostics, not part of any tier (run by name).
final class DiagnosticsTests: PassYUITestCase {
    // MARK: (a) single taps
    /// Diagnosis helper: prints the accessibility tree of the group list after one tile tap.
    /// Formerly `PassYUiR8Tests.test00_dumpGroupListTree`.
    func test_dumpGroupListTree() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["CategoryTile_login"].tap()
        sleep(4)
        print("TREE-BEGIN\n\(app.debugDescription)\nTREE-END")
        attach(app, "r8-00-group-list")
    }

    /// Diagnostic for the password finding: types into the secure password field of the add form slowly (one key at a
    /// time, with pauses) and fast (one `typeText`), and records the number of bullets after each step.
    /// Formerly `PassYUiR7ShotsTests.test_secureFieldTypingDiagnostic`.
    func test_secureFieldTypingDiagnostic() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PASSY_KNOWN_ISSUE_TESTS"] == "1",
                          "open finding: the add form keeps only the last typed character of a password; see README")
        let app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertTrue(openAdd(app, "Login"))
        let ok = app.alerts.buttons["OK"]
        if ok.waitForExistence(timeout: 3) { ok.tap() }
        let pw = app.secureTextFields["LoginPasswordEntry"]
        XCTAssertTrue(pw.waitForExistence(timeout: 10))
        pw.tap()
        var slow = [Int]()
        for ch in "abcdef" {
            pw.typeText(String(ch)); usleep(700_000)
            slow.append((pw.value as? String ?? "").count)
            print("R7DIAG after \(ch): value='\(pw.value as? String ?? "")' label='\(pw.label)'")
        }
        print("R7DIAG slow bullets: \(slow)")
        pw.typeText("ghijkl"); sleep(1)
        print("R7DIAG after fast typeText(6) bullets: \((pw.value as? String ?? "").count)")
        XCTAssertEqual(slow, [1, 2, 3, 4, 5, 6], "slow typing keeps every character")
        XCTAssertEqual((pw.value as? String ?? "").count, 12, "fast typing keeps every character")
    }
}
