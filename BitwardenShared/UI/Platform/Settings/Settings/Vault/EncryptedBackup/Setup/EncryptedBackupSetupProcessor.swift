import BitwardenKit
import BitwardenResources
import Foundation

// MARK: - EncryptedBackupSetupProcessor

/// The processor of the setup sheet of the encrypted backup (turn on, change password, change folder). Every mode
/// requires the user verification of the vault export first.
///
final class EncryptedBackupSetupProcessor: StateProcessor< // swiftlint:disable:this type_body_length
    EncryptedBackupSetupState,
    EncryptedBackupSetupAction,
    EncryptedBackupSetupEffect,
> {
    // MARK: Types

    typealias Services = HasAuthRepository
        & HasEncryptedBackupService
        & HasErrorReporter
        & HasPolicyService
        & HasStateService

    // MARK: Properties

    /// The coordinator used to manage navigation.
    private let coordinator: AnyCoordinator<SettingsRoute, SettingsEvent>

    /// The delegate told when the setup completed.
    private weak var delegate: EncryptedBackupSetupDelegate?

    /// The services used by this processor.
    private let services: Services

    // MARK: Initialization

    /// Creates the processor.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator used for navigation.
    ///   - delegate: The delegate told when the setup completed.
    ///   - mode: What the sheet sets up.
    ///   - services: The services used by the processor.
    ///
    init(
        coordinator: AnyCoordinator<SettingsRoute, SettingsEvent>,
        delegate: EncryptedBackupSetupDelegate?,
        mode: EncryptedBackupSetupMode,
        services: Services,
    ) {
        self.coordinator = coordinator
        self.delegate = delegate
        self.services = services
        super.init(state: EncryptedBackupSetupState(mode: mode))
    }

    // MARK: Methods

    override func perform(_ effect: EncryptedBackupSetupEffect) async {
        switch effect {
        case .confirmTapped:
            await confirm()
        case .loadData:
            await loadData()
        case .sendCodeTapped:
            await sendVerificationCode()
        }
    }

    override func receive(_ action: EncryptedBackupSetupAction) {
        switch action {
        case .chooseFolderTapped:
            state.isFolderPickerPresented = true
        case .dismiss:
            coordinator.navigate(to: .dismiss())
        case let .folderPicked(url):
            state.isFolderPickerPresented = false
            if let url {
                state.folderURL = url
            }
        case let .folderPickerPresented(isPresented):
            state.isFolderPickerPresented = isPresented
        case let .masterPasswordOrOtpTextChanged(text):
            state.masterPasswordOrOtpText = text
        case let .passwordConfirmationTextChanged(text):
            state.passwordConfirmationText = text
        case let .passwordTextChanged(text):
            state.passwordText = text
            updatePasswordStrength()
        case let .toastShown(toast):
            state.toast = toast
        case let .toggleMasterPasswordOrOtpVisibility(isVisible):
            state.isMasterPasswordOrOtpVisible = isVisible
        case let .togglePasswordVisibility(isVisible):
            state.isPasswordVisible = isVisible
        }
    }

    // MARK: Private

    /// Validates the input, verifies the user and applies the setup.
    private func confirm() async {
        do {
            if state.needsPassword {
                try EmptyInputValidator(fieldName: Localizations.backupPassword).validate(input: state.passwordText)
                guard state.passwordText.count >= EncryptedBackupSetupState.minimumPasswordLength else {
                    coordinator.showAlert(.defaultAlert(title: Localizations.backupPasswordTooShort))
                    return
                }
                guard state.passwordText == state.passwordConfirmationText else {
                    coordinator.showAlert(.passwordsDontMatch)
                    return
                }
            }
            if state.needsFolder, state.folderURL == nil {
                coordinator.showAlert(.defaultAlert(title: Localizations.chooseABackupFolder))
                return
            }
            try EmptyInputValidator(fieldName: state.masterPasswordOrOtpTitle)
                .validate(input: state.masterPasswordOrOtpText)
        } catch {
            coordinator.showAlert(.inputValidationAlert(error: error))
            return
        }

        guard await !services.policyService.policyAppliesToUser(.disablePersonalVaultExport) else {
            coordinator.showAlert(.defaultAlert(title: Localizations.encryptedBackupPolicyDisabled))
            return
        }
        guard await verifyUser() else { return }

        coordinator.showLoadingOverlay(LoadingOverlayState(title: Localizations.saving))
        do {
            let userId = try await services.stateService.getActiveAccountId()
            switch state.mode {
            case .enable:
                guard let folderURL = state.folderURL else { return }
                try await services.encryptedBackupService.enable(
                    password: state.passwordText,
                    folderURL: folderURL,
                    userId: userId,
                )
            case .changePassword:
                try await services.encryptedBackupService.changePassword(state.passwordText, userId: userId)
            case .changeFolder:
                guard let folderURL = state.folderURL else { return }
                try await services.encryptedBackupService.changeFolder(folderURL, userId: userId)
            }
            coordinator.hideLoadingOverlay()
        } catch {
            coordinator.hideLoadingOverlay()
            services.errorReporter.log(error: error)
            if error as? EncryptedBackupError == .folderBookmarkFailed {
                coordinator.showAlert(.defaultAlert(title: Localizations.backupErrorNoAccess))
            } else {
                await coordinator.showErrorAlert(error: error)
            }
            return
        }

        // Clear the secrets from the state before the sheet goes.
        let mode = state.mode
        state.passwordText = ""
        state.passwordConfirmationText = ""
        state.masterPasswordOrOtpText = ""
        state.passwordStrengthScore = nil
        let delegate = delegate
        coordinator.navigate(to: .dismiss(DismissAction(action: { [weak delegate] in
            Task { await delegate?.encryptedBackupSetupCompleted(mode: mode) }
        })))
    }

    /// Loads whether the user has a master password.
    private func loadData() async {
        do {
            state.hasMasterPassword = try await services.stateService.getUserHasMasterPassword()
        } catch {
            services.errorReporter.log(error: error)
            coordinator.showAlert(.defaultAlert(title: Localizations.anErrorHasOccurred))
        }
    }

    /// Sends a one-time verification code to the user.
    private func sendVerificationCode() async {
        coordinator.showLoadingOverlay(LoadingOverlayState(title: Localizations.sendingCode))
        defer { coordinator.hideLoadingOverlay() }
        do {
            try await services.authRepository.requestOtp()
            state.isSendCodeButtonDisabled = true
            state.toast = Toast(title: Localizations.codeSent)
        } catch {
            await coordinator.showErrorAlert(error: error)
            services.errorReporter.log(error: error)
        }
    }

    /// Updates the strength score of the backup password.
    private func updatePasswordStrength() {
        guard !state.passwordText.isEmpty else {
            state.passwordStrengthScore = nil
            return
        }
        let password = state.passwordText
        Task {
            do {
                let score = try await services.authRepository.passwordStrength(
                    email: "",
                    password: password,
                    isPreAuth: false,
                )
                guard state.passwordText == password else { return }
                state.passwordStrengthScore = score
            } catch {
                services.errorReporter.log(error: error)
            }
        }
    }

    /// Verifies the master password or the verification code (as the vault export does).
    ///
    /// - Returns: `true` when it is valid.
    ///
    private func verifyUser() async -> Bool {
        do {
            if state.hasMasterPassword {
                guard try await services.authRepository.validatePassword(state.masterPasswordOrOtpText) else {
                    coordinator.showAlert(.defaultAlert(title: Localizations.invalidMasterPassword))
                    return false
                }
            } else {
                try await services.authRepository.verifyOtp(state.masterPasswordOrOtpText)
            }
            return true
        } catch ServerError.error {
            coordinator.showAlert(.defaultAlert(title: Localizations.invalidVerificationCode))
            return false
        } catch {
            await coordinator.showErrorAlert(error: error)
            services.errorReporter.log(error: error)
            return false
        }
    }
}
