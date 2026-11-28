import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import TestHelpers
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

class EncryptedBackupProcessorTests: BitwardenTestCase {
    // MARK: Properties

    var coordinator: MockCoordinator<SettingsRoute, SettingsEvent>!
    var encryptedBackupService: MockEncryptedBackupService!
    var errorReporter: MockErrorReporter!
    var policyService: MockPolicyService!
    var stateService: MockStateService!
    var subject: EncryptedBackupProcessor!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        coordinator = MockCoordinator()
        encryptedBackupService = MockEncryptedBackupService()
        errorReporter = MockErrorReporter()
        policyService = MockPolicyService()
        stateService = MockStateService()
        stateService.activeAccount = .fixture(profile: .fixture(userId: "1"))

        subject = EncryptedBackupProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            services: ServiceContainer.withMocks(
                encryptedBackupService: encryptedBackupService,
                errorReporter: errorReporter,
                policyService: policyService,
                stateService: stateService,
            ),
        )
    }

    override func tearDown() {
        super.tearDown()

        coordinator = nil
        encryptedBackupService = nil
        errorReporter = nil
        policyService = nil
        stateService = nil
        subject = nil
    }

    // MARK: Tests

    /// `.streamStatus` loads the status and the policy and follows status changes of the active account.
    @MainActor
    func test_perform_streamStatus() async throws {
        encryptedBackupService.statusByUserId["1"] = EncryptedBackupStatus(isEnabled: true, folderName: "Backups")
        policyService.policyAppliesToUserResult[.disablePersonalVaultExport] = true

        let task = Task { await subject.perform(.streamStatus) }
        defer { task.cancel() }
        try await waitForAsync { self.subject.state.status.isEnabled }
        XCTAssertTrue(subject.state.isDisabledByPolicy)
        XCTAssertEqual(subject.state.status.folderName, "Backups")

        encryptedBackupService.statusByUserId["1"]?.isRunning = true
        // Another account's change is ignored; the subscription starts after the first load, so send until seen.
        encryptedBackupService.statusSubject.send("2")
        try await waitForAsync {
            self.encryptedBackupService.statusSubject.send("1")
            return self.subject.state.status.isRunning
        }
    }

    /// Turning the switch on opens the setup sheet; not while a policy disables the export.
    @MainActor
    func test_receive_toggleOn() {
        subject.receive(.toggleChanged(true))
        XCTAssertEqual(coordinator.routes.last, .encryptedBackupSetup(.enable))
        XCTAssertTrue(coordinator.contexts.last as? EncryptedBackupProcessor === subject)

        coordinator.routes = []
        subject.state.isDisabledByPolicy = true
        subject.receive(.toggleChanged(true))
        XCTAssertTrue(coordinator.routes.isEmpty)
    }

    /// Turning the switch off asks first, then disables the backup.
    @MainActor
    func test_receive_toggleOff() async throws {
        subject.state.status = EncryptedBackupStatus(isEnabled: true, folderName: "Backups")

        subject.receive(.toggleChanged(false))

        let alert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(alert.title, Localizations.turnOffEncryptedBackupQuestion)
        XCTAssertEqual(alert.message, Localizations.turnOffEncryptedBackupMessage)
        XCTAssertTrue(encryptedBackupService.disableUserIds.isEmpty)

        try await alert.tapAction(title: Localizations.turnOff)

        XCTAssertEqual(encryptedBackupService.disableUserIds, ["1"])
        XCTAssertFalse(subject.state.status.isEnabled)
    }

    /// A failing disable shows an error.
    @MainActor
    func test_receive_toggleOff_error() async throws {
        encryptedBackupService.disableError = BitwardenTestError.example
        subject.receive(.toggleChanged(false))

        try await coordinator.alertShown.last?.tapAction(title: Localizations.turnOff)

        XCTAssertEqual(errorReporter.errors.last as? BitwardenTestError, .example)
        XCTAssertEqual(coordinator.errorAlertsShown.last as? BitwardenTestError, .example)
    }

    /// The change rows open the setup sheet in their mode.
    @MainActor
    func test_receive_changeRows() {
        subject.receive(.changePasswordTapped)
        XCTAssertEqual(coordinator.routes.last, .encryptedBackupSetup(.changePassword))
        subject.receive(.changeFolderTapped)
        XCTAssertEqual(coordinator.routes.last, .encryptedBackupSetup(.changeFolder))
    }

    /// "Back up now" runs the backup and shows a toast when it worked.
    @MainActor
    func test_perform_backUpNow_success() async {
        encryptedBackupService.statusByUserId["1"] = EncryptedBackupStatus(
            isEnabled: true,
            folderName: "Backups",
            lastSuccessDate: Date(),
        )

        await subject.perform(.backUpNowTapped)

        XCTAssertEqual(encryptedBackupService.backUpNowUserIds, ["1"])
        XCTAssertEqual(subject.state.toast, Toast(title: Localizations.backupSaved))
    }

    /// A failed "Back up now" shows no toast; the error is in the state for the page.
    @MainActor
    func test_perform_backUpNow_failure() async {
        encryptedBackupService.statusByUserId["1"] = EncryptedBackupStatus(
            isEnabled: true,
            folderName: "Backups",
            lastFailure: .noSpace,
        )

        await subject.perform(.backUpNowTapped)

        XCTAssertNil(subject.state.toast)
        XCTAssertEqual(subject.state.failureMessage, Localizations.backupErrorNoSpace)
    }

    /// A completed setup writes the first backup right away.
    @MainActor
    func test_setupCompleted_backsUp() async {
        await subject.encryptedBackupSetupCompleted(mode: .enable)

        XCTAssertEqual(encryptedBackupService.backUpNowUserIds, ["1"])
    }

    /// Every failure has a short message with what to do.
    @MainActor
    func test_failureMessages() {
        let failures: [EncryptedBackupFailure] = [
            .disabledByPolicy, .exportFailed, .folderUnavailable, .noAccess, .noSpace, .passwordMissing,
            .writeFailed("Offline"),
        ]
        let messages = failures.map(\.localizedMessage)
        XCTAssertEqual(Set(messages).count, failures.count)
        XCTAssertTrue(messages.last?.contains("Offline") == true)
        XCTAssertEqual(EncryptedBackupState().lastBackupText, Localizations.never)
    }
}
