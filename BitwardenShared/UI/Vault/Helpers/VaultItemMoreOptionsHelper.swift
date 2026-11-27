import BitwardenKit
import BitwardenResources
import BitwardenSdk
import Foundation

// MARK: - VaultItemMoreOptionsHelper

/// A protocol for a helper object to perform the more-options actions of a vault item (chosen in the row's
/// context menu, its "More" swipe menu or a VoiceOver custom action).
///
protocol VaultItemMoreOptionsHelper {
    /// Performs the more-options action identified by `kind` for `item`.
    ///
    /// - Parameters
    ///   - kind: The kind of more-options action to perform.
    ///   - item: The selected item to perform the action on.
    ///   - delegate: The delegate notified of operations performed on the item from within the
    ///     add/edit item view, used when the edit option is selected.
    ///   - handleDisplayToast: A closure called to handle displaying a toast.
    ///   - handleNavigateToPremiumUpgrade: A closure called to navigate to the Premium upgrade flow.
    ///   - handleOpenURL: A closure called to open a URL.
    ///
    func performMoreOptionsAction( // swiftlint:disable:this function_parameter_count
        _ kind: MoreOptionsActionKind,
        for item: VaultListItem,
        delegate: CipherItemOperationDelegate?,
        handleDisplayToast: @escaping (Toast) -> Void,
        handleNavigateToPremiumUpgrade: @escaping () async -> Void,
        handleOpenURL: @escaping (URL) -> Void,
    ) async

    /// Moves an item into a folder (its "Move to folder" menu): master password re-prompt if the item requires it,
    /// then the update and a toast; errors show the error alert.
    ///
    /// - Parameters:
    ///   - item: The item (a cipher row or a code row).
    ///   - folderId: The folder, `nil` for no folder.
    ///   - handleDisplayToast: A closure called to handle displaying a toast.
    ///
    func moveToFolder(
        _ item: VaultListItem,
        folderId: String?,
        handleDisplayToast: @escaping (Toast) -> Void,
    ) async

    /// Creates a folder and moves an item into it ("New folder…" of its "Move to folder" menu): master password
    /// re-prompt if the item requires it, the folder name alert, then the folder, the move and a toast.
    ///
    /// - Parameters:
    ///   - item: The item (a cipher row or a code row).
    ///   - handleDisplayToast: A closure called to handle displaying a toast.
    ///   - onFolderCreated: Called after the folder was created (the page reloads its folders).
    ///
    func moveToNewFolder(
        _ item: VaultListItem,
        handleDisplayToast: @escaping (Toast) -> Void,
        onFolderCreated: @escaping () async -> Void,
    ) async
}

// MARK: - DefaultVaultItemMoreOptionsHelper

/// A default implementation of `VaultItemMoreOptionsHelper`.
///
@MainActor
class DefaultVaultItemMoreOptionsHelper: VaultItemMoreOptionsHelper {
    // MARK: Types

    typealias Services = HasAuthRepository
        & HasEnvironmentService
        & HasErrorReporter
        & HasEventService
        & HasPasteboardService
        & HasSettingsRepository
        & HasStateService
        & HasVaultRepository

    // MARK: Private Properties

    /// The `Coordinator` that handles navigation.
    private var coordinator: AnyCoordinator<VaultRoute, AuthAction>

    /// The helper to handle master password reprompts.
    private let masterPasswordRepromptHelper: MasterPasswordRepromptHelper

    /// The services used by this helper.
    private var services: Services

    // MARK: Initialization

    /// Initialize a `VaultItemMoreOptionsHelper`.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator that handles navigation.
    ///   - masterPasswordRepromptHelper: The helper to handle master password reprompts.
    ///   - services: The services used by this helper.
    ///
    init(
        coordinator: AnyCoordinator<VaultRoute, AuthAction>,
        masterPasswordRepromptHelper: MasterPasswordRepromptHelper,
        services: Services,
    ) {
        self.coordinator = coordinator
        self.masterPasswordRepromptHelper = masterPasswordRepromptHelper
        self.services = services
    }

    // MARK: Methods

    func performMoreOptionsAction( // swiftlint:disable:this function_parameter_count
        _ kind: MoreOptionsActionKind,
        for item: VaultListItem,
        delegate: CipherItemOperationDelegate?,
        handleDisplayToast: @escaping (Toast) -> Void,
        handleNavigateToPremiumUpgrade: @escaping () async -> Void,
        handleOpenURL: @escaping (URL) -> Void,
    ) async {
        do {
            guard case let .cipher(cipherListView, _) = item.itemType,
                  let cipherId = cipherListView.id,
                  let cipherView = try await services.vaultRepository.fetchCipher(withId: cipherId) else {
                return
            }

            let hasPremium = await services.vaultRepository.doesActiveAccountHavePremium()
            guard let action = kind.moreOptionsAction(cipherView: cipherView, itemId: item.id) else { return }

            await handleMoreOptionsAction(
                action,
                cipherView: cipherView,
                delegate: delegate,
                handleDisplayToast: handleDisplayToast,
                handleNavigateToPremiumUpgrade: handleNavigateToPremiumUpgrade,
                handleOpenURL: handleOpenURL,
                hasPremium: hasPremium,
            )
        } catch {
            services.errorReporter.log(error: error)
            coordinator.showAlert(.defaultAlert(title: Localizations.anErrorHasOccurred))
        }
    }

