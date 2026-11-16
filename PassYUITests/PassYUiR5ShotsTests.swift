import XCTest

/// ui-r5: Apple Passwords comparison shots, Dynamic Type on the new forms, accessibility audit, iPad appearance and
/// landscape. Attachment names: `<PASSY_SHOT_TAG>-<nn>-<screen>`. The iPad appearance cannot be switched from
/// XCUITest on the simulator (`XCUIDevice.appearance` has no effect there): switch it before the run with
/// `xcrun simctl ui <udid> appearance dark` and use another tag.
final class PassYUiR5ShotsTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var tag: String { ProcessInfo.processInfo.environment["PASSY_SHOT_TAG"] ?? "r5" }

    private func shot(_ app: XCUIApplication, _ n: Int, _ name: String) {
        sleep(1)
        attach(app, "\(tag)-\(String(format: "%02d", n))-\(name)")
    }

    private func closeSheet(_ app: XCUIApplication) {
        for id in ["CancelButton", "CloseButton", "Close", "Cancel"] {
            let b = app.buttons[id].firstMatch
            if b.exists, b.isHittable { b.tap(); sleep(1); break }
        }
        let discard = app.buttons["Cancel"].firstMatch
        if discard.waitForExistence(timeout: 1) { discard.tap() }
    }

    private func openAdd(_ app: XCUIApplication, _ type: String) -> Bool {
        let fab = app.buttons["AddItemFloatingActionButton"]
        guard fab.waitForExistence(timeout: 8) else { return false }
        fab.tap(); sleep(1)
        let item = app.menuItems.matching(NSPredicate(format: "label BEGINSWITH %@", type)).firstMatch
        let btn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT (identifier BEGINSWITH 'CategoryTile')", type)).firstMatch
        if item.waitForExistence(timeout: 3) { item.tap() } else if btn.waitForExistence(timeout: 2) { btn.tap() } else { app.tap(); return false }
        sleep(2)
        return true
    }

    /// Add forms for the types that need the `pm-32009-new-item-types` server flag (Vaultwarden
    /// `EXPERIMENTAL_CLIENT_FEATURE_FLAGS`): bank account, passport, driver's license.
    func test_newTypeForms() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            var n = 1
            for type in ["Bank account", "Passport", "License"] {
                XCTAssertTrue(openAdd(app, type), "add menu has \(type) (server flag pm-32009-new-item-types)")
                shot(app, n, "\(mode)-add-\(type.lowercased().replacingOccurrences(of: " ", with: "-"))"); n += 1
                closeSheet(app)
            }
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// New forms and the item view with large and accessibility Dynamic Type.
    func test_dynamicTypeForms() {
        for size in ["UICTContentSizeCategoryXL", "UICTContentSizeCategoryAccessibilityL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", size])
            ensureUnlockedVault(app)
            let short = size.replacingOccurrences(of: "UICTContentSizeCategory", with: "").lowercased()
            if openAdd(app, "Bank account") { shot(app, 1, "\(short)-add-bank"); closeSheet(app) }
            if openAdd(app, "Login") { shot(app, 2, "\(short)-add-login"); closeSheet(app) }
            app.terminate()
        }
    }

    /// Home, item list and item view in the current light/dark appearance for the Apple Passwords comparison.
    func test_compare() {
        for mode in ["light", "dark"] {
            XCUIDevice.shared.appearance = mode == "dark" ? .dark : .light
            let app = launchApp()
            ensureUnlockedVault(app)
            XCTAssertTrue(app.buttons["CategoryTile_login"].waitForExistence(timeout: 10))
            shot(app, 1, "\(mode)-home")
            app.buttons["CategoryTile_login"].tap(); sleep(2)
            shot(app, 2, "\(mode)-list")
            let row = app.buttons["VaultListItemRowButton"].firstMatch
            if row.waitForExistence(timeout: 8) {
                row.tap(); sleep(2)
                shot(app, 3, "\(mode)-detail")
                let edit = app.buttons["Edit"].firstMatch
                if edit.exists { edit.tap(); sleep(2); shot(app, 4, "\(mode)-edit"); closeSheet(app) }
            }
            app.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Home is a left-aligned large title; the bottom bar and avatar menu have accessibility labels in reading order.
    func test_voiceOverLabels() throws {
        let app = launchApp()
        ensureUnlockedVault(app)
        let avatar = app.buttons["CurrentActiveAccount"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        XCTAssertFalse(avatar.label.isEmpty, "avatar has an accessibility label")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.exists, "search field")
        XCTAssertFalse(search.label.isEmpty, "search field has a label")
        let add = app.buttons["AddItemFloatingActionButton"]
        XCTAssertFalse(add.label.isEmpty, "add button has a label: '\(add.label)'")
        // Reading order top to bottom: title, avatar, tiles, search, add.
        XCTAssertLessThan(avatar.frame.minY, app.buttons["CategoryTile_login"].frame.minY, "avatar before tiles")
        XCTAssertLessThan(app.buttons["CategoryTile_login"].frame.minY, search.frame.minY, "tiles before the bottom bar")
        // Every tile reads "<name>, <count>" through label and value.
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertFalse(tile.label.isEmpty)
        XCTAssertFalse((tile.value as? String ?? "").isEmpty, "tile has a count value")
        avatar.tap(); sleep(1)
        for label in ["My vault", "Send", "Generator", "Settings"] {
            XCTAssertTrue(avatarMenuEntry(app, label).exists, "avatar menu entry \(label)")
        }
        attach(app, "\(tag)-voiceover-avatar-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.45)).tap() // outside the menu: dismisses it
        sleep(1)
        if #available(iOS 17.0, *) {
            // Audit result is recorded (never fails the run); contrast/dynamic-type findings are listed in the README.
            var issues: [String] = []
            do {
                try app.performAccessibilityAudit { issue in
                    issues.append("\(issue.auditType.rawValue): \(issue.compactDescription) [\(issue.element?.label ?? "?")]")
                    return true
                }
            } catch { issues.append("audit error: \(error)") }
            print("R5AUDIT home: \(issues.count) issues")
            for i in issues { print("R5AUDIT home: \(i)") }
            let item = app.buttons["VaultListItemRowButton"].firstMatch
            app.buttons["CategoryTile_login"].tap(); sleep(2)
            if item.waitForExistence(timeout: 8) {
                item.tap(); sleep(2)
                var issues2: [String] = []
                do {
                    try app.performAccessibilityAudit { issue in
                        issues2.append("\(issue.auditType.rawValue): \(issue.compactDescription) [\(issue.element?.label ?? "?")]")
                        return true
                    }
                } catch { issues2.append("audit error: \(error)") }
                print("R5AUDIT item: \(issues2.count) issues")
                for i in issues2 { print("R5AUDIT item: \(i)") }
            }
        }
    }

    /// iPad shots in the simulator's current appearance, portrait and landscape (no sidebar: avatar menu shell).
    func test_ipadShell() {
        let app = launchApp()
        ensureUnlockedVault(app)
        for (name, orientation) in [("portrait", UIDeviceOrientation.portrait), ("landscape", UIDeviceOrientation.landscapeLeft)] {
            XCUIDevice.shared.orientation = orientation
            sleep(2)
            shot(app, name == "portrait" ? 1 : 10, "ipad-\(name)-home")
            let tile = app.buttons["CategoryTile_login"]
            if tile.waitForExistence(timeout: 5) {
                tile.tap(); sleep(2)
                shot(app, name == "portrait" ? 2 : 11, "ipad-\(name)-list")
                let row = app.buttons["VaultListItemRowButton"].firstMatch
                if row.waitForExistence(timeout: 5) {
                    row.tap(); sleep(2)
                    shot(app, name == "portrait" ? 3 : 12, "ipad-\(name)-detail")
                    closeSheet(app)
                    let close = app.buttons["Close"].firstMatch
                    if close.exists, close.isHittable { close.tap(); sleep(1) }
                }
                let back = app.navigationBars.buttons.firstMatch
                if back.exists, back.isHittable { back.tap(); sleep(1) }
            }
            goTo(app, "Settings"); sleep(2)
            shot(app, name == "portrait" ? 4 : 13, "ipad-\(name)-settings")
            goTo(app, "My vault"); sleep(1)
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
