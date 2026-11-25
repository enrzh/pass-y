import XCTest

/// The verification codes page (PassYDesign): code rows with name, account, the code and a live countdown; a tap
/// copies the code and shows the "copied" toast. Uses the seeded GitHub login (authenticator key).
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

    /// The seconds left in a code row label ("..., 14 seconds left").
    private func secondsLeft(_ label: String) -> Int? {
        guard let range = label.range(of: #"(\d+) seconds? left"#, options: .regularExpression) else { return nil }
        return Int(label[range].prefix { $0.isNumber })
    }
}
