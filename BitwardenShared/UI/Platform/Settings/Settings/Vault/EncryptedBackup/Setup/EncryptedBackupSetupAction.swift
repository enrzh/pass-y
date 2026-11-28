import BitwardenKit
import Foundation

// MARK: - EncryptedBackupSetupAction

/// Actions handled by the `EncryptedBackupSetupProcessor`.
///
enum EncryptedBackupSetupAction: Equatable {
    /// The cancel button was tapped.
    case dismiss

    /// The folder row was tapped (opens the document picker).
    case chooseFolderTapped

    /// The document picker returned a folder (`nil`: cancelled or failed).
    case folderPicked(URL?)

    /// The document picker was shown or hidden.
    case folderPickerPresented(Bool)

    /// The master password / OTP text changed.
    case masterPasswordOrOtpTextChanged(String)

    /// The backup password confirmation changed.
    case passwordConfirmationTextChanged(String)

    /// The backup password changed.
    case passwordTextChanged(String)

    /// The toast was shown or hidden.
    case toastShown(Toast?)

    /// The visibility of the master password / OTP field changed.
    case toggleMasterPasswordOrOtpVisibility(Bool)

    /// The visibility of the backup password fields changed.
    case togglePasswordVisibility(Bool)
}
