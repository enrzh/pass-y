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

    private func probe(_ name: String, text: String? = nil, rounds: Int? = nil, _ field: () -> XCUIElement) {
        let text = text ?? self.text
        for round in 1 ... (rounds ?? self.rounds) {
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

    /// The unlock field right after a cold launch, typed the way the tests type it (`focus()` then one `typeText`, no
    /// settle wait), alternating the master password (one double letter, "ss" at 2-3) and a value of the same length
    /// without double letters. Prints the missing positions (indexes only):
    /// `KEYPROBE field=unlock-cold value=<password|nodouble> round=<n> want=21 got=<count> lost=[...] appFocus=<bool>`.
    /// Tells a timing loss (same early positions for both values) from a dropped repeated key (only "ss").
    func test_probeColdUnlockTyping() {
        let first = launchApp()
        ensureUnlockedVault(first)
        let values = [("password", text), ("nodouble", "PasxY-Test-Only-2026!")]
        for round in 1 ... rounds * 2 {
            let (name, value) = values[round % 2]
            PassYSession.app?.terminate()
            // `TEST_RUNNER_PASSY_PROBE_APPEARANCE=toggle`: switch light/dark before every launch, as the light/dark
            // tests do (device appearance and the app's forced style); `system`: only the device appearance.
            switch ProcessInfo.processInfo.environment["PASSY_PROBE_APPEARANCE"] {
            case "toggle": setPassYAppearance(round % 4 < 2 ? .dark : .light)
            case "system": XCUIDevice.shared.appearance = round % 4 < 2 ? .dark : .light
            default: break
            }
            let app = launchApp()
            let secure = app.secureTextFields["MasterPasswordEntry"]
            XCTAssertTrue(secure.waitForExistence(timeout: 60), "unlock screen")
            secure.focus()
            let appFocus = PassYTyping.lastFocusWasTheApps
            secure.typeText(value)
            let got = count(secure)
            let lost = got == value.count ? "[]" : secure.lostKeystrokePositions(value)
            print("KEYPROBE field=unlock-cold value=\(name) appearance=\(XCUIDevice.shared.appearance == .dark ? "dark" : "light") round=\(round) want=\(value.count) got=\(got) lost=\(lost) appFocus=\(appFocus) load=\(passYLoad())")
        }
        if ProcessInfo.processInfo.environment["PASSY_PROBE_APPEARANCE"] != nil { setPassYAppearance(.light) }
        let app = PassYSession.app ?? launchApp()
        ensureUnlockedVault(app)
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
        app.buttons["ViewPasswordButton"].firstMatch.tap()
        probeTotp(app)
        _ = returnToRoot(app)
    }

    /// The masked authenticator key of the add-login form (16 characters), then revealed.
    private func probeTotp(_ app: XCUIApplication) {
        let key = "JBSWY3DPEHPK3PXP"
        let totp = app.secureTextFields["LoginTotpEntry"]
        for _ in 0 ..< 4 where !(totp.exists && totp.isHittable) { app.swipeUp() }
        probe("addform-totp-secure", text: key) { app.secureTextFields["LoginTotpEntry"] }
        clear(totp)
        totp.typeText(key)
        let dots = count(totp)
        app.buttons["TextVisibilityToggle"].firstMatch.tap()
        let plain = app.textFields["LoginTotpEntry"]
        _ = plain.waitForExistence(timeout: 5)
        print("KEYPROBE field=addform-totp-revealed mode=whole round=1 want=\(key.count) dots=\(dots) revealedCount=\(count(plain)) revealedEqual=\((plain.value as? String) == key) load=\(passYLoad())")
    }

    /// Launch arguments for diagnosis switches (`PASSY_APP_ARGS`, space separated, e.g. `-passyDbgX YES`).
    private var appArgs: [String] {
        (ProcessInfo.processInfo.environment["PASSY_APP_ARGS"] ?? "").split(separator: " ").map(String.init)
    }

    /// Types `text` into the focused field by tapping the software keyboard's keys (as a person would).
    private func tapKeys(_ app: XCUIApplication, _ text: String) {
        for ch in text {
            let s = String(ch)
            var key = app.keyboards.keys[s]
            if !key.exists {
                // Switch the keyboard plane (letters/numbers) until the key is there.
                for plane in ["more", "shift", "more"] where !key.exists {
                    let k = app.keyboards.buttons[plane].exists ? app.keyboards.buttons[plane] : app.keyboards.keys[plane]
                    if k.exists { k.tap() }
                    key = app.keyboards.keys[s]
                }
            }
            if key.exists { key.tap() } else { print("KEYPROBE missing key \(s)") }
        }
    }

    /// Discriminator: reveals the authenticator key first (so the password is the only masked field), probes the
    /// masked password; then the reverse (password revealed, authenticator key masked). Also types the masked password
    /// with software-keyboard key taps.
    func test_probeAddLoginOneMaskedField() {
        let app = launchApp(extraArguments: appArgs)
        ensureUnlockedVault(app)
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        XCTAssertTrue(app.textFields["ItemNameEntry"].waitForExistence(timeout: 15), "add form")
        app.dismissNewLoginCard()
        let totpToggle = app.buttons["TextVisibilityToggle"].firstMatch
        for _ in 0 ..< 4 where !(totpToggle.exists && totpToggle.isHittable) { app.swipeUp() }
        totpToggle.tap()
        XCTAssertTrue(app.textFields["LoginTotpEntry"].waitForExistence(timeout: 5), "authenticator key revealed")
        let secure = app.secureTextFields["LoginPasswordEntry"]
        for _ in 0 ..< 4 where !(secure.exists && secure.isHittable) { app.swipeDown() }
        probe("onlymasked-password", rounds: 1) { app.secureTextFields["LoginPasswordEntry"] }
        clear(secure)
        let key = "abcdefghijklmnopqrstu"
        tapKeys(app, key)
        print("KEYPROBE field=onlymasked-password mode=keytaps round=1 want=\(key.count) got=\(count(secure)) load=\(passYLoad())")
        // Both masked again: key taps into the masked password.
        totpToggle.tap()
        clear(secure)
        tapKeys(app, key)
        print("KEYPROBE field=bothmasked-password mode=keytaps round=1 want=\(key.count) got=\(count(secure)) load=\(passYLoad())")
        // The reverse: password revealed, only the authenticator key masked.
        clear(secure)
        app.buttons["ViewPasswordButton"].firstMatch.tap()
        probeTotp(app)
        _ = returnToRoot(app)
    }

    /// Quick variant: only the masked password (and the authenticator key) of the add-login form, then revealed.
    func test_probeAddLoginSecureFields() {
        let app = launchApp(extraArguments: appArgs)
        ensureUnlockedVault(app)
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        XCTAssertTrue(app.textFields["ItemNameEntry"].waitForExistence(timeout: 15), "add form")
        app.dismissNewLoginCard()
        probe("addform-password-secure") { app.secureTextFields["LoginPasswordEntry"] }
        let secure = app.secureTextFields["LoginPasswordEntry"]
        clear(secure)
        secure.typeText(text)
        let dots = count(secure)
        app.buttons["ViewPasswordButton"].firstMatch.tap()
        let plain = app.textFields["LoginPasswordEntry"]
        _ = plain.waitForExistence(timeout: 5)
        print("KEYPROBE field=addform-password-revealed mode=whole round=1 want=\(text.count) dots=\(dots) revealedCount=\(count(plain)) revealedEqual=\((plain.value as? String) == text) load=\(passYLoad())")
        app.buttons["ViewPasswordButton"].firstMatch.tap()
        probeTotp(app)
        _ = returnToRoot(app)
    }
}
