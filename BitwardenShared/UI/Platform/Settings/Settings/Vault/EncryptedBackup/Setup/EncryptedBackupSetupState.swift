import BitwardenKit
import BitwardenResources
import Foundation

// MARK: - EncryptedBackupSetupMode

/// What the setup sheet of the encrypted backup sets up.
///
public enum EncryptedBackupSetupMode: Equatable, Hashable, Sendable {
    /// Turning the backup on: backup password and folder.
    case enable

    /// A new backup password.
    case changePassword

    /// A new folder.
    case changeFolder
}

// MARK: - EncryptedBackupSetupState

/// The state of the `EncryptedBackupSetupView`. Every mode asks for the user verification of the vault export
/// (master password, or a verification code without one).
///
struct EncryptedBackupSetupState: Equatable {
    // MARK: Constants

    /// The minimum length of the backup password (the vault export only requires a non-empty one).
    static let minimumPasswordLength = 12

    // MARK: Properties

    /// What the sheet sets up.
    var mode: EncryptedBackupSetupMode

    /// The chosen folder.
    var folderURL: URL?

    /// Whether the user has a master password (else a verification code is sent).
    var hasMasterPassword = true

    /// Whether the document picker is shown.
    var isFolderPickerPresented = false

    /// Whether the master password / OTP field shows its text.
    var isMasterPasswordOrOtpVisible = false

    /// Whether the backup password fields show their text.
    var isPasswordVisible = false

    /// Whether the send code button is disabled (a code was sent).
    var isSendCodeButtonDisabled = false

    /// The master password / OTP text.
    var masterPasswordOrOtpText = ""

    /// The backup password confirmation.
    var passwordConfirmationText = ""

    /// The strength of the backup password (0-4), `nil` while empty.
    var passwordStrengthScore: UInt8?

    /// The backup password.
    var passwordText = ""

    /// A toast message to show in the view.
    var toast: Toast?

    // MARK: Computed Properties

    /// The title of the confirm button.
    var confirmTitle: String {
        mode == .enable ? Localizations.turnOn : Localizations.save
    }

    /// The name of the chosen folder, or "Choose folder".
    var folderText: String {
        folderURL?.lastPathComponent ?? Localizations.chooseFolder
    }

    /// The footer of the master password / OTP field.
    var masterPasswordOrOtpFooter: String {
        hasMasterPassword ? Localizations.encryptedBackupMasterPasswordDescription : Localizations.confirmYourIdentity
    }

    /// The title of the master password / OTP field.
    var masterPasswordOrOtpTitle: String {
        hasMasterPassword ? Localizations.masterPassword : Localizations.verificationCode
    }

    /// Whether the sheet asks for a folder.
    var needsFolder: Bool {
        mode != .changePassword
    }

    /// Whether the sheet asks for a backup password.
    var needsPassword: Bool {
        mode != .changeFolder
    }

    /// The title of the sheet.
    var title: String {
        switch mode {
        case .enable: Localizations.encryptedBackup
        case .changePassword: Localizations.changeBackupPassword
        case .changeFolder: Localizations.changeBackupFolder
        }
    }
}
