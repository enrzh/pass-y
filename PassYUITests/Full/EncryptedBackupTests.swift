import XCTest

/// End to end: Settings > Vault > Encrypted backup against the throwaway Vaultwarden (not part of the regular chain).
/// `test_encryptedBackup_turnOnAndBackUp` turns the backup on (test backup password, folder "PassY Backups" in
/// "On My iPhone"), waits for the first backup, taps Back up now and attaches screenshots;
/// `test_encryptedBackup_germanScreenshots` (after it, launched in German) attaches the page and the password sheet.
/// Before the run create the folder with a foreign file that must survive: in the app group directory of
/// `~/Library/Developer/CoreSimulator/Devices/<udid>/data/Containers/Shared/AppGroup/` whose container metadata names
/// `group.com.apple.FileProvider.LocalStorage`, create `File Provider Storage/PassY Backups/notes.txt`. Check the written files outside the app with
/// `PASSY_BACKUP_PASSWORD=PassY-Backup-Test-2026 Scripts-passy/vaultwarden/decrypt_backup.py <file> --expect-items N`.
final class EncryptedBackupTests: PassYUITestCase {
    /// The test backup password (test value only, also used by the decrypt check).
    static let backupPassword = "PassY-Backup-Test-2026"

    /// The folder in "On My iPhone".
    static let folderName = "PassY Backups"

    func test_encryptedBackup_turnOnAndBackUp() throws {
        let app = launchApp()
        ensureUnlockedVault(app)
        openEncryptedBackup(app)
        attach(app, "backup-page-off-en")

        let toggle = app.switches["EncryptedBackupToggle"]
        XCTAssertTrue(waitFor(toggle, timeout: 10), "encrypted backup switch")
        if (toggle.value as? String) == "1" {
            // A leftover configuration from an earlier run: turn it off first.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            let turnOff = app.alerts.buttons["Turn off"]
            XCTAssertTrue(turnOff.waitForExistence(timeout: 10)); turnOff.tap()
            XCTAssertTrue(waitUntil(15) { (toggle.value as? String) == "0" })
        }
        // A tap on the label of a SwiftUI switch row does not switch it: tap the switch itself (right edge).
        let password = app.secureTextFields["BackupPasswordEntry"]
        for _ in 0 ..< 3 where !password.exists {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            _ = password.waitForExistence(timeout: 15)
        }
        XCTAssertTrue(waitFor(password, timeout: 20), "setup sheet\n\(app.debugDescription)")
        password.replaceText(Self.backupPassword)
        app.secureTextFields["BackupPasswordConfirmEntry"].replaceText(Self.backupPassword)
        attach(app, "backup-setup-en")

        // The folder first: the picker also closes the keyboard, which covers the master password field.
        app.buttons["EncryptedBackupChooseFolderRow"].tap()
        pickFolder(app)
        XCTAssertTrue(waitUntil(20) {
            app.buttons["EncryptedBackupChooseFolderRow"].label.contains(Self.folderName)
        }, "picked folder shown\n\(app.debugDescription)")
        app.secureTextFields["MasterPasswordEntry"].replaceText(TestAccount.password)
        attach(app, "backup-setup-folder-en")

        app.buttons["EncryptedBackupConfirmButton"].tap()
        let lastBackup = app.descendants(matching: .any)["EncryptedBackupLastBackupRow"]
        XCTAssertTrue(waitFor(lastBackup, timeout: 60), "page shows the active backup")
        XCTAssertTrue(waitUntil(180) {
            !lastBackup.label.contains("Never") && !app.descendants(matching: .any)["EncryptedBackupRunningLabel"].exists
        }, "first backup written\n\(app.debugDescription)")
        XCTAssertFalse(app.descendants(matching: .any)["EncryptedBackupErrorLabel"].exists, "no error shown")
        attach(app, "backup-page-on-en")

        // Back up now writes a second file (rotation is unit tested).
        let now = app.buttons["EncryptedBackupNowButton"]
        XCTAssertTrue(waitFor(now, timeout: 20))
        now.tap()
        XCTAssertTrue(waitUntil(120) { now.exists && now.isHittable }, "back up now finished")
        XCTAssertFalse(app.descendants(matching: .any)["EncryptedBackupErrorLabel"].exists, "no error after back up now")
        attach(app, "backup-page-after-now-en")
    }

