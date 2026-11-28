import Foundation

// MARK: - EncryptedBackupPasswordStore

/// Where the backup password of an account lives: the keychain only (this device only, readable only while the
/// device is unlocked, never synced; see `BitwardenKeychainItem.encryptedBackupPassword`). Never in app settings,
/// `UserDefaults` or logs.
///
protocol EncryptedBackupPasswordStore: AnyObject {
    /// Removes the backup password of an account (no error when there is none).
    func deletePassword(userId: String) async throws

    /// The backup password of an account; throws when there is none.
    func password(userId: String) async throws -> String

    /// Stores the backup password of an account.
    func setPassword(_ password: String, userId: String) async throws
}

// MARK: - DefaultEncryptedBackupPasswordStore

/// The keychain implementation of `EncryptedBackupPasswordStore`.
///
final class DefaultEncryptedBackupPasswordStore: EncryptedBackupPasswordStore {
    /// The keychain repository.
    private let keychainRepository: KeychainRepository

    /// Creates the store.
    ///
    /// - Parameter keychainRepository: The keychain repository.
    ///
    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }

    func deletePassword(userId: String) async throws {
        try await keychainRepository.deleteUserAuthKey(for: .encryptedBackupPassword(userId: userId))
    }

    func password(userId: String) async throws -> String {
        try await keychainRepository.getUserAuthKeyValue(for: .encryptedBackupPassword(userId: userId))
    }

    func setPassword(_ password: String, userId: String) async throws {
        try await keychainRepository.setUserAuthKey(for: .encryptedBackupPassword(userId: userId), value: password)
    }
}
