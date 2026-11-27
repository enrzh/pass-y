// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

class EncryptedBackupSetupViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<EncryptedBackupSetupState, EncryptedBackupSetupAction, EncryptedBackupSetupEffect>!
    var subject: EncryptedBackupSetupView!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        processor = MockProcessor(state: EncryptedBackupSetupState(mode: .enable))
        subject = EncryptedBackupSetupView(store: Store(processor: processor))
    }

    override func tearDown() {
        super.tearDown()

        processor = nil
        subject = nil
    }

    // MARK: Tests

    /// Turning on asks for the backup password twice (with the strength indicator), a folder and the master password.
    @MainActor
    func test_enable_fields() throws {
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "BackupPasswordEntry"))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "BackupPasswordConfirmEntry"))
        XCTAssertNoThrow(try subject.inspect().find(PasswordStrengthIndicator.self))
        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.backupPasswordDescription))
        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.chooseFolder))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "MasterPasswordEntry"))
        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.encryptedBackupMasterPasswordDescription))
        XCTAssertThrowsError(try subject.inspect().find(button: Localizations.sendCode))
    }

    /// The folder row opens the document picker; the chosen folder is shown.
    @MainActor
    func test_folderRow() throws {
        try subject.inspect().find(viewWithAccessibilityIdentifier: "EncryptedBackupChooseFolderRow").button().tap()
        XCTAssertEqual(processor.dispatchedActions.last, .chooseFolderTapped)

        processor.state.folderURL = URL(fileURLWithPath: "/Pass-Y Backups", isDirectory: true)
        XCTAssertNoThrow(try subject.inspect().find(text: "Pass-Y Backups"))
    }

    /// "Change password" has no folder row.
    @MainActor
    func test_changePassword_fields() throws {
        processor.state = EncryptedBackupSetupState(mode: .changePassword)

        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "BackupPasswordEntry"))
        XCTAssertThrowsError(try subject.inspect().find(viewWithAccessibilityIdentifier: "EncryptedBackupChooseFolderRow"))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "MasterPasswordEntry"))
    }

    /// "Change folder" has no password fields.
    @MainActor
    func test_changeFolder_fields() throws {
        processor.state = EncryptedBackupSetupState(mode: .changeFolder)

        XCTAssertThrowsError(try subject.inspect().find(viewWithAccessibilityIdentifier: "BackupPasswordEntry"))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "EncryptedBackupChooseFolderRow"))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "MasterPasswordEntry"))
    }

    /// Without a master password: the verification code field and the send code button.
    @MainActor
    func test_noMasterPassword() throws {
        processor.state.hasMasterPassword = false

        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.sendVerificationCodeToEmail))
        try subject.inspect().find(button: Localizations.sendCode).tap()
        try waitFor(!processor.effects.isEmpty)
        XCTAssertEqual(processor.effects.last, .sendCodeTapped)
    }
}
