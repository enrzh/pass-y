import XCTest

/// The avatar menu (top right) is the only way between the top-level screens.
final class AvatarMenuTests: PassYUITestCase {
    /// The avatar menu: Send, Generator, Settings, pending login requests, sync; the server URL on top; no Vault, no
    /// account entries, no Add account, no "Pass-Y".
    /// Formerly `PassYUiR9Tests.test01_avatarMenu`.
    func test_menuEntriesServerUrlNoAccountEntries() {
        let app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertTrue(openAvatarMenu(app), "avatar menu opens")
        for label in ["Send", "Generator", "Settings"] {
            XCTAssertTrue(avatarMenuEntry(app, label).exists, "menu entry \(label)")
        }
        XCTAssertTrue(menuButton(app, id: "ProfileMenuPendingRequestsButton", label: "Pending login requests").exists, "pending login requests in the menu")
        XCTAssertTrue(menuButton(app, id: "ProfileMenuSyncButton", label: "Sync now").exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label == %@", "My vault")).firstMatch.exists, "ui-r9: no Vault entry in the avatar menu (on the vault home the bar has no Vault button either)")
        XCTAssertFalse(app.buttons["ProfileMenuVaultButton"].exists, "no Vault entry")
        XCTAssertFalse(app.buttons["Add account"].exists, "no Add account in the menu")
        XCTAssertFalse(containing(app, "passy-test@example.test").allElementsBoundByIndex.contains { $0.elementType == .button },
                       "no signed-in account entry in the menu")
        XCTAssertGreaterThan(containing(app, "localhost").count, 0, "the connected server URL is shown")
        XCTAssertFalse(app.staticTexts["Pass-Y"].exists)
        shot(app, 1, "avatar-menu")
    }

    // MARK: 19 to 22: ui-r3 shell (no tab bar, avatar menu, persistent bottom search, bigger tiles)
    /// There is no tab bar; Vault, Send, Generator and Settings are only reachable from the avatar menu, which
    /// is a single plain avatar (no second container) in the top right.
    /// Formerly `PassYFlowTests.test19_noTabBarAndAvatarMenuNavigates`.
    func test_noTabBarAndMenuNavigates() {
        let app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertEqual(app.tabBars.count, 0, "no tab bar on the vault screen")
        let avatar = app.buttons["CurrentActiveAccount"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10), "avatar menu button exists")
        XCTAssertLessThanOrEqual(avatar.frame.width, 56, "avatar is a plain 30 pt avatar, not wrapped in a capsule: \(avatar.frame)")
        XCTAssertLessThanOrEqual(avatar.frame.height, 56, "avatar height: \(avatar.frame)")
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(avatar.frame.midX, window.width * 0.8, "avatar is at the trailing edge")
        XCTAssertLessThan(avatar.frame.midY, 120, "avatar is in the navigation bar")
        attach(app, "19-vault-avatar")
        for label in ["Send", "Generator", "Settings"] {
            XCTAssertTrue(avatarMenuEntry(app, label).exists, "avatar menu has \(label)")
        }
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label == %@", "My vault")).firstMatch.exists, "ui-r9: no Vault entry in the avatar menu (on the vault home the bar has no Vault button either)")
        XCTAssertFalse(app.buttons["ProfileMenuVaultButton"].exists, "ui-r9: no Vault entry in the avatar menu")
        XCTAssertFalse(app.staticTexts["Pass-Y"].exists, "ui-r9: the menu shows the server URL, not the app name")
        XCTAssertTrue(menuButton(app, id: "ProfileMenuPendingRequestsButton", label: "Pending login requests").exists, "ui-r9: pending login requests in the menu")
        XCTAssertFalse(app.buttons["Add account"].exists, "ui-r9: no Add account in the avatar menu (Settings only)")
        attach(app, "19-avatar-menu")
        // Close the menu by choosing Send.
        avatarMenuEntry(app, "Send").tap()
        XCTAssertTrue(app.staticTexts["Send"].waitForExistence(timeout: 10), "Send opened from the avatar menu (title)")
        XCTAssertEqual(app.tabBars.count, 0)
        XCTAssertTrue(app.buttons["CurrentActiveAccount"].exists, "avatar also on the Send screen")
        attach(app, "19-send")
        goTo(app, "Generator")
        XCTAssertTrue(waitFor(app.staticTexts["GeneratedPasswordLabel"]), "Generator opened from the avatar menu")
        XCTAssertTrue(app.staticTexts["Generator"].exists, "Generator title")
        attach(app, "19-generator")
        goTo(app, "Settings")
        XCTAssertTrue(waitFor(app.buttons["AccountSecuritySettingsButton"]), "Settings opened from the avatar menu")
        XCTAssertEqual(app.tabBars.count, 0)
        attach(app, "19-settings")
        goTo(app, "My vault")
        XCTAssertTrue(waitFor(app.buttons["AddItemFloatingActionButton"]), "vault shown again")
        XCTAssertTrue(app.staticTexts["My vault"].exists, "vault title")
        attach(app, "19-vault")
    }
}
