// MARK: - EncryptedBackupSetupDelegate

/// Told when the setup sheet of the encrypted backup completed.
///
@MainActor
protocol EncryptedBackupSetupDelegate: AnyObject {
    /// The setup completed (the sheet is being dismissed).
    ///
    /// - Parameter mode: What was set up.
    ///
    func encryptedBackupSetupCompleted(mode: EncryptedBackupSetupMode) async
}
