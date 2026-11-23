import XCTest

/// Keystroke-loss probe (not part of a tier; run by name, `TEST_RUNNER_PASSY_PROBE_ROUNDS`, default 10). Types a
/// 21-character value into different fields, once key by key (reading the field after every key) and once as one
/// fast `typeText`, and prints one line per round:
/// `KEYPROBE field=<field> mode=<perkey|whole> round=<n> want=21 got=<count> firstLoss=<index|-1> focusLostAt=<index|-1> load=<1-min load>`.
/// The probe never retypes and never fails on a loss: it only measures.
final class KeystrokeProbeTests: PassYUITestCase {
    private let text = TestAccount.password   // 21 characters, no spaces
    private var rounds: Int { Int(ProcessInfo.processInfo.environment["PASSY_PROBE_ROUNDS"] ?? "") ?? 10 }

    private func count(_ field: XCUIElement) -> Int {
        guard let value = field.value as? String, value != (field.placeholderValue ?? "") else { return 0 }
        return value.count
    }

    private func clear(_ field: XCUIElement) {
        field.focus()
        for _ in 0 ..< 3 {
            let n = count(field)
            if n == 0 { return }
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: n))
        }
    }

    private func probe(_ name: String, _ field: () -> XCUIElement) {
        for round in 1 ... rounds {
            // Key by key.
            var f = field()
            clear(f)
            var firstLoss = -1, focusLostAt = -1
            for (index, ch) in text.enumerated() {
                f = field()
                f.typeText(String(ch))
                if firstLoss < 0, count(f) != index + 1 { firstLoss = index }
                if focusLostAt < 0, (f.value(forKey: "hasKeyboardFocus") as? Bool) != true { focusLostAt = index }
            }
            print("KEYPROBE field=\(name) mode=perkey round=\(round) want=\(text.count) got=\(count(field())) firstLoss=\(firstLoss) focusLostAt=\(focusLostAt) load=\(passYLoad())")
            // One fast typeText.
            f = field()
            clear(f)
            f.typeText(text)
            let got = count(field())
            let focused = (field().value(forKey: "hasKeyboardFocus") as? Bool) == true
            print("KEYPROBE field=\(name) mode=whole round=\(round) want=\(text.count) got=\(got) firstLoss=\(got == text.count ? -1 : got) focusLostAt=\(focused ? -1 : 0) load=\(passYLoad())")
        }
        clear(field())
    }

    /// The unlock screen's master password field (SecureField) and, revealed, the same field as a TextField.
    func test_probeUnlockField() {
        let first = launchApp()
        ensureUnlockedVault(first)
        first.terminate()
        let app = launchApp()
        let secure = app.secureTextFields["MasterPasswordEntry"]
        XCTAssertTrue(secure.waitForExistence(timeout: 60), "unlock screen")
        // Let the screen settle (the appeared effect focuses the field).
        _ = waitUntil(10) { (secure.value(forKey: "hasKeyboardFocus") as? Bool) == true }
        probe("unlock-secure") { app.secureTextFields["MasterPasswordEntry"] }
        app.buttons["PasswordVisibilityToggle"].tap()
        let plain = app.textFields["MasterPasswordEntry"]
        XCTAssertTrue(plain.waitForExistence(timeout: 5), "revealed field")
        probe("unlock-plain") { app.textFields["MasterPasswordEntry"] }
        app.buttons["PasswordVisibilityToggle"].tap()
        ensureUnlockedVault(app)
    }

    /// The bottom search bar (UIKit search field; the list filters after every key).
    func test_probeSearchField() {
        let app = launchApp()
        ensureUnlockedVault(app)
        focusSearch(app)
        probe("search") { app.searchFields.firstMatch }
    }

    /// The add-login form: the name (TextField) and the password (SecureField of the item form).
    func test_probeAddLoginForm() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        XCTAssertTrue(app.textFields["ItemNameEntry"].waitForExistence(timeout: 15), "add form")
        app.dismissNewLoginCard()
        probe("addform-name") { app.textFields["ItemNameEntry"] }
        probe("addform-password-secure") { app.secureTextFields["LoginPasswordEntry"] }
        // What the field really holds: type once more masked, then reveal it and read the plain value.
        let secure = app.secureTextFields["LoginPasswordEntry"]
        clear(secure)
        secure.typeText(text)
        let dots = count(secure)
        app.buttons["ViewPasswordButton"].firstMatch.tap()
        let plain = app.textFields["LoginPasswordEntry"]
        _ = plain.waitForExistence(timeout: 5)
        print("KEYPROBE field=addform-password-revealed mode=whole round=1 want=\(text.count) dots=\(dots) revealedCount=\(count(plain)) revealedEqual=\((plain.value as? String) == text) load=\(passYLoad())")
        _ = returnToRoot(app)
    }
}
