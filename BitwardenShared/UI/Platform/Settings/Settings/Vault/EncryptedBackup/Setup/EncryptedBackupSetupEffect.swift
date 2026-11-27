// MARK: - EncryptedBackupSetupEffect

/// Effects handled by the `EncryptedBackupSetupProcessor`.
///
enum EncryptedBackupSetupEffect: Equatable {
    /// The confirm button ("Turn on" / "Save") was tapped.
    case confirmTapped

    /// The sheet appeared.
    case loadData

    /// The send code button was tapped (accounts without a master password).
    case sendCodeTapped
}
