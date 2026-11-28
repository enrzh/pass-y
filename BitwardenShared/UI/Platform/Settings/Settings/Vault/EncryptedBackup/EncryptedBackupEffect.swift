// MARK: - EncryptedBackupEffect

/// Effects handled by the `EncryptedBackupProcessor`.
///
enum EncryptedBackupEffect: Equatable {
    /// "Back up now" was tapped.
    case backUpNowTapped

    /// The page appeared: load the status and follow its changes.
    case streamStatus
}
