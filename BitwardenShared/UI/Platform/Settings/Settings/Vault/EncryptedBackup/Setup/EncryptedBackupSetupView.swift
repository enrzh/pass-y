import BitwardenKit
import BitwardenResources
import SwiftUI
import UniformTypeIdentifiers

// MARK: - EncryptedBackupSetupView

/// The setup sheet of the encrypted backup: backup password (twice, with the strength indicator), folder (system
/// document picker) and the user verification of the vault export.
///
struct EncryptedBackupSetupView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<EncryptedBackupSetupState, EncryptedBackupSetupAction, EncryptedBackupSetupEffect>

    // MARK: View

    var body: some View {
        Form {
            if store.state.needsPassword {
                passwordSection
            }

            if store.state.needsFolder {
                Section {
                    PassYSettingsRow(
                        Localizations.backupFolder,
                        systemImage: "folder.fill",
                        tint: .blue,
                        value: store.state.folderText,
                        identifier: "EncryptedBackupChooseFolderRow",
                    ) {
                        store.send(.chooseFolderTapped)
                    }
                }
            }

            verificationSection
        }
        .passYGroupedBackground()
        .animation(.default, value: store.state.passwordStrengthScore)
        .navigationBar(title: store.state.title, titleDisplayMode: .inline)
        .fileImporter(
            isPresented: store.binding(
                get: \.isFolderPickerPresented,
                send: EncryptedBackupSetupAction.folderPickerPresented,
            ),
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
        ) { result in
            store.send(.folderPicked(try? result.get().first))
        }
        .task {
            await store.perform(.loadData)
        }
        .toast(store.binding(get: \.toast, send: EncryptedBackupSetupAction.toastShown))
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }

            ToolbarItem(placement: .topBarTrailing) {
                primaryActionToolbarButton(store.state.confirmTitle) {
                    Task { await store.perform(.confirmTapped) }
                }
                .accessibilityIdentifier("EncryptedBackupConfirmButton")
            }
        }
    }

    // MARK: Private Views

    /// The backup password fields.
    private var passwordSection: some View {
        Section {
            secureRow(
                title: Localizations.backupPassword,
                text: store.binding(get: \.passwordText, send: EncryptedBackupSetupAction.passwordTextChanged),
                visible: store.binding(
                    get: \.isPasswordVisible,
                    send: EncryptedBackupSetupAction.togglePasswordVisibility,
                ),
                fieldId: "BackupPasswordEntry",
                toggleId: "BackupPasswordVisibilityToggle",
            )

            secureRow(
                title: Localizations.confirmBackupPassword,
                text: store.binding(
                    get: \.passwordConfirmationText,
                    send: EncryptedBackupSetupAction.passwordConfirmationTextChanged,
                ),
                visible: store.binding(
                    get: \.isPasswordVisible,
                    send: EncryptedBackupSetupAction.togglePasswordVisibility,
                ),
                fieldId: "BackupPasswordConfirmEntry",
                toggleId: "BackupPasswordConfirmVisibilityToggle",
            )

            PasswordStrengthIndicator(
                passwordStrengthScore: store.state.passwordStrengthScore,
                passwordTextCount: store.state.passwordText.count,
                requiredTextCount: EncryptedBackupSetupState.minimumPasswordLength,
            )
        } footer: {
            Text(Localizations.backupPasswordDescription)
        }
    }

    /// The master password / OTP section (as on the export screen).
    private var verificationSection: some View {
        Section {
            secureRow(
                title: store.state.masterPasswordOrOtpTitle,
                text: store.binding(
                    get: \.masterPasswordOrOtpText,
                    send: EncryptedBackupSetupAction.masterPasswordOrOtpTextChanged,
                ),
                visible: store.binding(
                    get: \.isMasterPasswordOrOtpVisible,
                    send: EncryptedBackupSetupAction.toggleMasterPasswordOrOtpVisibility,
                ),
                fieldId: "MasterPasswordEntry",
                toggleId: "PasswordVisibilityToggle",
            )

            if !store.state.hasMasterPassword {
                Button {
                    Task { await store.perform(.sendCodeTapped) }
                } label: {
                    Label(Localizations.sendCode, systemImage: "envelope")
                }
                .accessibilityIdentifier("SendTOTPCodeButton")
                .disabled(store.state.isSendCodeButtonDisabled)
            }
        } header: {
            if !store.state.hasMasterPassword {
                Text(Localizations.sendVerificationCodeToEmail)
            }
        } footer: {
            Text(store.state.masterPasswordOrOtpFooter)
        }
    }

    /// A password row with a reveal button.
    private func secureRow(
        title: String,
        text: Binding<String>,
        visible: Binding<Bool>,
        fieldId: String,
        toggleId: String,
    ) -> some View {
        PassYPasswordField(
            title,
            text: text,
            isRevealed: visible.wrappedValue,
            contentType: nil,
            fieldIdentifier: fieldId,
            toggleIdentifier: toggleId,
        ) { visible.wrappedValue = $0 }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Turn on") {
    NavigationStack {
        EncryptedBackupSetupView(store: Store(processor: StateProcessor(state: EncryptedBackupSetupState(mode: .enable))))
    }
}
#endif