    /// Screenshots of the page in German (an earlier run turned the backup on).
    func test_encryptedBackup_germanScreenshots() throws {
        let app = launchApp(extraArguments: ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"])
        ensureUnlockedVault(app)
        openEncryptedBackup(app, settingsLabel: "Einstellungen")
        XCTAssertTrue(waitFor(app.switches["EncryptedBackupToggle"], timeout: 10))
        attach(app, "backup-page-de")
        let change = app.buttons["EncryptedBackupChangePasswordRow"]
        if change.waitForExistence(timeout: 5) {
            change.tap()
            XCTAssertTrue(waitFor(app.secureTextFields["BackupPasswordEntry"], timeout: 15))
            attach(app, "backup-change-password-de")
        }
    }

    // MARK: Helpers

    /// Settings > Vault > Encrypted backup.
    private func openEncryptedBackup(_ app: XCUIApplication, settingsLabel: String = "Settings") {
        if settingsLabel == "Settings" {
            goTo(app, "Settings")
        } else {
            // `goTo` detects the open avatar menu by English labels: open it and pick the localized entry directly.
            let avatar = app.buttons["CurrentActiveAccount"]
            XCTAssertTrue(waitFor(avatar, timeout: 15)); avatar.tap()
            let entry = app.descendants(matching: .any).matching(NSPredicate(
                format: "identifier == 'ProfileMenuSettingsButton' OR label == %@", settingsLabel)).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 15), "avatar menu\n\(app.debugDescription)"); entry.tap()
        }
        let vault = app.buttons["VaultSettingsButton"]
        XCTAssertTrue(waitFor(vault, timeout: 15)); vault.tap()
        let row = app.buttons["EncryptedBackupLabel"]
        XCTAssertTrue(waitFor(row, timeout: 15), "Vault settings offers Encrypted backup"); row.tap()
    }

    /// In the system folder picker: On My iPhone > PassY Backups > Open.
    private func pickFolder(_ app: XCUIApplication) {
        func element(_ label: String) -> XCUIElement {
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        // The picker opens on Recents or Browse; get to the Browse locations.
        XCTAssertTrue(waitUntil(30) { element("Browse").exists || element("On My iPhone").exists },
                      "folder picker\n\(app.debugDescription)")
        if !element("On My iPhone").exists { element("Browse").tap() }
        let onMyPhone = element("On My iPhone")
        if !onMyPhone.waitForExistence(timeout: 10) {
            // Browse shows the last location: go back to the locations list.
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(onMyPhone.waitForExistence(timeout: 10), "On My iPhone\n\(app.debugDescription)")
        onMyPhone.tap()
        let folder = element(Self.folderName)
        XCTAssertTrue(folder.waitForExistence(timeout: 20), "folder in On My iPhone\n\(app.debugDescription)")
        // A tap on the name does not open a folder in the icon view: tap its icon above the name.
        let openFolder = {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: folder.frame.midX, dy: folder.frame.minY - 45)).tap()
        }
        openFolder()
        // "Open" exists on every level: wait until the picker shows the folder before choosing it.
        // The runner puts a foreign file `notes.txt` into the folder: it is listed (dimmed) once the folder is open.
        let inside = { element("notes.txt").exists || element("notes").exists }
        if !waitUntil(10, inside) {
            attach(app, "backup-picker-after-folder-tap")
            if folder.exists { openFolder() }
        }
        XCTAssertTrue(waitUntil(20, inside), "picker inside the folder\n\(app.debugDescription)")
        let open = app.buttons["Open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Open button\n\(app.debugDescription)")
        attach(app, "backup-picker")
        open.tap()
    }
}
