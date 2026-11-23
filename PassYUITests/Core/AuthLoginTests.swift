import XCTest

/// Login with the master password against the throwaway Vaultwarden and the first sync.
final class AuthLoginTests: PassYUITestCase {
    // MARK: 02 Login + sync
    /// Formerly `PassYFlowTests.test02_loginAndSync`.
    func test_loginAndSync() {
        let app = launchApp()
        ensureUnlockedVault(app)
        XCTAssertTrue(app.staticTexts["My vault"].exists)
        attach(app, "02-vault")
    }
}
