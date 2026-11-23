import XCTest

/// The vault locks on restart, a wrong password is rejected, the right one unlocks.
final class LockUnlockTests: PassYUITestCase {
    // MARK: 07 Lock and unlock
    /// Formerly `PassYFlowTests.test07_lockAndUnlock`.
    func test_lockedAfterRestartWrongPasswordRejectedThenUnlock() {
        let app = launchApp()
        ensureUnlockedVault(app)
        app.terminate()
        let app2 = launchApp()
        let unlockPw = app2.secureTextFields["MasterPasswordEntry"]
        XCTAssertTrue(waitFor(unlockPw), "vault is locked after restart")
        attach(app2, "07-locked")
        unlockPw.tap(); unlockPw.typeText("wrong-password")
        app2.buttons["UnlockVaultButton"].tap()
        XCTAssertTrue(waitFor(app2.alerts.firstMatch, timeout: 15), "wrong password is rejected")
        app2.alerts.buttons.firstMatch.tap()
        ensureUnlockedVault(app2)
        XCTAssertTrue(app2.staticTexts["My vault"].exists)
        attach(app2, "07-unlocked")
    }
}