    func moveToFolder(
        _ item: VaultListItem,
        folderId: String?,
        handleDisplayToast: @escaping (Toast) -> Void,
    ) async {
        guard let cipher = await movableCipher(for: item), cipher.folderId != folderId else { return }
        await masterPasswordRepromptHelper.repromptForMasterPasswordIfNeeded(cipherView: cipher) {
            let name: String
            if let folderId {
                name = (try? await self.services.vaultRepository.fetchFolder(withId: folderId))?.name
                    ?? Localizations.folder
            } else {
                name = Localizations.folderNone
            }
            await self.move(cipher, folderId: folderId, folderName: name, handleDisplayToast: handleDisplayToast)
        }
    }

    func moveToNewFolder(
        _ item: VaultListItem,
        handleDisplayToast: @escaping (Toast) -> Void,
        onFolderCreated: @escaping () async -> Void,
    ) async {
        guard let cipher = await movableCipher(for: item) else { return }
        await masterPasswordRepromptHelper.repromptForMasterPasswordIfNeeded(cipherView: cipher) {
            self.coordinator.showAlert(.newFolderName { name in
                do {
                    let folder = try await self.services.settingsRepository.addFolder(name: name)
                    await onFolderCreated()
                    await self.move(
                        cipher,
                        folderId: folder.id,
                        folderName: folder.name,
                        handleDisplayToast: handleDisplayToast,
                    )
                } catch {
                    self.services.errorReporter.log(error: error)
                    await self.coordinator.showErrorAlert(error: error)
                }
            })
        }
    }

    // MARK: Private Methods

    /// The cipher of a row to move (a code row's cipher for a code row), `nil` (error alert shown) when it cannot be
    /// fetched.
    private func movableCipher(for item: VaultListItem) async -> CipherView? {
        guard let cipherId = (item.totpCipherItem ?? item).cipherId else { return nil }
        do {
            guard let cipher = try await services.vaultRepository.fetchCipher(withId: cipherId) else {
                coordinator.showAlert(.defaultAlert(title: Localizations.anErrorHasOccurred))
                return nil
            }
            return cipher
        } catch {
            services.errorReporter.log(error: error)
            coordinator.showAlert(.defaultAlert(title: Localizations.anErrorHasOccurred))
            return nil
        }
    }

    /// Saves the cipher in the folder and shows the "Moved to …" toast.
    private func move(
        _ cipher: CipherView,
        folderId: String?,
        folderName: String,
        handleDisplayToast: @escaping (Toast) -> Void,
    ) async {
        await performOperationAndShowToast(
            handleDisplayToast: handleDisplayToast,
            loadingTitle: Localizations.saving,
            toastTitle: Localizations.movedToX(folderName),
        ) {
            try await services.vaultRepository.updateCipher(cipher.update(folderId: folderId))
        }
    }

    /// Archives a cipher.
    ///
    /// - Parameters:
    ///   - cipher: The cipher to archive.
    ///   - handleDisplayToast: A closure to display a toast.
    ///   - handleNavigateToPremiumUpgrade: A closure called to navigate to the Premium upgrade flow.
    ///   - hasPremium: Whether the user has Premium account.
    private func archive(
        _ cipher: CipherView,
        handleDisplayToast: @escaping (Toast) -> Void,
        handleNavigateToPremiumUpgrade: @escaping () async -> Void,
        hasPremium: Bool,
    ) async {
        guard hasPremium else {
            coordinator.showAlert(
                Alert.archiveUnavailable(action: {
                    Task {
                        await handleNavigateToPremiumUpgrade()
                    }
                }),
            )
            return
        }

        coordinator.showAlert(Alert.confirmArchiveItem {
            await self.masterPasswordRepromptHelper.repromptForMasterPasswordIfNeeded(cipherView: cipher) {
                await self.performOperationAndShowToast(
                    handleDisplayToast: handleDisplayToast,
                    loadingTitle: Localizations.sendingToArchive,
                    toastTitle: Localizations.itemMovedToArchive,
                ) {
                    try await self.services.vaultRepository.archiveCipher(cipher)
                }
            }
        })
    }

    /// Generates and copies a TOTP code for the cipher's TOTP key.
    ///
    /// - Parameter totpKey: The TOTP key used to generate a TOTP code.
    ///
    private func generateAndCopyTotpCode(
        totpKey: TOTPKeyModel,
        handleDisplayToast: @escaping (Toast) -> Void,
    ) async {
        do {
            let response = try await services.vaultRepository.refreshTOTPCode(for: totpKey)
            guard let code = response.codeModel?.code else {
                throw TOTPServiceError.unableToGenerateCode(nil)
            }
            services.pasteboardService.copy(code)
            handleDisplayToast(
                Toast(title: Localizations.valueHasBeenCopied(Localizations.verificationCodeTotp)),
            )
        } catch {
            coordinator.showAlert(.defaultAlert(title: Localizations.anErrorHasOccurred))
            services.errorReporter.log(error: error)
        }
    }

