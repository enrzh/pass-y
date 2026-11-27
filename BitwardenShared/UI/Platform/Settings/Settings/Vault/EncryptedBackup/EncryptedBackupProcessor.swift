import BitwardenKit
import BitwardenResources
import Foundation

// MARK: - EncryptedBackupProcessor

/// The processor of the encrypted backup page (Settings > Vault > Encrypted backup).
///
final class EncryptedBackupProcessor: StateProcessor<EncryptedBackupState, EncryptedBackupAction, EncryptedBackupEffect> {
    // MARK: Types

    typealias Services = HasEncryptedBackupService
        & HasErrorReporter
        & HasPolicyService
        & HasStateService

    // MARK: Properties

    /// The coordinator used to manage navigation.
    private let coordinator: AnyCoordinator<SettingsRoute, SettingsEvent>

    /// The services used by this processor.
    private let services: Services

    // MARK: Initialization

    /// Creates the processor.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator used for navigation.
    ///   - services: The services used by the processor.
    ///   - state: The initial state.
    ///
    init(
        coordinator: AnyCoordinator<SettingsRoute, SettingsEvent>,
        services: Services,
        state: EncryptedBackupState = EncryptedBackupState(),
    ) {
        self.coordinator = coordinator
        self.services = services
        super.init(state: state)
    }

    // MARK: Methods

    override func perform(_ effect: EncryptedBackupEffect) async {
        switch effect {
        case .backUpNowTapped:
            await backUpNow()
        case .streamStatus:
            await streamStatus()
        }
    }

    override func receive(_ action: EncryptedBackupAction) {
        switch action {
        case .changeFolderTapped:
            coordinator.navigate(to: .encryptedBackupSetup(.changeFolder), context: self)
        case .changePasswordTapped:
            coordinator.navigate(to: .encryptedBackupSetup(.changePassword), context: self)
        case let .toggleChanged(isOn):
            if isOn {
                guard !state.isDisabledByPolicy else { return }
                coordinator.navigate(to: .encryptedBackupSetup(.enable), context: self)
            } else {
                confirmTurnOff()
            }
        case let .toastShown(toast):
            state.toast = toast
        }
    }

    // MARK: Private

    /// Writes a backup now and shows a toast when it worked (the error stays visible on the page otherwise).
    private func backUpNow() async {
        guard let userId = try? await services.stateService.getActiveAccountId() else { return }
        state.status.isRunning = true
        await services.encryptedBackupService.backUpNow(userId: userId)
        await loadStatus(userId: userId)
        if state.status.lastFailure == nil, state.status.lastSuccessDate != nil {
            state.toast = Toast(title: Localizations.backupSaved)
        }
    }

    /// Asks before turning the backup off.
    private func confirmTurnOff() {
        coordinator.showAlert(Alert(
            title: Localizations.turnOffEncryptedBackupQuestion,
            message: Localizations.turnOffEncryptedBackupMessage,
            alertActions: [
                AlertAction(title: Localizations.cancel, style: .cancel),
                AlertAction(title: Localizations.turnOff, style: .destructive) { [weak self] _ in
                    await self?.turnOff()
                },
            ],
        ))
    }

    /// Loads the status and the policy of an account.
    private func loadStatus(userId: String) async {
        state.isDisabledByPolicy = await services.policyService.policyAppliesToUser(.disablePersonalVaultExport)
        state.status = await services.encryptedBackupService.status(userId: userId)
    }

    /// Loads the status and follows its changes while the page is shown.
    private func streamStatus() async {
        guard let userId = try? await services.stateService.getActiveAccountId() else { return }
        await loadStatus(userId: userId)
        for await changedUserId in services.encryptedBackupService.statusChangesPublisher().values
            where changedUserId == userId {
            state.status = await services.encryptedBackupService.status(userId: userId)
        }
    }

    /// Turns the backup off.
    private func turnOff() async {
        do {
            let userId = try await services.stateService.getActiveAccountId()
            try await services.encryptedBackupService.disable(userId: userId)
            await loadStatus(userId: userId)
        } catch {
            services.errorReporter.log(error: error)
            await coordinator.showErrorAlert(error: error)
        }
    }
}

// MARK: - EncryptedBackupSetupDelegate

extension EncryptedBackupProcessor: EncryptedBackupSetupDelegate {
    func encryptedBackupSetupCompleted(mode: EncryptedBackupSetupMode) async {
        // The first backup (or the first one with the new password or folder) is written right away.
        await backUpNow()
    }
}
