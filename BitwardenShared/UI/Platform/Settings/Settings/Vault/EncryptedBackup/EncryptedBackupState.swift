import BitwardenKit
import BitwardenResources
import Foundation

// MARK: - EncryptedBackupState

/// The state of the `EncryptedBackupView`.
///
struct EncryptedBackupState: Equatable {
    // MARK: Properties

    /// Whether an organization policy disables the personal vault export (and with it the backup).
    var isDisabledByPolicy = false

    /// The status of the backup.
    var status = EncryptedBackupStatus.off

    /// A toast message to show in the view.
    var toast: Toast?

    // MARK: Computed Properties

    /// The message of the last failure with what to do, `nil` after a success.
    var failureMessage: String? {
        status.lastFailure?.localizedMessage
    }

    /// The time of the last successful backup, or "Never".
    var lastBackupText: String {
        status.lastSuccessDate?.formatted(date: .abbreviated, time: .shortened) ?? Localizations.never
    }
}

// MARK: - EncryptedBackupFailure + Message

extension EncryptedBackupFailure {
    /// A short message with what to do.
    var localizedMessage: String {
        switch self {
        case .disabledByPolicy:
            Localizations.backupErrorDisabledByPolicy
        case .exportFailed:
            Localizations.backupErrorExportFailed
        case .folderUnavailable:
            Localizations.backupErrorFolderUnavailable
        case .noAccess:
            Localizations.backupErrorNoAccess
        case .noSpace:
            Localizations.backupErrorNoSpace
        case .passwordMissing:
            Localizations.backupErrorPasswordMissing
        case let .writeFailed(message):
            Localizations.backupErrorWriteFailedX(message)
        }
    }
}
