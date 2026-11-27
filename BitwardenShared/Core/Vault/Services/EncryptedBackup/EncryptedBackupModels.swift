import Foundation

// MARK: - EncryptedBackupSettings

/// The per-account configuration and status of the automatic encrypted backup (Settings > Vault > Encrypted backup),
/// stored in `AppSettingsStore`. It never holds the backup password: that one lives in the keychain only
/// (`BitwardenKeychainItem.encryptedBackupPassword`).
///
struct EncryptedBackupSettings: Codable, Equatable {
    /// The bookmark of the destination folder the user picked with the document picker.
    var folderBookmark: Data

    /// The display name of the destination folder.
    var folderName: String

    /// The time of the last successful backup.
    var lastSuccessDate: Date?

    /// The fingerprint of the exported content at the last successful backup (ids and revision dates of the exported
    /// items and folders, see `EncryptedBackupContentFingerprint`), used to skip automatic runs without changes.
    var lastContentFingerprint: String?

    /// The time of the last attempt (successful or not).
    var lastAttemptDate: Date?

    /// The error of the last attempt, `nil` when it succeeded.
    var lastFailure: EncryptedBackupFailure?
}

// MARK: - EncryptedBackupFailure

/// Why a backup run failed. Persisted so the settings page can show it with what to do.
///
enum EncryptedBackupFailure: Codable, Equatable, Error {
    /// An organization policy disables the personal vault export.
    case disabledByPolicy

    /// The export itself failed (or did not return a password-protected file).
    case exportFailed

    /// The folder (or its bookmark) cannot be found any more.
    case folderUnavailable

    /// The app has no permission to write into the folder.
    case noAccess

    /// The device or the provider is out of space.
    case noSpace

    /// The backup password is missing in the keychain (for example after a restore onto another device).
    case passwordMissing

    /// Writing the file failed for another reason (provider error); the message is the system description.
    case writeFailed(String)
}

// MARK: - EncryptedBackupStatus

/// The state of the automatic encrypted backup of an account, as shown on the settings page.
///
struct EncryptedBackupStatus: Equatable {
    /// The status while the backup is off.
    static let off = EncryptedBackupStatus()

    /// Whether the backup is on (a configuration exists).
    var isEnabled = false

    /// The name of the destination folder.
    var folderName: String?

    /// The time of the last successful backup.
    var lastSuccessDate: Date?

    /// The error of the last attempt.
    var lastFailure: EncryptedBackupFailure?

    /// Whether a backup is being written right now.
    var isRunning = false
}

// MARK: - EncryptedBackupContentFingerprint

/// The input of the change detection: what identifies the exported content without decrypting anything. A
/// password-protected export gets a new salt and IV on every run, so the output itself cannot be compared.
///
struct EncryptedBackupContentFingerprint: Codable, Equatable {
    /// An exported item.
    struct Item: Codable, Equatable {
        let id: String
        let revisionDate: Date
        let archivedDate: Date?
        let folderId: String?
        let favorite: Bool
    }

    /// An exported folder.
    struct Folder: Codable, Equatable {
        let id: String
        let revisionDate: Date
    }

    /// The exported items, sorted by id.
    let items: [Item]

    /// The exported folders, sorted by id.
    let folders: [Folder]
}
