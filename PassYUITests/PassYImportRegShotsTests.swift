import XCTest

/// Real taps through the rewritten Registration start and Export screens (light + dark). Needs a seeded Vaultwarden
/// (PASSY_SERVER, default http://localhost:8088). Screenshots are attached to the result bundle.
final class PassYImportRegShotsTests: XCTestCase {
    private func tag() -> String {
        (try? String(contentsOfFile: "/tmp/passy_ir_tag", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "ir"
    }

    /// Landing -> Create account: start registration form, fill, press Continue (no mail server: error or check-email).
    func test_registrationStart() {
        let t = tag()
        let app = launchApp()
        // The server sheet is presented automatically on a fresh install.
        let server = app.textFields["ServerUrlEntry"]
        if waitFor(server, timeout: 40) {
            server.tap(); server.typeText(TestAccount.server)
            app.buttons["SaveButton"].firstMatch.tap()
        }
        let create = app.buttons["CreateAccountButton"]
        XCTAssertTrue(waitFor(create), "landing offers Create account")
        create.tap()
        let email = app.textFields["EmailAddressEntry"]
        XCTAssertTrue(waitFor(email), "start registration shows the email field")
        sleep(1)
        attach(app, "\(t)-reg-start-light")
        XCUIDevice.shared.appearance = .dark
        sleep(2)
        attach(app, "\(t)-reg-start-dark")
        XCUIDevice.shared.appearance = .light
        email.tap(); email.typeText("passy-ir-new@example.test")
        let name = app.textFields["NameEntry"]
        name.tap(); name.typeText("IR Test")
        attach(app, "\(t)-reg-start-filled")
        app.keyboards.buttons["return"].firstMatch.tap()
        let cont = app.buttons["ContinueButton"]
        XCTAssertTrue(cont.waitForExistence(timeout: 5))
        cont.tap()
        sleep(4)
        attach(app, "\(t)-reg-start-after-continue")
    }

    /// Settings > Vault > Export vault > Export to a file: format picker, encrypted file password fields.
    func test_exportVault() {
        let t = tag()
        let app = launchApp()
        ensureUnlockedVault(app)
        app.tabBars.buttons["Settings"].tap()
        let vault = app.buttons["VaultSettingsButton"]
        XCTAssertTrue(waitFor(vault, timeout: 10)); vault.tap()
        let export = app.buttons["ExportVaultLabel"]
        XCTAssertTrue(waitFor(export, timeout: 10)); export.tap()
        let toFile = app.buttons["ExportVaultToAFileLabel"]
        XCTAssertTrue(waitFor(toFile, timeout: 10), "export settings list")
        attach(app, "\(t)-export-settings-light")
        XCUIDevice.shared.appearance = .dark
        sleep(2)
        attach(app, "\(t)-export-settings-dark")
        XCUIDevice.shared.appearance = .light
        toFile.tap()
        let picker = app.buttons["FileFormatPicker"]
        XCTAssertTrue(waitFor(picker, timeout: 10), "export form shows the file format picker")
        attach(app, "\(t)-export-form-light")
        picker.tap(); sleep(1)
        let enc = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Password protected'")).firstMatch
        let encItem = app.menuItems.matching(NSPredicate(format: "label CONTAINS 'Password protected'")).firstMatch
        XCTAssertTrue(enc.waitForExistence(timeout: 5) || encItem.exists, "picker offers encrypted json")
        (encItem.exists ? encItem : enc).tap(); sleep(1)
        XCTAssertTrue(app.secureTextFields["FilePasswordEntry"].firstMatch.waitForExistence(timeout: 5),
                      "file password fields appear for encrypted json")
        attach(app, "\(t)-export-form-encrypted-light")
        XCUIDevice.shared.appearance = .dark
        sleep(2)
        attach(app, "\(t)-export-form-encrypted-dark")
        XCUIDevice.shared.appearance = .light
        let mp = app.secureTextFields["MasterPasswordEntry"]
        XCTAssertTrue(mp.exists, "master password field")
        app.buttons["ExportVaultButton"].tap()
        sleep(2)
        attach(app, "\(t)-export-tap-without-input")
    }
}
