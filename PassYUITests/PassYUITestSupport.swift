import XCTest

/// Throwaway test account on a local Vaultwarden (see Scripts-passy/vaultwarden/seed_account.py).
enum TestAccount {
    /// Defaults to port 8088; override with `TEST_RUNNER_PASSY_SERVER=http://localhost:<port>` (alias: `PASSY_VW_URL`) for a parallel Vaultwarden.
    static let server = ProcessInfo.processInfo.environment["PASSY_SERVER"]
        ?? ProcessInfo.processInfo.environment["PASSY_VW_URL"]
        ?? "http://localhost:8088"
    static let email = "passy-test@example.test"
    static let password = "PassY-Test-Only-2026!"
}

extension XCUIElement {
    /// Taps a field until it really has keyboard focus (the simulator sometimes ignores the first tap, and typing
    /// then fails with "Neither element nor any descendant has keyboard focus").
    func focus() {
        for _ in 0 ..< 4 {
            tap()
            for _ in 0 ..< 6 {
                if (value(forKey: "hasKeyboardFocus") as? Bool) == true { return }
                usleep(250_000)
            }
        }
    }

    /// Clears a text/secure field (a failed login attempt leaves the typed text in the field) and types `text`.
    func replaceText(_ text: String) {
        // The simulator sometimes drops a character while the app is busy ("Invalid master password", 20 instead of 21
        // dots). The count is checked after typing and the text is typed again (at most three times).
        for _ in 0 ..< 3 {
            focus()
            if let current = value as? String, !current.isEmpty, current != (placeholderValue ?? "") {
                typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            }
            typeText(text)
            if typedTextIsComplete(text) { return }
        }
    }

    /// Whether the field holds all of `text` (secure fields show one dot per character).
    func typedTextIsComplete(_ text: String) -> Bool {
        guard let shown = value as? String else { return false }
        return shown == text || (shown.count == text.count && shown.allSatisfy { $0 == "\u{2022}" || $0 == "\u{25CF}" })
    }
}

extension XCTestCase {
    /// Taps the search field and makes sure the soft keyboard is up (the simulator occasionally ignores the first tap).
    func focusSearch(_ app: XCUIApplication) {
        let search = app.searchFields.firstMatch
        search.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 4) {
            search.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 6), "keyboard shows after tapping the search field")
        }
        sleep(1)
    }

    /// Taps "Login" in the open add menu (on iPad the category tile of the same name is also visible behind it).
    func tapNewLoginMenuItem(_ app: XCUIApplication) {
        let menuItem = app.menuItems["Login"]
        if menuItem.waitForExistence(timeout: 4) { menuItem.tap(); return }
        let predicate = NSPredicate(format: "label == 'Login' AND NOT (identifier BEGINSWITH 'CategoryTile')")
        let button = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Login entry of the add menu\n\(app.debugDescription)")
        button.tap()
    }

    func launchApp(extraArguments: [String] = [], appearance: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        // `XCUIDevice.shared.appearance = .dark` and `-AppleInterfaceStyle` do not change the rendering on the iOS 27
        // simulator (every "dark" run of ui-r5 to ui-r8 rendered light, proven by the pixel check below). The app has a
        // launch argument that sets its windows' interface style (`AppProcessor`).
        let style: [String] = passYWantedStyle.map { ["-passyForceInterfaceStyle", $0] } ?? []
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + style + extraArguments
        app.launch()
        return app
    }

    /// Attaches a screenshot without the appearance check (for screens that are not the app: "Recovery code" opens Safari).
    func attachUnchecked(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        // Only the app is checked: "Recovery code" opens Safari (web vault link), the screenshot then shows another app.
        if app.state == .runningForeground { assertRenderedAppearance(screenshot, name: name) }
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Waits until `element` no longer exists.
    func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @discardableResult
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Polls `condition` until it holds or `timeout` seconds passed.
    @discardableResult
    func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            usleep(400_000)
        }
        return condition()
    }

    /// Brings the app to the unlocked vault list from any of: intro, login, unlock, vault.
    ///
    /// State driven: it waits for the app to reach the next state (vault, error alert) instead of sleeping for fixed
    /// times, the overall budget grows with the load of the host (a login under load 100 takes minutes), and an error
    /// alert (network or credentials) is dismissed and the step is tried again, at most three times.
    func ensureUnlockedVault(_ app: XCUIApplication) {
        let fab = app.buttons["AddItemFloatingActionButton"]
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        let budget = min(600, 150 + max(0, load[0] - 8) * 6)
        let deadline = Date().addingTimeInterval(budget)
        var dismissedAlerts = 0
        /// Waits for the vault or an alert after an asynchronous step (login, unlock).
        func settle() {
            waitUntil(max(5, min(120, deadline.timeIntervalSinceNow))) { fab.exists || app.alerts.firstMatch.exists }
        }
        while Date() < deadline {
            if fab.exists { return }
            let alert = app.alerts.firstMatch
            if alert.exists {
                dismissedAlerts += 1
                print("LOGIN-ALERT \(dismissedAlerts): \(alert.staticTexts.allElementsBoundByIndex.map(\.label))")
                if dismissedAlerts > 3 { XCTFail("Login keeps failing with an alert: \(alert.debugDescription) texts: \(alert.staticTexts.allElementsBoundByIndex.map(\.label))"); return }
                alert.buttons.firstMatch.tap()
                sleep(1)
                continue
            }
            if app.buttons["Log in"].exists { app.buttons["Log in"].tap() }
            let server = app.textFields["ServerUrlEntry"]
            if server.exists {
                server.focus()
                server.typeText(TestAccount.server)
                app.buttons["SaveButton"].firstMatch.tap()
                waitUntil(10) { !server.exists }
                continue
            }
            let email = app.textFields["LoginEmailAddressEntry"]
            if email.exists {
                if app.buttons["RegionSelectorDropdown"].label.contains("Not set") {
                    // The server sheet is presented automatically; wait until the selector is tappable.
                    if app.buttons["RegionSelectorDropdown"].isHittable { app.buttons["RegionSelectorDropdown"].tap() }
                } else if email.isHittable {
                    email.focus()
                    email.typeText(TestAccount.email)
                    app.buttons["ContinueButton"].tap()
                    waitUntil(20) { !email.exists || app.alerts.firstMatch.exists }
                }
            }
            let loginPw = app.secureTextFields["LoginMasterPasswordEntry"]
            if loginPw.exists {
                loginPw.replaceText(TestAccount.password)
                app.buttons["LogInWithMasterPasswordButton"].tap()
                // The login is asynchronous and the field disappears when it succeeded: wait for the result instead of
                // typing into the vanishing field again (snapshot race seen in Flow test02).
                settle()
            }
            let unlockPw = app.secureTextFields["MasterPasswordEntry"]
            if !fab.exists, unlockPw.exists {
                unlockPw.replaceText(TestAccount.password)
                app.buttons["UnlockVaultButton"].tap()
                settle()
            }
            usleep(500_000)
        }
        XCTFail("Could not reach the vault list (budget \(Int(budget)) s at load \(String(format: "%.0f", load[0])))")
    }
}

