import BitwardenResources
import Foundation

// MARK: - VaultSettingsState

/// An object that defines the current state of the `VaultSettingsView`.
///
struct VaultSettingsState {
    // MARK: Properties

    /// The state of the badges in the settings tab.
    var badgeState: SettingsBadgeState?

    /// The status of the encrypted backup.
    var encryptedBackupStatus = EncryptedBackupStatus.off

    /// The import items URL.
    var url: URL?

    // MARK: Computed Properties

    /// The badge of the encrypted backup row: shown when the last backup failed.
    var encryptedBackupBadge: String? {
        encryptedBackupStatus.isEnabled && encryptedBackupStatus.lastFailure != nil ? "!" : nil
    }

    /// The value of the encrypted backup row ("On" / "Off").
    var encryptedBackupValue: String {
        encryptedBackupStatus.isEnabled ? Localizations.on : Localizations.off
    }

    /// Whether the import logins action card should be shown.
    var shouldShowImportLoginsActionCard: Bool {
        badgeState?.importLoginsSetupProgress == .setUpLater
    }
}
