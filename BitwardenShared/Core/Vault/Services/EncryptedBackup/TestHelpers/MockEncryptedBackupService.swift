import Combine
import Foundation

@testable import BitwardenShared

/// A mock `EncryptedBackupService`.
///
class MockEncryptedBackupService: EncryptedBackupService {
    var backUpNowUserIds = [String]()
    var changeFolderCalls = [(url: URL, userId: String)]()
    var changeFolderError: Error?
    var changePasswordCalls = [(password: String, userId: String)]()
    var changePasswordError: Error?
    var disableUserIds = [String]()
    var disableError: Error?
    var enableCalls = [(password: String, folderURL: URL, userId: String)]()
    var enableError: Error?
    var runAutomaticBackupIfDueCalled = false
    var scheduleAutomaticBackupCount = 0
    var statusByUserId = [String: EncryptedBackupStatus]()
    let statusSubject = PassthroughSubject<String, Never>()

    func backUpNow(userId: String) async {
        backUpNowUserIds.append(userId)
    }

    func changeFolder(_ folderURL: URL, userId: String) async throws {
        changeFolderCalls.append((folderURL, userId))
        if let changeFolderError { throw changeFolderError }
    }

    func changePassword(_ password: String, userId: String) async throws {
        changePasswordCalls.append((password, userId))
        if let changePasswordError { throw changePasswordError }
    }

    func disable(userId: String) async throws {
        disableUserIds.append(userId)
        if let disableError { throw disableError }
    }

    func enable(password: String, folderURL: URL, userId: String) async throws {
        enableCalls.append((password, folderURL, userId))
        if let enableError { throw enableError }
    }

    func runAutomaticBackupIfDue() async {
        runAutomaticBackupIfDueCalled = true
    }

    func scheduleAutomaticBackup() {
        scheduleAutomaticBackupCount += 1
    }

    func status(userId: String) async -> EncryptedBackupStatus {
        statusByUserId[userId] ?? .off
    }

    func statusChangesPublisher() -> AnyPublisher<String, Never> {
        statusSubject.eraseToAnyPublisher()
    }
}