extension XCUIApplication {
    /// Dismisses the "learn about new logins" intro card if it is visible.
    func dismissNewLoginCard() {
        let dismiss = buttons["Dismiss"]
        if dismiss.exists, dismiss.isHittable { dismiss.tap() }
    }

    /// All visible text labels joined, for content assertions that ignore accessibility identifiers.
    var allLabels: String {
        staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
            + "\n" + buttons.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
    }
}

extension XCTestCase {
    /// Creates a login through the add-item UI and returns to the vault list.
    func addLogin(_ app: XCUIApplication, name: String, user: String, password: String, totp: String? = nil) {
        app.buttons["AddItemFloatingActionButton"].tap()
        tapNewLoginMenuItem(app)
        let nameField = app.textFields["ItemNameEntry"]
        XCTAssertTrue(waitFor(nameField))
        app.dismissNewLoginCard()
        nameField.tap(); nameField.typeText(name)
        if let totp {
            let setup = app.buttons["SetupTotpButton"]
            if !setup.exists { app.swipeUp() }
            let field = app.secureTextFields["LoginTotpEntry"].exists
                ? app.secureTextFields["LoginTotpEntry"] : app.textFields["LoginTotpEntry"]
            if !field.waitForExistence(timeout: 3) {
                for _ in 0 ..< 4 where !field.exists { app.swipeUp() }
            }
            if !field.exists, setup.exists { setup.tap() }
            if field.waitForExistence(timeout: 10) { field.tap(); field.typeText(totp) }
        }
        if totp != nil { app.swipeDown() }
        let userField = app.textFields["LoginUsernameEntry"]
        userField.tap(); userField.typeText(user)
        let pw = app.secureTextFields["LoginPasswordEntry"]
        pw.tap(); pw.typeText(password)
        app.buttons["SaveButton"].firstMatch.tap()
        _ = app.buttons["Close"].waitForExistence(timeout: 8)
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        if close.exists { close.firstMatch.tap() }
        sleep(2)
    }
}

