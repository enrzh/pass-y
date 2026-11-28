import BitwardenKit

// MARK: - EncryptedBackupAction

/// Actions handled by the `EncryptedBackupProcessor`.
///
enum EncryptedBackupAction: Equatable {
    /// The change folder row was tapped.
    case changeFolderTapped

    /// The change password row was tapped.
    case changePasswordTapped

    /// The switch changed.
    case toggleChanged(Bool)

    /// The toast was shown or hidden.
    case toastShown(Toast?)
}
