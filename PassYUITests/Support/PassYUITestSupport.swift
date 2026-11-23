import XCTest

/// Throwaway test account on a local Vaultwarden (see Scripts-passy/vaultwarden/seed_account.py).
enum TestAccount {
    /// Defaults to port 8088; override with `TEST_RUNNER_PASSY_SERVER=http://localhost:<port>` (alias: `PASSY_VW_URL`) for a parallel Vaultwarden.
    static let server = ProcessInfo.processInfo.environment["PASSY_SERVER"]
        ?? ProcessInfo.processInfo.environment["PASSY_VW_URL"]
        ?? "http://localhost:8088"
    /// `TEST_RUNNER_PASSY_EMAIL` selects another seeded account (the perf step uses `passy-perf@example.test`).
    static let email = ProcessInfo.processInfo.environment["PASSY_EMAIL"] ?? "passy-test@example.test"
    static let twoFactorEmail = "passy-2fa@example.test"
    static let password = "PassY-Test-Only-2026!"
}

/// Counters of the typing helpers. Every retype is printed as `PASSY-RETYPE <n> ...` (the chain counts these lines per
/// step), so lost keystrokes stay visible instead of being silently repaired.
enum PassYTyping {
    nonisolated(unsafe) static var retypes = 0
}

/// Load average of the host (the simulator shares the CPU), for log lines.
func passYLoad() -> String {
    var load = [Double](repeating: 0, count: 3)
    getloadavg(&load, 3)
    return String(format: "%.0f", load[0])
}

/// The app shared by the tests of one run (see `launchApp`).
enum PassYSession {
    nonisolated(unsafe) static var app: XCUIApplication?
    nonisolated(unsafe) static var arguments: [String] = []
    nonisolated(unsafe) static var launches = 0
    nonisolated(unsafe) static var reused = 0
    /// The e-mail address last typed into the login e-mail field (the login password screen belongs to it).
    nonisolated(unsafe) static var loginEmail: String?
}

extension XCUIElement {
    /// Taps a field until it really has keyboard focus (the simulator sometimes ignores the first tap, and typing
    /// then fails with "Neither element nor any descendant has keyboard focus"), then waits until the software
    /// keyboard is on screen: keys typed while the keyboard is still being presented can be dropped.
    func focus() {
        var focused = (value(forKey: "hasKeyboardFocus") as? Bool) == true
        for _ in 0 ..< 4 where !focused {
            tap()
            for _ in 0 ..< 6 {
                if (value(forKey: "hasKeyboardFocus") as? Bool) == true { focused = true; break }
                usleep(250_000)
            }
            if focused { break }
        }
        let keyboard = XCUIApplication().keyboards.firstMatch
        if focused, keyboard.waitForExistence(timeout: 5) {
            // The keyboard exists before its slide-in ends; wait until its frame stops moving.
            var last = keyboard.frame
            for _ in 0 ..< 10 {
                usleep(150_000)
                let now = keyboard.frame
                if now == last { break }
                last = now
            }
        }
    }

