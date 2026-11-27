// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

class EncryptedBackupViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<EncryptedBackupState, EncryptedBackupAction, EncryptedBackupEffect>!
    var subject: EncryptedBackupView!

    /// An active backup.
    let enabledStatus = EncryptedBackupStatus(
        isEnabled: true,
        folderName: "Pass-Y Backups",
        lastSuccessDate: Date(timeIntervalSince1970: 1_795_780_800),
    )

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        processor = MockProcessor(state: EncryptedBackupState())
        subject = EncryptedBackupView(store: Store(processor: processor))
    }

    override func tearDown() {
        super.tearDown()

        processor = nil
        subject = nil
    }

    // MARK: Tests

    /// Off: only the switch with its description; no folder, last backup or buttons.
    @MainActor
    func test_off() throws {
        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.encryptedBackup))
        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.encryptedBackupDescription))
        XCTAssertThrowsError(try subject.inspect().find(text: Localizations.lastBackup))
        XCTAssertThrowsError(try subject.inspect().find(passYInlineButtonRow: Localizations.backUpNow))
        XCTAssertThrowsError(try subject.inspect().find(text: Localizations.encryptedBackupFooter))
    }

    /// Tapping the switch sends `.toggleChanged`.
    @MainActor
    func test_toggle_tap() throws {
        try subject.inspect().find(viewWithAccessibilityIdentifier: "EncryptedBackupToggle").toggle().tap()
        XCTAssertEqual(processor.dispatchedActions.last, .toggleChanged(true))
    }

    /// On: folder, last backup, "Back up now", change password and the footer (what is not included).
    @MainActor
    func test_on_rows() throws {
        processor.state.status = enabledStatus

        XCTAssertNoThrow(try subject.inspect().find(text: "Pass-Y Backups"))
        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.lastBackup))
        XCTAssertNoThrow(try subject.inspect().find(text: processor.state.lastBackupText))
        XCTAssertNoThrow(try subject.inspect().find(passYInlineButtonRow: Localizations.backUpNow))
        XCTAssertNoThrow(try subject.inspect().find(button: Localizations.changeBackupPassword))
        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.encryptedBackupFooter))
        XCTAssertThrowsError(try subject.inspect().find(viewWithAccessibilityIdentifier: "EncryptedBackupErrorLabel"))
        XCTAssertNotEqual(processor.state.lastBackupText, Localizations.never)
    }

    /// The rows send their actions and effects.
    @MainActor
    func test_on_taps() async throws {
        processor.state.status = enabledStatus

        try subject.inspect().find(button: Localizations.changeBackupPassword).tap()
        XCTAssertEqual(processor.dispatchedActions.last, .changePasswordTapped)

        try subject.inspect().find(viewWithAccessibilityIdentifier: "EncryptedBackupFolderRow").button().tap()
        XCTAssertEqual(processor.dispatchedActions.last, .changeFolderTapped)

        try await subject.inspect().find(passYInlineButtonRow: Localizations.backUpNow).perform()
        XCTAssertEqual(processor.effects.last, .backUpNowTapped)
    }

    /// A failed backup shows its message with what to do.
    @MainActor
    func test_failure_visible() throws {
        processor.state.status = enabledStatus
        processor.state.status.lastFailure = .folderUnavailable

        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.backupErrorFolderUnavailable))
    }

    /// While a backup is written, "Backing up…" replaces the button (and hides an old error).
    @MainActor
    func test_running() throws {
        processor.state.status = enabledStatus
        processor.state.status.isRunning = true
        processor.state.status.lastFailure = .noSpace

        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.backingUp))
        XCTAssertThrowsError(try subject.inspect().find(passYInlineButtonRow: Localizations.backUpNow))
        XCTAssertThrowsError(try subject.inspect().find(text: Localizations.backupErrorNoSpace))
    }

    /// A policy that disables the export shows the short explanation.
    @MainActor
    func test_policy() throws {
        processor.state.isDisabledByPolicy = true

        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.encryptedBackupPolicyDisabled))
        XCTAssertTrue(try subject.inspect().find(viewWithAccessibilityIdentifier: "EncryptedBackupToggle").isDisabled())
    }
}
