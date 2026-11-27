import Foundation

@testable import BitwardenShared

/// An in-memory `EncryptedBackupFileSystem`: folders are paths with files (name → data); a bookmark is the folder
/// path as data.
///
final class FakeEncryptedBackupFileSystem: EncryptedBackupFileSystem {
    /// The folders: path → (file name → content).
    var folders = [String: [String: Data]]()

    /// Whether `startAccessing` grants the access.
    var grantsAccess = true

    /// The number of open security-scoped accesses (must end at 0).
    private(set) var openAccesses = 0

    /// Bookmarks that resolve as stale.
    var staleBookmarks = Set<Data>()

    /// Errors to throw.
    var makeBookmarkError: Error?
    var resolveError: Error?
    var listError: Error?
    var removeError: Error?
    var writeError: Error?

    /// The names of the removed files, in order.
    private(set) var removedFiles = [String]()

    /// The URLs written, in order.
    private(set) var writtenURLs = [URL]()

    /// Creates a bookmark for a folder path.
    static func bookmark(_ path: String) -> Data {
        Data(path.utf8)
    }

    func makeBookmark(for folderURL: URL) throws -> Data {
        if let makeBookmarkError { throw makeBookmarkError }
        return Self.bookmark(folderURL.path)
    }

    func resolveBookmark(_ bookmark: Data) throws -> (url: URL, isStale: Bool) {
        if let resolveError { throw resolveError }
        return (URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self), isDirectory: true),
                staleBookmarks.contains(bookmark))
    }

    func startAccessing(_ url: URL) -> Bool {
        guard grantsAccess else { return false }
        openAccesses += 1
        return true
    }

    func stopAccessing(_ url: URL) {
        openAccesses -= 1
    }

    func folderExists(at url: URL) -> Bool {
        folders[url.path] != nil
    }

    func fileNames(inFolder url: URL) throws -> [String] {
        if let listError { throw listError }
        return Array(folders[url.path, default: [:]].keys)
    }

    func write(_ data: Data, to url: URL) throws {
        if let writeError { throw writeError }
        writtenURLs.append(url)
        folders[url.deletingLastPathComponent().path, default: [:]][url.lastPathComponent] = data
    }

    func removeFile(at url: URL) throws {
        if let removeError { throw removeError }
        removedFiles.append(url.lastPathComponent)
        folders[url.deletingLastPathComponent().path]?[url.lastPathComponent] = nil
    }
}

/// An in-memory `EncryptedBackupPasswordStore` (the keychain fake).
///
final class FakeEncryptedBackupPasswordStore: EncryptedBackupPasswordStore {
    /// The passwords by user ID.
    var passwords = [String: String]()

    /// An error thrown by `setPassword`.
    var setError: Error?

    func deletePassword(userId: String) async throws {
        passwords[userId] = nil
    }

    func password(userId: String) async throws -> String {
        guard let password = passwords[userId] else { throw EncryptedBackupError.notEnabled }
        return password
    }

    func setPassword(_ password: String, userId: String) async throws {
        if let setError { throw setError }
        passwords[userId] = password
    }
}