    /// Clears a text/secure field (a failed login attempt leaves the typed text in the field) and types `text`, then
    /// verifies the field content (secure fields: one dot per character). A mismatch is printed as `PASSY-RETYPE` and
    /// typed again; the third mismatch fails the test, so a real stall cannot hide behind the retries.
    func replaceText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        var shown = ""
        for attempt in 1 ... 3 {
            focus()
            if let current = value as? String, !current.isEmpty, current != (placeholderValue ?? "") {
                typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            }
            typeText(text)
            if typedTextIsComplete(text) { return }
            shown = value as? String ?? "nil"
            PassYTyping.retypes += 1
            let secure = elementType == .secureTextField
            print("PASSY-RETYPE \(PassYTyping.retypes) field=\(identifier) attempt=\(attempt) want=\(text.count) got=\(shown.count)"
                + (secure ? "" : " value='\(shown)'") + " focus=\((value(forKey: "hasKeyboardFocus") as? Bool) == true)"
                + " keyboard=\(XCUIApplication().keyboards.firstMatch.exists) load=\(passYLoad())")
        }
        XCTFail("typing into \(identifier) lost keystrokes three times (field shows \(shown.count) of \(text.count) characters)",
                file: file, line: line)
    }

    /// After appending with `typeText`: when the field does not hold `expected`, logs a `PASSY-RETYPE` line and types
    /// the whole value again (verified).
    func ensureText(_ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let shown = value as? String ?? "nil"
        guard shown != expected else { return }
        PassYTyping.retypes += 1
        print("PASSY-RETYPE \(PassYTyping.retypes) field=\(identifier) attempt=append want=\(expected.count) got=\(shown.count) value='\(shown)' load=\(passYLoad())")
        replaceText(expected, file: file, line: line)
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
        // Instead of a fixed second: wait for keyboard focus and the end of the keyboard animation.
        search.focus()
    }

    /// Types into the focused bottom search bar key by key (the list filters after every key, a fast `typeText` on a
    /// busy list dropped keys) and verifies the field; a mismatch is logged as `PASSY-RETYPE` and typed again.
    func typeSearch(_ app: XCUIApplication, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        for ch in text { app.typeText(String(ch)); usleep(150_000) }
        let field = app.searchFields.firstMatch
        let shown = field.value as? String ?? "nil"
        guard shown != text else { return }
        PassYTyping.retypes += 1
        print("PASSY-RETYPE \(PassYTyping.retypes) field=search attempt=1 want=\(text.count) got=\(shown.count) value='\(shown)' load=\(passYLoad())")
        field.replaceText(text, file: file, line: line)
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

    /// Returns the app with the given launch configuration. Within one test run the app is launched (and logged in)
    /// once and then reused: when it is still running in the foreground with the same launch arguments it is brought
    /// back to a root screen (`returnToRoot`) instead of being relaunched, which would lock the vault and make every
    /// test type the master password again. A test that needs a cold start terminates the app first (`app.terminate()`)
    /// or changes the launch arguments (appearance, text size). `TEST_RUNNER_PASSY_REUSE_APP=0` relaunches every time.
    func launchApp(extraArguments: [String] = [], appearance: String? = nil) -> XCUIApplication {
        // `XCUIDevice.shared.appearance = .dark` and `-AppleInterfaceStyle` do not change the rendering on the iOS 27
        // simulator (every "dark" run of ui-r5 to ui-r8 rendered light, proven by the pixel check below). The app has a
        // launch argument that sets its windows' interface style (`AppProcessor`).
        let style: [String] = passYWantedStyle.map { ["-passyForceInterfaceStyle", $0] } ?? []
        let arguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + style + extraArguments
        if ProcessInfo.processInfo.environment["PASSY_REUSE_APP"] != "0", let app = PassYSession.app,
           PassYSession.arguments == arguments, app.state == .runningForeground {
            if returnToRoot(app) {
                PassYSession.reused += 1
                return app
            }
            print("PASSY-RELAUNCH \(name): could not return to a root screen\n\(app.debugDescription)")
        }
        let app = PassYSession.app ?? XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        PassYSession.app = app
        PassYSession.arguments = arguments
        PassYSession.launches += 1
        print("PASSY-LAUNCH \(PassYSession.launches) (reused \(PassYSession.reused)) for \(name)")
        return app
    }

    /// Brings a running app back to a root screen: dismisses alerts, menus, sheets and the search, pops to the vault
    /// home and scrolls it to the top. Screens outside the unlocked vault (landing, login, unlock) count as root:
    /// `ensureUnlockedVault` takes it from there. Every step waits for the state it causes, no fixed sleeps. Returns
    /// false when the app does not reach a root screen (the caller then relaunches it).
    func returnToRoot(_ app: XCUIApplication) -> Bool {
        let fab = app.buttons["AddItemFloatingActionButton"]
        let vaultButton = app.buttons["BottomBarVaultButton"]
        let searchCancel = app.buttons["VaultSearchCancel"]
        for _ in 0 ..< 12 {
            let alert = app.alerts.firstMatch
            if alert.exists {
                // Never confirm (Yes/Delete): cancel, or acknowledge an error.
                let button = ["Cancel", "OK", "Close", "No"].map { alert.buttons[$0] }.first { $0.exists } ?? alert.buttons.firstMatch
                button.tap()
                _ = waitForDisappearance(of: alert, timeout: 5)
                continue
            }
            // The add menu's entries are buttons named after their symbols ("folder", "key"), not menu items.
            if app.menuItems.firstMatch.exists || avatarMenuIsOpen(app)
                || (app.buttons["folder"].exists && app.buttons["key"].exists) {
                // A menu (add menu, avatar menu, context menu) is open: tap outside it. (The avatar menu entries carry
                // labels, not the identifiers, in the tree, so `avatarMenuIsOpen` also matches "Sync now" by label.)
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.45)).tap()
                _ = waitUntil(3) { !app.menuItems.firstMatch.exists && !avatarMenuIsOpen(app) && !app.buttons["folder"].exists }
                continue
            }
            // Outside the unlocked vault: landing, server sheet, login, two-step login, unlock are fine as they are.
            if app.buttons["Log in"].exists || app.buttons["RegionSelectorDropdown"].exists || app.textFields["ServerUrlEntry"].exists
                || app.buttons["LogInWithMasterPasswordButton"].exists || app.textFields["VerificationCodeEntry"].exists
                || app.buttons["UnlockVaultButton"].exists {
                return true
            }
            if let close = ["CancelButton", "CloseButton", "Close", "Cancel"].map({ app.buttons[$0].firstMatch })
                .first(where: { $0.exists && $0.isHittable }), !(fab.exists && fab.isHittable) {
                close.tap()
                _ = waitUntil(5) { !close.exists || !close.isHittable }
                continue
            }
            if searchCancel.exists, searchCancel.isHittable {
                searchCancel.tap()
                _ = waitForDisappearance(of: searchCancel, timeout: 5)
                continue
            }
            if vaultButton.exists, vaultButton.isHittable {
                vaultButton.tap()
                _ = waitForDisappearance(of: vaultButton, timeout: 5)
                continue
            }
            if fab.exists, fab.isHittable {
                // Vault home: make sure it is scrolled to the top (tests expect the category tiles).
                let tile = app.buttons["CategoryTile_login"]
                for _ in 0 ..< 6 where !(tile.exists && tile.isHittable) { app.swipeDown() }
                return tile.exists && tile.isHittable
            }
            if fab.exists, !fab.isHittable {
                // Something unknown covers the vault (a context menu): tap outside it.
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.45)).tap()
                usleep(800_000)
                continue
            }
            let back = app.navigationBars.buttons.firstMatch
            if back.exists, back.isHittable, back.identifier != "CurrentActiveAccount" {
                back.tap()
                usleep(500_000)
                continue
            }
            usleep(500_000)
        }
        return false
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

    /// Brings the app to the unlocked vault list from any of: intro, landing, server sheet, login (also of another
    /// account), two-step login, unlock, vault.
    ///
    /// State driven: it waits for the app to reach the next state (vault, error alert) instead of sleeping for fixed
    /// times, the overall budget grows with the load of the host (a login under load 100 takes minutes), every typed
    /// value is verified (`replaceText`, retypes are logged as `PASSY-RETYPE`), and an error alert (network or
    /// credentials) is logged as `LOGIN-ALERT`, dismissed and the step is tried again, at most three times.
    func ensureUnlockedVault(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let fab = app.buttons["AddItemFloatingActionButton"]
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        let budget = min(600, 150 + max(0, load[0] - 8) * 6)
        let deadline = Date().addingTimeInterval(budget)
        var dismissedAlerts = 0
        /// Waits for the vault or an alert after an asynchronous step (login, unlock).
        func settle() {
            waitUntil(max(5, min(120, deadline.timeIntervalSinceNow))) {
                fab.exists || app.alerts.firstMatch.exists || app.textFields["VerificationCodeEntry"].exists
            }
        }
        while Date() < deadline {
            if fab.exists { return }
            let alert = app.alerts.firstMatch
            if alert.exists {
                dismissedAlerts += 1
                print("LOGIN-ALERT \(dismissedAlerts): \(alert.staticTexts.allElementsBoundByIndex.map(\.label)) load=\(passYLoad())")
                if dismissedAlerts > 3 {
                    XCTFail("Login keeps failing with an alert: \(alert.debugDescription) texts: \(alert.staticTexts.allElementsBoundByIndex.map(\.label))",
                            file: file, line: line)
                    return
                }
                alert.buttons.firstMatch.tap()
                _ = waitForDisappearance(of: alert, timeout: 5)
                continue
            }
            // Two-step login of another account (AuthTwoFactorTests): leave it.
            if app.textFields["VerificationCodeEntry"].exists {
                let cancel = app.buttons["CancelButton"].exists ? app.buttons["CancelButton"] : app.navigationBars.buttons.firstMatch
                cancel.tap()
                waitUntil(10) { !app.textFields["VerificationCodeEntry"].exists }
                continue
            }
            if app.buttons["Log in"].exists { app.buttons["Log in"].tap() }
            let server = app.textFields["ServerUrlEntry"]
            if server.exists {
                server.replaceText(TestAccount.server, file: file, line: line)
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
                    // The landing remembers the last e-mail: replace it, never append.
                    email.replaceText(TestAccount.email, file: file, line: line)
                    PassYSession.loginEmail = TestAccount.email
                    app.buttons["ContinueButton"].tap()
                    waitUntil(20) { !email.exists || app.alerts.firstMatch.exists }
                }
            }
            let loginPw = app.secureTextFields["LoginMasterPasswordEntry"]
            if loginPw.exists {
                // The login screen of another account (left by an auth test): back to the landing ("Not you?").
                let loggingInAs = app.staticTexts["LoggingInAsLabel"]
                if loggingInAs.exists, !loggingInAs.label.contains(TestAccount.email), app.buttons["NotYouLabel"].exists {
                    app.buttons["NotYouLabel"].tap()
                    waitUntil(10) { !loginPw.exists }
                    continue
                }
                loginPw.replaceText(TestAccount.password, file: file, line: line)
                app.buttons["LogInWithMasterPasswordButton"].tap()
                // The login is asynchronous and the field disappears when it succeeded: wait for the result instead of
                // typing into the vanishing field again (snapshot race seen in Flow test02).
                settle()
            }
            let unlockPw = app.secureTextFields["MasterPasswordEntry"]
            if !fab.exists, unlockPw.exists, app.buttons["UnlockVaultButton"].exists {
                unlockPw.replaceText(TestAccount.password, file: file, line: line)
                app.buttons["UnlockVaultButton"].tap()
                settle()
            }
            usleep(500_000)
        }
        XCTFail("Could not reach the vault list (budget \(Int(budget)) s at load \(String(format: "%.0f", load[0])))", file: file, line: line)
    }

    /// Logs the signed-in account out (Settings > account row > Log out) if the vault is open or locked, and returns
    /// once the landing or login screen is shown.
    func logOutIfLoggedIn(_ app: XCUIApplication) {
        guard app.buttons["AddItemFloatingActionButton"].exists || app.buttons["UnlockVaultButton"].exists else { return }
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        let row = app.buttons["SettingsAccountRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "settings account row")
        row.tap()
        let logOut = app.buttons["Log out"]
        XCTAssertTrue(logOut.waitForExistence(timeout: 5), "account menu offers Log out")
        logOut.tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5), "log out asks for confirmation")
        yes.tap()
        XCTAssertTrue(waitUntil(20) {
            app.textFields["LoginEmailAddressEntry"].exists || app.buttons["Log in"].exists
        }, "landing after log out")
    }

    /// From any state (vault, locked, landing, intro, a login of another account): logs out if needed, sets the server if
    /// it is not set and enters `email`; returns on the login (master password) screen of that account.
    func reachLoginPasswordScreen(_ app: XCUIApplication, email: String, file: StaticString = #filePath, line: UInt = #line) {
        logOutIfLoggedIn(app)
        let pw = app.secureTextFields["LoginMasterPasswordEntry"]
        let emailField = app.textFields["LoginEmailAddressEntry"]
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            if pw.exists {
                let loggingInAs = app.staticTexts["LoggingInAsLabel"]
                if !loggingInAs.exists || loggingInAs.label.contains(email) { return }
                app.buttons["NotYouLabel"].tap()
                waitUntil(10) { !pw.exists }
                continue
            }
            if app.textFields["VerificationCodeEntry"].exists {
                (app.buttons["CancelButton"].exists ? app.buttons["CancelButton"] : app.navigationBars.buttons.firstMatch).tap()
                waitUntil(10) { !app.textFields["VerificationCodeEntry"].exists }
                continue
            }
            if app.buttons["Log in"].exists { app.buttons["Log in"].tap() }
            let server = app.textFields["ServerUrlEntry"]
            if server.waitForExistence(timeout: 2) {
                server.replaceText(TestAccount.server, file: file, line: line)
                app.buttons["SaveButton"].firstMatch.tap()
                waitUntil(10) { !server.exists }
                continue
            }
            if emailField.exists {
                if app.buttons["RegionSelectorDropdown"].label.contains("Not set") {
                    if app.buttons["RegionSelectorDropdown"].isHittable { app.buttons["RegionSelectorDropdown"].tap() }
                    continue
                }
                guard emailField.isHittable else { usleep(500_000); continue }
                emailField.replaceText(email, file: file, line: line)
                PassYSession.loginEmail = email
                app.buttons["ContinueButton"].tap()
                waitUntil(20) { pw.exists || app.alerts.firstMatch.exists }
                if app.alerts.firstMatch.exists {
                    print("LOGIN-ALERT e-mail step: \(app.alerts.firstMatch.staticTexts.allElementsBoundByIndex.map(\.label))")
                    app.alerts.firstMatch.buttons.firstMatch.tap()
                }
                continue
            }
            usleep(500_000)
        }
        XCTFail("login screen of \(email) not reached\n\(app.debugDescription)", file: file, line: line)
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
        nameField.replaceText(name)
        if let totp {
            let setup = app.buttons["SetupTotpButton"]
            if !setup.exists { app.swipeUp() }
            let field = app.secureTextFields["LoginTotpEntry"].exists
                ? app.secureTextFields["LoginTotpEntry"] : app.textFields["LoginTotpEntry"]
            if !field.waitForExistence(timeout: 3) {
                for _ in 0 ..< 4 where !field.exists { app.swipeUp() }
            }
            if !field.exists, setup.exists { setup.tap() }
            if field.waitForExistence(timeout: 10) { field.replaceText(totp) }
        }
        if totp != nil { app.swipeDown() }
        let userField = app.textFields["LoginUsernameEntry"]
        userField.replaceText(user)
        let pw = app.secureTextFields["LoginPasswordEntry"]
        pw.tap(); pw.typeText(password)
        app.buttons["SaveButton"].firstMatch.tap()
        _ = app.buttons["Close"].waitForExistence(timeout: 8)
        let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["CancelButton"]
        if close.exists { close.firstMatch.tap() }
        sleep(2)
    }
}

