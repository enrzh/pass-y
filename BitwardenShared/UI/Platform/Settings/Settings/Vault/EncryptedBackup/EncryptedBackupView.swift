import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - EncryptedBackupView

/// The encrypted backup page (Settings > Vault > Encrypted backup): switch, folder, last backup, "Back up now",
/// change password and one footer.
///
struct EncryptedBackupView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<EncryptedBackupState, EncryptedBackupAction, EncryptedBackupEffect>

    // MARK: View

    var body: some View {
        Form {
            if store.state.isDisabledByPolicy {
                Section {
                    Label(Localizations.encryptedBackupPolicyDisabled, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("EncryptedBackupPolicyLabel")
                }
            }

            Section {
                PassYToggleRow(
                    Localizations.encryptedBackup,
                    systemImage: "lock.doc.fill",
                    tint: .indigo,
                    isOn: store.binding(get: \.status.isEnabled, send: EncryptedBackupAction.toggleChanged),
                    identifier: "EncryptedBackupToggle",
                )
                .disabled(store.state.isDisabledByPolicy && !store.state.status.isEnabled)
            } footer: {
                Text(Localizations.encryptedBackupDescription)
            }

            if store.state.status.isEnabled {
                backupSection
            }
        }
        .passYGroupedBackground()
        .animation(.default, value: store.state.status)
        .navigationBar(title: Localizations.encryptedBackup, titleDisplayMode: .inline)
        .task {
            await store.perform(.streamStatus)
        }
        .toast(store.binding(get: \.toast, send: EncryptedBackupAction.toastShown))
    }

    // MARK: Private Views

    /// The rows of an active backup.
    private var backupSection: some View {
        Section {
            PassYSettingsRow(
                Localizations.backupFolder,
                systemImage: "folder.fill",
                tint: .blue,
                value: store.state.status.folderName,
                identifier: "EncryptedBackupFolderRow",
            ) {
                store.send(.changeFolderTapped)
            }
            .disabled(store.state.isDisabledByPolicy)

            PassYValueRow(
                Localizations.lastBackup,
                value: store.state.lastBackupText,
                systemImage: "clock.fill",
                tint: .gray,
                identifier: "EncryptedBackupLastBackupRow",
            )

            if let failureMessage = store.state.failureMessage, !store.state.status.isRunning {
                Label {
                    Text(failureMessage)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                .font(.footnote)
                .accessibilityIdentifier("EncryptedBackupErrorLabel")
            }

            if store.state.status.isRunning {
                HStack(spacing: PassYDesign.Spacing.small) {
                    ProgressView()
                    Text(Localizations.backingUp)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("EncryptedBackupRunningLabel")
            } else {
                PassYInlineButtonRow(
                    Localizations.backUpNow,
                    systemImage: "arrow.clockwise",
                    identifier: "EncryptedBackupNowButton",
                ) {
                    await store.perform(.backUpNowTapped)
                }
                .disabled(store.state.isDisabledByPolicy)
            }

            PassYSettingsRow(
                Localizations.changeBackupPassword,
                systemImage: "key.fill",
                tint: .orange,
                identifier: "EncryptedBackupChangePasswordRow",
            ) {
                store.send(.changePasswordTapped)
            }
            .disabled(store.state.isDisabledByPolicy)
        } footer: {
            Text(Localizations.encryptedBackupFooter)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Encrypted backup") {
    NavigationStack {
        EncryptedBackupView(store: Store(processor: StateProcessor(state: EncryptedBackupState(
            status: EncryptedBackupStatus(isEnabled: true, folderName: "Pass-Y Backups", lastSuccessDate: .now),
        ))))
    }
}
#endif