/// Opens the avatar menu (top right) and returns the entry for a destination ("My vault", "Send", "Generator",
/// "Settings"). There is no tab bar: these entries are the only way to switch top-level screens.
func avatarMenuEntry(_ app: XCUIApplication, _ label: String) -> XCUIElement {
    let ids = ["My vault": "ProfileMenuVaultButton", "Send": "ProfileMenuSendButton",
               "Generator": "ProfileMenuGeneratorButton", "Settings": "ProfileMenuSettingsButton"]
    func lookup() -> XCUIElement? {
        let byId = app.buttons[ids[label] ?? label]
        if byId.exists { return byId }
        let byLabel = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if byLabel.exists { return byLabel }
        let item = app.menuItems[label]
        return item.exists ? item : nil
    }
    if let found = lookup() { return found }
    // The menu is closed: open it (once) and look again.
    let avatar = app.buttons["CurrentActiveAccount"]
    if avatar.waitForExistence(timeout: 10) { avatar.tap() }
    for _ in 0 ..< 10 {
        if let found = lookup() { return found }
        usleep(300_000)
    }
    return app.buttons[ids[label] ?? label]
}

/// A button of the open avatar menu by identifier or, failing that, by its label.
func menuButton(_ app: XCUIApplication, id: String, label: String) -> XCUIElement {
    let byId = app.buttons[id]
    if byId.exists { return byId }
    let byLabel = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    if byLabel.exists { return byLabel }
    let item = app.menuItems[label]
    return item.exists ? item : byId
}

/// Switches to a top-level screen through the avatar menu. The vault is not in the menu any more (ui-r9): it is the
/// Vault button of the bottom bar (absent on the vault home itself).
func goTo(_ app: XCUIApplication, _ label: String) {
    if label == "My vault" {
        let button = app.buttons["BottomBarVaultButton"]
        if button.waitForExistence(timeout: 5) { button.tap() }
        return
    }
    avatarMenuEntry(app, label).tap()
}


// MARK: - Appearance

/// Whether the current test step wants the dark interface style (set by `setPassYAppearance`, or by the chain through
/// `TEST_RUNNER_PASSY_EXPECT_APPEARANCE=dark`).
nonisolated(unsafe) private var passYForcedAppearance: String?

var passYWantedStyle: String? {
    passYForcedAppearance ?? ProcessInfo.processInfo.environment["PASSY_EXPECT_APPEARANCE"]
}

/// Replacement for `XCUIDevice.shared.appearance = ...`: remembers the wish (launch arguments) and still sets the
/// device appearance, which is harmless where it works.
func setPassYAppearance(_ appearance: XCUIDevice.Appearance) {
    passYForcedAppearance = appearance == .dark ? "dark" : "light"
    XCUIDevice.shared.appearance = appearance
}

/// Fails when a screenshot does not render in the expected appearance: the page background at the left edge (outside every
/// card and control) is dark (luminance below 0.35) or light (above 0.6). Skipped when no appearance is expected.
/// Background luminance (0 black, 1 white) at the left edge of a screenshot, `nil` when it cannot be read.
func backgroundLuminance(_ screenshot: XCUIScreenshot) -> Double? {
    guard let cg = screenshot.image.cgImage else { return nil }
    var samples: [Double] = []
    for fraction in [0.35, 0.5, 0.65] {
        guard let crop = cg.cropping(to: CGRect(x: 2, y: Int(Double(cg.height) * fraction), width: 2, height: 2)),
              let data = crop.dataProvider?.data as Data?, data.count >= 3 else { continue }
        let bytes = [UInt8](data.prefix(3))
        samples.append((0.2126 * Double(bytes[0]) + 0.7152 * Double(bytes[1]) + 0.0722 * Double(bytes[2])) / 255)
    }
    return samples.sorted().dropFirst(samples.count / 2).first
}

extension XCTestCase {
    /// For a dark variant that is switched on in a running app (does not work on the iOS 27 simulator): the screenshot is
    /// only attached when it really is dark, otherwise a note is printed. Never attach a light screenshot as "dark".
    func attachDarkIfRendered(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        if let luminance = backgroundLuminance(screenshot), luminance < 0.35 {
            let shot = XCTAttachment(screenshot: screenshot)
            shot.name = name; shot.lifetime = .keepAlways; add(shot)
        } else {
            print("NOTE \(name): the running app did not switch to dark, screenshot omitted (dark is covered by the dark chain steps)")
        }
    }
}

func assertRenderedAppearance(_ screenshot: XCUIScreenshot, name: String, file: StaticString = #filePath, line: UInt = #line) {
    guard let expected = passYForcedAppearance ?? ProcessInfo.processInfo.environment["PASSY_EXPECT_APPEARANCE"],
          let luminance = backgroundLuminance(screenshot) else { return }
    let ok = expected == "dark" ? luminance < 0.35 : luminance > 0.6
    print("APPEARANCE-CHECK \(name) expected=\(expected) luminance=\(String(format: "%.2f", luminance)) ok=\(ok)")
    XCTAssertTrue(ok, "screenshot \(name) should render \(expected) (background luminance \(String(format: "%.2f", luminance)))",
                  file: file, line: line)
}