/// Whether the avatar menu is open (its Sync entry is always there).
func avatarMenuIsOpen(_ app: XCUIApplication) -> Bool {
    app.buttons["ProfileMenuSyncButton"].exists || app.buttons["ProfileMenuSettingsButton"].exists
        || app.menuItems["Sync now"].exists || app.buttons.matching(NSPredicate(format: "label == 'Sync now'")).firstMatch.exists
}

/// Opens the avatar menu (top right) once and waits until it is open (state driven: a second tap while it is still
/// opening would close it again). Returns whether it is open.
@discardableResult
func openAvatarMenu(_ app: XCUIApplication) -> Bool {
    if avatarMenuIsOpen(app) { return true }
    let avatar = app.buttons["CurrentActiveAccount"]
    guard avatar.waitForExistence(timeout: 10) else { return false }
    for _ in 0 ..< 2 {
        avatar.tap()
        let end = Date().addingTimeInterval(10)
        while Date() < end {
            if avatarMenuIsOpen(app) { return true }
            usleep(300_000)
        }
    }
    return avatarMenuIsOpen(app)
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
    if avatarMenuIsOpen(app), let found = lookup() { return found }
    openAvatarMenu(app)
    if let found = lookup() { return found }
    return app.buttons[ids[label] ?? label]
}

/// A button of the avatar menu by identifier or, failing that, by its label. Opens the menu first (and waits for it)
/// when it is not open yet.
func menuButton(_ app: XCUIApplication, id: String, label: String) -> XCUIElement {
    func lookup() -> XCUIElement? {
        let byId = app.buttons[id]
        if byId.exists { return byId }
        let byLabel = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if byLabel.exists { return byLabel }
        let item = app.menuItems[label]
        return item.exists ? item : nil
    }
    if let found = lookup() { return found }
    if id.hasPrefix("ProfileMenu") {
        openAvatarMenu(app)
        if let found = lookup() { return found }
    }
    // Not there yet (a menu still opening): a query that matches either way, so `waitForExistence` on it works.
    return app.descendants(matching: .any).matching(NSPredicate(
        format: "(identifier == %@ OR label == %@) AND NOT (identifier BEGINSWITH 'CategoryTile') AND (elementType == %d OR elementType == %d)",
        id, label, XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue)).firstMatch
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

/// The appearances a light/dark test runs: `PASSY_MODE` (one), else light and dark.
func passYModes() -> [String] {
    ProcessInfo.processInfo.environment["PASSY_MODE"].map { [$0] } ?? ["light", "dark"]
}

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
