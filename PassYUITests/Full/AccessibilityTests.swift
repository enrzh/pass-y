import XCTest

/// VoiceOver labels and the accessibility audit, Dynamic Type up to AX-XXXL, the idle-stall loop of the add menu.
final class AccessibilityTests: PassYUITestCase {
    /// Home is a left-aligned large title; the bottom bar and avatar menu have accessibility labels in reading order.
    /// Formerly `PassYUiR5ShotsTests.test_voiceOverLabels`.
    func test_voiceOverLabelsAndAudit() throws {
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
        XCTAssertTrue(openAvatarMenu(app), "avatar menu opens")
        for label in ["Send", "Generator", "Settings"] {
            XCTAssertTrue(avatarMenuEntry(app, label).exists, "avatar menu entry \(label)")
        }
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label == %@", "My vault")).firstMatch.exists, "ui-r9: no Vault entry in the avatar menu (on the vault home the bar has no Vault button either)")
        XCTAssertFalse(app.buttons["ProfileMenuVaultButton"].exists, "ui-r9: no Vault entry in the avatar menu")
        XCTAssertTrue(menuButton(app, id: "ProfileMenuPendingRequestsButton", label: "Pending login requests").exists, "ui-r9: pending login requests in the menu")
        attach(app, "\(tag)-voiceover-avatar-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.45)).tap() // outside the menu: dismisses it
        sleep(1)
        // Audit result is recorded (never fails the run); contrast/dynamic-type findings are listed in the README.
        var issues: [String] = []
        do {
            try app.performAccessibilityAudit { issue in
                issues.append("\(issue.auditType.rawValue): \(issue.compactDescription) [\(issue.element?.label ?? "?")] type=\(issue.element?.elementType.rawValue ?? 0) id=\(issue.element?.identifier ?? "") frame=\(issue.element?.frame ?? .zero) detail=\(issue.detailedDescription)")
                return true
            }
        } catch { issues.append("audit error: \(error)") }
        print("R5AUDIT home: \(issues.count) issues")
        // ui-r7: fixed findings must not come back (avatar initials contrast).
        XCTAssertFalse(issues.contains { $0.hasPrefix("1:") && $0.contains("[PT]") }, "avatar contrast: \(issues)")
        for i in issues { print("R5AUDIT home: \(i)") }
        let item = app.buttons["VaultListItemRowButton"].firstMatch
        app.buttons["CategoryTile_login"].tap(); sleep(2)
        if item.waitForExistence(timeout: 8) {
            item.tap(); sleep(2)
            var issues2: [String] = []
            do {
                try app.performAccessibilityAudit { issue in
                    issues2.append("\(issue.auditType.rawValue): \(issue.compactDescription) [\(issue.element?.label ?? "?")] type=\(issue.element?.elementType.rawValue ?? 0) id=\(issue.element?.identifier ?? "") frame=\(issue.element?.frame ?? .zero) detail=\(issue.detailedDescription)")
                    return true
                }
            } catch { issues2.append("audit error: \(error)") }
            print("R5AUDIT item: \(issues2.count) issues")
            // ui-r7: no clipped text (breach row) and the section header passes the contrast check.
            XCTAssertFalse(issues2.contains { $0.hasPrefix("131072:") }, "clipped text: \(issues2)")
            XCTAssertFalse(issues2.contains { $0.contains("[Login credentials]") }, "header contrast: \(issues2)")
            for i in issues2 { print("R5AUDIT item: \(i)") }
        }
    }

    /// The add menu at accessibility sizes lists every entry the user can create (7 with the new item types) and
    /// "Login" is reachable (system menus scroll; this checks the reachable entries and keeps a whole-screen shot).
    /// Formerly `PassYUiR5ShotsTests.test_addMenuAccessibilityXXXL`.
    func test_addMenuReachableAtAXXXL() {
        let app = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        ensureUnlockedVault(app)
        let fab = app.buttons["AddItemFloatingActionButton"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10))
        fab.tap(); sleep(2)
        screenShot(1, "axxxl-add-menu")
        print("R5MENU items: \(app.menuItems.allElementsBoundByIndex.map { $0.label + "@" + String(describing: $0.frame) })")
        print("R5MENU buttons: \(app.buttons.allElementsBoundByIndex.map(\.label))")
        let login = app.buttons.matching(NSPredicate(format: "label == 'Login' AND NOT (identifier BEGINSWITH 'CategoryTile')")).firstMatch
        XCTAssertTrue(app.menuItems["Login"].exists || login.waitForExistence(timeout: 4), "Login is reachable in the add menu at AX-XXXL")
    }

    /// New forms and the item view with large and accessibility Dynamic Type.
    /// Formerly `PassYUiR5ShotsTests.test_dynamicTypeForms`.
    func test_dynamicTypeAddForms() {
        for size in ["UICTContentSizeCategoryXL", "UICTContentSizeCategoryAccessibilityL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", size])
            ensureUnlockedVault(app)
            let short = size.replacingOccurrences(of: "UICTContentSizeCategory", with: "").lowercased()
            XCTAssertTrue(openAdd(app, "Bank account"), "add menu reaches Bank account at \(short)")
            shot(app, 1, "\(short)-add-bank"); closeSheet(app)
            XCTAssertTrue(openAdd(app, "Login"), "add menu reaches Login at \(short)")
            shot(app, 2, "\(short)-add-login"); closeSheet(app)
            app.terminate()
        }
    }

    /// Formerly `PassYZAppearanceTests.test_largeText`.
    func test_largeTextWalk() {
        let app = launchApp(extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        walkScreens(app, prefix: "xxxl")
    }

    /// Idle: the "+" menu opens, leads to the add sheet and closes 12 times per text size (normal, accessibility L, accessibility XXXL) and every round is quick. A menu whose
    /// glass animation never reports its end makes XCUITest wait 60 s per action ("App animations complete
    /// notification not received"); one such round fails this test.
    /// Formerly `PassYUiR9Tests.test07_addMenuOpenCloseLoop`.
    func test_addMenuOpenCloseLoopNoIdleStall() {
        var slowest = 0.0
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", size])
            ensureUnlockedVault(app)
            let plus = app.buttons["AddItemFloatingActionButton"]
            XCTAssertTrue(plus.waitForExistence(timeout: 20))
            for round in 1 ... 12 {
                let start = Date()
                plus.tap()
                let entry = menuButton(app, id: "none", label: "Login")
                XCTAssertTrue(entry.waitForExistence(timeout: 10), "\(size) round \(round): the add menu opens")
                // Open the add sheet through the menu and close it again (the path of the real tests).
                entry.tap()
                XCTAssertTrue(app.textFields["ItemNameEntry"].waitForExistence(timeout: 15), "\(size) round \(round): the add sheet opens")
                closeSheet(app)
                XCTAssertTrue(plus.waitForExistence(timeout: 15), "\(size) round \(round): back on the vault")
                let took = Date().timeIntervalSince(start)
                slowest = max(slowest, took)
                XCTAssertLessThan(took, 40, "\(size) round \(round) took \(took) s (idle stall)")
            }
            app.terminate()
        }
        print("ADDMENU-LOOP slowest round \(slowest)")
    }
}
