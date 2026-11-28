import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import TestHelpers
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// swiftlint:disable:next type_body_length
class EncryptedBackupSetupProcessorTests: BitwardenTestCase {
    // MARK: Properties

    var authRepository: MockAuthRepository!
    var coordinator: MockCoordinator<SettingsRoute, SettingsEvent>!
    var delegate: MockEncryptedBackupSetupDelegate!
    var encryptedBackupService: MockEncryptedBackupService!
    var errorReporter: MockErrorReporter!
    var policyService: MockPolicyService!
    var stateService: MockStateService!
    var subject: EncryptedBackupSetupProcessor!

    let folderURL = URL(fileURLWithPath: "/Backups", isDirectory: true)
    let password = "correct horse battery"

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        authRepository = MockAuthRepository()
        coordinator = MockCoordinator()
        delegate = MockEncryptedBackupSetupDelegate()
        encryptedBackupService = MockEncryptedBackupService()
        errorReporter = MockErrorReporter()
        policyService = MockPolicyService()
        stateService = MockStateService()
        stateService.activeAccount = .fixture(profile: .fixture(userId: "1"))
        makeSubject(mode: .enable)
    }

    override func tearDown() {
        super.tearDown()

        authRepository = nil
        coordinator = nil
        delegate = nil
        encryptedBackupService = nil
        errorReporter = nil
        policyService = nil
        stateService = nil
        subject = nil
    }

    // MARK: Helpers

    @MainActor
    func makeSubject(mode: EncryptedBackupSetupMode) {
        subject = EncryptedBackupSetupProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            delegate: delegate,
            mode: mode,
            services: ServiceContainer.withMocks(
                authRepository: authRepository,
                encryptedBackupService: encryptedBackupService,
                errorReporter: errorReporter,
                policyService: policyService,
                stateService: stateService,
            ),
        )
    }

    /// Fills the sheet with valid input.
    @MainActor
    func fillValidInput() {
        subject.receive(.passwordTextChanged(password))
        subject.receive(.passwordConfirmationTextChanged(password))
        subject.receive(.folderPicked(folderURL))
        subject.receive(.masterPasswordOrOtpTextChanged("master"))
    }

    // MARK: Tests - Turn on

    /// Valid input, verified master password: the backup is turned on, the secrets are cleared from the state, the
    /// sheet is dismissed and the delegate is told (it writes the first backup).
    @MainActor
    func test_confirm_enable_success() async throws {
        fillValidInput()

        await subject.perform(.confirmTapped)

        XCTAssertEqual(authRepository.validatePasswordPasswords, ["master"])
        XCTAssertEqual(encryptedBackupService.enableCalls.count, 1)
        XCTAssertEqual(encryptedBackupService.enableCalls.first?.password, password)
        XCTAssertEqual(encryptedBackupService.enableCalls.first?.folderURL, folderURL)
        XCTAssertEqual(encryptedBackupService.enableCalls.first?.userId, "1")
        XCTAssertTrue(subject.state.passwordText.isEmpty)
        XCTAssertTrue(subject.state.passwordConfirmationText.isEmpty)
        XCTAssertTrue(subject.state.masterPasswordOrOtpText.isEmpty)

        guard case let .dismiss(action) = coordinator.routes.last else {
            return XCTFail("The sheet was not dismissed.")
        }
        action?.action()
        try await waitForAsync { self.delegate.completedModes == [.enable] }
    }

    /// An empty backup password is an input validation error.
    @MainActor
    func test_confirm_emptyPassword() async {
        subject.receive(.folderPicked(folderURL))
        subject.receive(.masterPasswordOrOtpTextChanged("master"))

        await subject.perform(.confirmTapped)

        XCTAssertEqual(
            coordinator.alertShown.last,
            .inputValidationAlert(error: InputValidationError(
                message: Localizations.validationFieldRequired(Localizations.backupPassword),
            )),
        )
        XCTAssertTrue(encryptedBackupService.enableCalls.isEmpty)
    }

    /// A backup password under 12 characters is refused.
    @MainActor
    func test_confirm_shortPassword() async {
        fillValidInput()
        subject.receive(.passwordTextChanged("short pass1"))
        subject.receive(.passwordConfirmationTextChanged("short pass1"))

        await subject.perform(.confirmTapped)

        XCTAssertEqual(coordinator.alertShown.last, .defaultAlert(title: Localizations.backupPasswordTooShort))
        XCTAssertTrue(authRepository.validatePasswordPasswords.isEmpty)
        XCTAssertTrue(encryptedBackupService.enableCalls.isEmpty)
    }

    /// Different confirmation: "passwords don't match".
    @MainActor
    func test_confirm_mismatch() async {
        fillValidInput()
        subject.receive(.passwordConfirmationTextChanged("something else entirely"))

        await subject.perform(.confirmTapped)

        XCTAssertEqual(coordinator.alertShown.last, .passwordsDontMatch)
        XCTAssertTrue(encryptedBackupService.enableCalls.isEmpty)
    }

    /// Without a folder: "choose a folder".
    @MainActor
    func test_confirm_noFolder() async {
        fillValidInput()
        subject.state.folderURL = nil

        await subject.perform(.confirmTapped)

        XCTAssertEqual(coordinator.alertShown.last, .defaultAlert(title: Localizations.chooseABackupFolder))
        XCTAssertTrue(encryptedBackupService.enableCalls.isEmpty)
    }

    /// Without the master password: input validation error, nothing verified.
    @MainActor
    func test_confirm_noMasterPassword() async {
        fillValidInput()
        subject.receive(.masterPasswordOrOtpTextChanged(""))

        await subject.perform(.confirmTapped)

        XCTAssertEqual(
            coordinator.alertShown.last,
            .inputValidationAlert(error: InputValidationError(
                message: Localizations.validationFieldRequired(Localizations.masterPassword),
            )),
        )
        XCTAssertTrue(authRepository.validatePasswordPasswords.isEmpty)
    }

    /// A wrong master password stops the setup.
    @MainActor
    func test_confirm_invalidMasterPassword() async {
        authRepository.validatePasswordResult = .success(false)
        fillValidInput()

        await subject.perform(.confirmTapped)

        XCTAssertEqual(coordinator.alertShown.last, .defaultAlert(title: Localizations.invalidMasterPassword))
        XCTAssertTrue(encryptedBackupService.enableCalls.isEmpty)
    }

    /// Without a master password a verification code is checked instead.
    @MainActor
    func test_confirm_otp() async {
        subject.state.hasMasterPassword = false
        fillValidInput()

        await subject.perform(.confirmTapped)

        XCTAssertEqual(authRepository.verifyOtpOpt, "master")
        XCTAssertTrue(authRepository.validatePasswordPasswords.isEmpty)
        XCTAssertEqual(encryptedBackupService.enableCalls.count, 1)
    }

    /// A wrong verification code stops the setup.
    @MainActor
    func test_confirm_otpInvalid() async {
        authRepository.verifyOtpResult = .failure(
            ServerError.error(errorResponse: ErrorResponseModel(validationErrors: nil, message: "")),
        )
        subject.state.hasMasterPassword = false
        fillValidInput()

        await subject.perform(.confirmTapped)

        XCTAssertEqual(coordinator.alertShown.last, .defaultAlert(title: Localizations.invalidVerificationCode))
        XCTAssertTrue(encryptedBackupService.enableCalls.isEmpty)
    }

    /// An organization policy that disables the export blocks the setup.
    @MainActor
    func test_confirm_policy() async {
        policyService.policyAppliesToUserResult[.disablePersonalVaultExport] = true
        fillValidInput()

        await subject.perform(.confirmTapped)

        XCTAssertEqual(coordinator.alertShown.last, .defaultAlert(title: Localizations.encryptedBackupPolicyDisabled))
        XCTAssertTrue(authRepository.validatePasswordPasswords.isEmpty)
        XCTAssertTrue(encryptedBackupService.enableCalls.isEmpty)
    }

    /// A folder that cannot be bookmarked shows "no access" and keeps the sheet.
    @MainActor
    func test_confirm_bookmarkFails() async {
        encryptedBackupService.enableError = EncryptedBackupError.folderBookmarkFailed
        fillValidInput()

        await subject.perform(.confirmTapped)

        XCTAssertEqual(coordinator.alertShown.last, .defaultAlert(title: Localizations.backupErrorNoAccess))
        XCTAssertFalse(coordinator.routes.contains { if case .dismiss = $0 { true } else { false } })
        XCTAssertNil(delegate.completedModes.first)
    }

    // MARK: Tests - Change password / folder

    /// "Change password" needs the password and the verification, not a folder.
    @MainActor
    func test_confirm_changePassword() async {
        makeSubject(mode: .changePassword)
        XCTAssertFalse(subject.state.needsFolder)
        XCTAssertEqual(subject.state.title, Localizations.changeBackupPassword)
        subject.receive(.passwordTextChanged(password))
        subject.receive(.passwordConfirmationTextChanged(password))
        subject.receive(.masterPasswordOrOtpTextChanged("master"))

        await subject.perform(.confirmTapped)

        XCTAssertEqual(authRepository.validatePasswordPasswords, ["master"])
        XCTAssertEqual(encryptedBackupService.changePasswordCalls.first?.password, password)
    }

    /// "Change folder" needs the folder and the verification, not a password.
    @MainActor
    func test_confirm_changeFolder() async {
        makeSubject(mode: .changeFolder)
        XCTAssertFalse(subject.state.needsPassword)
        subject.receive(.folderPicked(folderURL))
        subject.receive(.masterPasswordOrOtpTextChanged("master"))

        await subject.perform(.confirmTapped)

        XCTAssertEqual(authRepository.validatePasswordPasswords, ["master"])
        XCTAssertEqual(encryptedBackupService.changeFolderCalls.first?.url, folderURL)
    }

    // MARK: Tests - Other

    /// `.loadData` loads whether the user has a master password.
    @MainActor
    func test_perform_loadData() async {
        stateService.userHasMasterPassword["1"] = false

        await subject.perform(.loadData)

        XCTAssertFalse(subject.state.hasMasterPassword)
        XCTAssertEqual(subject.state.masterPasswordOrOtpTitle, Localizations.verificationCode)
    }

    /// `.sendCodeTapped` requests a code and disables the button.
    @MainActor
    func test_perform_sendCode() async {
        await subject.perform(.sendCodeTapped)

        XCTAssertTrue(authRepository.requestOtpCalled)
        XCTAssertTrue(subject.state.isSendCodeButtonDisabled)
        XCTAssertEqual(subject.state.toast, Toast(title: Localizations.codeSent))
    }

    /// The folder picker opens and returns the folder; a cancelled pick keeps the old one.
    @MainActor
    func test_receive_folderPicker() {
        subject.receive(.chooseFolderTapped)
        XCTAssertTrue(subject.state.isFolderPickerPresented)
        XCTAssertEqual(subject.state.folderText, Localizations.chooseFolder)

        subject.receive(.folderPicked(folderURL))
        XCTAssertFalse(subject.state.isFolderPickerPresented)
        XCTAssertEqual(subject.state.folderText, "Backups")

        subject.receive(.folderPicked(nil))
        XCTAssertEqual(subject.state.folderURL, folderURL)
    }

    /// Typing the backup password updates the strength indicator.
    @MainActor
    func test_receive_passwordTextChanged_strength() async throws {
        authRepository.passwordStrengthResult = .success(3)

        subject.receive(.passwordTextChanged(password))

        try await waitForAsync { self.subject.state.passwordStrengthScore == 3 }
        subject.receive(.passwordTextChanged(""))
        XCTAssertNil(subject.state.passwordStrengthScore)
    }

    /// Cancel dismisses the sheet without changes.
    @MainActor
    func test_receive_dismiss() {
        subject.receive(.dismiss)

        XCTAssertEqual(coordinator.routes.last, .dismiss())
        XCTAssertTrue(encryptedBackupService.enableCalls.isEmpty)
    }
}

// MARK: - MockEncryptedBackupSetupDelegate

@MainActor
class MockEncryptedBackupSetupDelegate: EncryptedBackupSetupDelegate {
    var completedModes = [EncryptedBackupSetupMode]()

    func encryptedBackupSetupCompleted(mode: EncryptedBackupSetupMode) async {
        completedModes.append(mode)
    }
}
