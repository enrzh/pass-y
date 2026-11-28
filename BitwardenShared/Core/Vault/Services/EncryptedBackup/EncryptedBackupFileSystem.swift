import Foundation

// MARK: - EncryptedBackupFileSystem

/// The file operations of the encrypted backup, behind a protocol so the tests use a fake. All calls are synchronous
/// and may block (file coordination with a provider); `DefaultEncryptedBackupService` runs them on its own queue.
///
protocol EncryptedBackupFileSystem: AnyObject {
    /// Creates a bookmark for a folder URL from the document picker (the caller holds its security-scoped access).
    func makeBookmark(for folderURL: URL) throws -> Data

    /// Resolves a folder bookmark.
    ///
    /// - Returns: The folder URL and whether the bookmark is stale (should be recreated).
    ///
    func resolveBookmark(_ bookmark: Data) throws -> (url: URL, isStale: Bool)

    /// Starts the security-scoped access to a URL. `false` can also mean that no scope is needed (own container).
    func startAccessing(_ url: URL) -> Bool

    /// Ends the security-scoped access to a URL.
    func stopAccessing(_ url: URL)

    /// Whether a folder exists at the URL.
    func folderExists(at url: URL) -> Bool

    /// The names of the files in a folder (no subfolders). iCloud placeholders of files that are not downloaded
    /// (`.name.icloud`) are reported with their real name.
    func fileNames(inFolder url: URL) throws -> [String]

    /// Writes data to a file atomically (temporary file and rename) with file coordination, replacing an existing file.
    func write(_ data: Data, to url: URL) throws

    /// Deletes a file with file coordination (or its iCloud placeholder when it is not downloaded).
    func removeFile(at url: URL) throws
}

// MARK: - DefaultEncryptedBackupFileSystem

/// The `FileManager` / `NSFileCoordinator` implementation of `EncryptedBackupFileSystem`.
///
final class DefaultEncryptedBackupFileSystem: EncryptedBackupFileSystem {
    /// The file manager.
    private let fileManager: FileManager

    /// Creates the file system.
    ///
    /// - Parameter fileManager: The file manager.
    ///
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func makeBookmark(for folderURL: URL) throws -> Data {
        try folderURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolveBookmark(_ bookmark: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
        return (url, isStale)
    }

    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    func folderExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func fileNames(inFolder url: URL) throws -> [String] {
        try coordinated { coordinator, coordinationError, run in
            coordinator.coordinate(readingItemAt: url, options: [], error: coordinationError) { readURL in
                run {
                    try self.fileManager.contentsOfDirectory(
                        at: readURL,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [],
                    ).compactMap { fileURL in
                        guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                            return nil
                        }
                        return Self.realName(of: fileURL.lastPathComponent)
                    }
                }
            }
        } ?? []
    }

    func write(_ data: Data, to url: URL) throws {
        _ = try coordinated { coordinator, coordinationError, run in
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: coordinationError) { writeURL in
                run { try data.write(to: writeURL, options: .atomic) }
            }
        }
    }

    func removeFile(at url: URL) throws {
        let placeholder = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).icloud", isDirectory: false)
        let target = !fileManager.fileExists(atPath: url.path) && fileManager.fileExists(atPath: placeholder.path)
            ? placeholder
            : url
        _ = try coordinated { coordinator, coordinationError, run in
            coordinator.coordinate(writingItemAt: target, options: .forDeleting, error: coordinationError) { deleteURL in
                run { try self.fileManager.removeItem(at: deleteURL) }
            }
        }
    }

    // MARK: Private

    /// Runs a file coordination. `body` gets the coordinator, the coordination error pointer and `run`, which
    /// executes the (throwing) work inside the coordination block and keeps its result or error. Throws the
    /// coordination error or the error of the work.
    private func coordinated<T>(
        _ body: (NSFileCoordinator, NSErrorPointer, (() throws -> T) -> Void) -> Void,
    ) throws -> T? {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<T, Error>?
        body(coordinator, &coordinationError) { work in
            result = Result { try work() }
        }
        if let coordinationError {
            throw coordinationError
        }
        return try result?.get()
    }

    /// The real name of a file: `.name.icloud` (an iCloud placeholder) is `name`.
    static func realName(of fileName: String) -> String {
        guard fileName.hasPrefix("."), fileName.hasSuffix(".icloud"), fileName.count > ".icloud".count + 1 else {
            return fileName
        }
        return String(fileName.dropFirst().dropLast(".icloud".count))
    }
}