    /// Handle the result of the selected option of the more-options menu.
    ///
    /// - Parameters:
    ///   - action: The selected action.
    ///   - cipherView: The cipher to act upon.
    ///   - delegate: The delegate notified of operations performed on the item from within the
    ///     add/edit item view, used when the edit option is selected.
    ///   - handleDisplayToast: A closure to display a toast.
    ///   - handleOpenURL: A closure to open an URL.
    ///   - hasPremium: Whether the user has Premium account.
    private func handleMoreOptionsAction( // swiftlint:disable:this function_body_length function_parameter_count
        _ action: MoreOptionsAction,
        cipherView: CipherView,
        delegate: CipherItemOperationDelegate?,
        handleDisplayToast: @escaping (Toast) -> Void,
        handleNavigateToPremiumUpgrade: @escaping () async -> Void,
        handleOpenURL: @escaping (URL) -> Void,
        hasPremium: Bool,
    ) async {
        switch action {
        case let .archive(cipher):
            await archive(
                cipher,
                handleDisplayToast: handleDisplayToast,
                handleNavigateToPremiumUpgrade: handleNavigateToPremiumUpgrade,
                hasPremium: hasPremium,
            )
        case let .copy(toast, value, requiresMasterPasswordReprompt, event, cipherId):
            let copyBlock = {
                self.services.pasteboardService.copy(value)
                handleDisplayToast(Toast(title: Localizations.valueHasBeenCopied(toast)))
                if let event {
                    Task {
                        await self.services.eventService.collect(
                            eventType: event,
                            cipherId: cipherId,
                        )
                    }
                }
            }
            if requiresMasterPasswordReprompt {
                await masterPasswordRepromptHelper.repromptForMasterPasswordIfNeeded(cipherView: cipherView) {
                    copyBlock()
                }
            } else {
                copyBlock()
            }
        case let .copyTotp(totpKey):
            await masterPasswordRepromptHelper.repromptForMasterPasswordIfNeeded(cipherView: cipherView) {
                await self.generateAndCopyTotpCode(totpKey: totpKey, handleDisplayToast: handleDisplayToast)
            }
        case let .edit(cipherView):
            await masterPasswordRepromptHelper.repromptForMasterPasswordIfNeeded(cipherView: cipherView) {
                self.coordinator.navigate(to: .editItem(cipherView), context: delegate)
            }
        case let .launch(url):
            handleOpenURL(url.sanitized)
        case let .unarchive(cipher):
            await masterPasswordRepromptHelper.repromptForMasterPasswordIfNeeded(cipherView: cipherView) {
                await self.performOperationAndShowToast(
                    handleDisplayToast: handleDisplayToast,
                    loadingTitle: Localizations.movingItemToVault,
                    toastTitle: Localizations.itemMovedToVault,
                ) {
                    try await self.services.vaultRepository.unarchiveCipher(cipher)
                }
            }
        case let .view(id):
            await masterPasswordRepromptHelper.repromptForMasterPasswordIfNeeded(cipherView: cipherView) {
                self.coordinator.navigate(to: .viewItem(id: id, masterPasswordRepromptCheckCompleted: true))
            }
        }
    }

    /// Performs an operation and shows a toast.
    /// - Parameters:
    ///   - loadingTitle: The title of the loading overlay.
    ///   - operation: The operation to execute.
    ///   - toastTitle: The title of the toast.
    private func performOperationAndShowToast(
        handleDisplayToast: @escaping (Toast) -> Void,
        loadingTitle: String,
        toastTitle: String,
        operation: () async throws -> Void,
    ) async {
        defer { coordinator.hideLoadingOverlay() }
        do {
            coordinator.showLoadingOverlay(.init(title: loadingTitle))

            try await operation()

            handleDisplayToast(Toast(title: toastTitle))
        } catch {
            await coordinator.showErrorAlert(error: error)
            services.errorReporter.log(error: error)
        }
    }
}

// MARK: - Alert + new folder

extension Alert {
    /// Asks for the name of a new folder ("New folder…" of the "Move to folder" menu).
    ///
    /// - Parameter completion: Called with the entered name.
    ///
    static func newFolderName(completion: @MainActor @escaping (String) async -> Void) -> Alert {
        Alert(
            title: Localizations.addFolder,
            message: nil,
            alertActions: [
                AlertAction(
                    title: Localizations.save,
                    style: .default,
                    handler: { _, alertTextFields in
                        guard let name = alertTextFields.first(where: { $0.id == "name" })?.text
                            .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }
                        await completion(name)
                    },
                    shouldEnableAction: { textFields in
                        guard let text = textFields.first(where: { $0.id == "name" })?.text else { return false }
                        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    },
                ),
                AlertAction(title: Localizations.cancel, style: .cancel),
            ],
            alertTextFields: [
                AlertTextField(id: "name", autocapitalizationType: .words, placeholder: Localizations.name),
            ],
        )
    }
}
