import BitwardenKit
@preconcurrency import Combine
import CryptoKit
import Foundation

// MARK: - EncryptedBackupService

/// The automatic encrypted backup of Pass-Y (Settings > Vault > Encrypted backup): a password-protected encrypted JSON
/// export (the one of Export vault, made by the SDK, importable into any Bitwarden/Vaultwarden web vault) written into a
/// folder the user picked, at most once a day when the exported content changed, plus "Back up now".
///
/// - Only the main app runs backups (never an extension), only for the active account while its vault is unlocked.
/// - The export exists only in memory and is written straight into the destination folder (atomic, coordinated).
///   Nothing unencrypted or account-key encrypted is ever written; a result that is not password protected is rejected.
/// - The last `keptBackups` files of the account's own naming pattern are kept; nothing else in the folder is touched.
///
protocol EncryptedBackupService: AnyObject {
    /// Writes a backup now, regardless of the schedule and of changes. The result is in `status(userId:)`.
    ///
    /// - Parameter userId: The account (must be the active one, unlocked).
    ///
    func backUpNow(userId: String) async

    /// Changes the destination folder.
    ///
    /// - Parameters:
    ///   - folderURL: The folder from the document picker.
    ///   - userId: The account.
    ///
    func changeFolder(_ folderURL: URL, userId: String) async throws

    /// Changes the backup password (for the next backups; the existing files keep their password).
    ///
    /// - Parameters:
    ///   - password: The new backup password.
    ///   - userId: The account.
    ///
    func changePassword(_ password: String, userId: String) async throws

    /// Turns the backup off: removes the password, the folder bookmark and the status. The files stay.
    ///
    /// - Parameter userId: The account.
    ///
    func disable(userId: String) async throws

    /// Turns the backup on.
    ///
    /// - Parameters:
    ///   - password: The backup password.
    ///   - folderURL: The folder from the document picker.
    ///   - userId: The account.
    ///
    func enable(password: String, folderURL: URL, userId: String) async throws

    /// Runs an automatic backup of the active account if one is due (vault unlocked, last backup at least a day old,
    /// content changed). Errors end up in the status.
    ///
    func runAutomaticBackupIfDue() async

    /// Schedules `runAutomaticBackupIfDue()` after a delay, off the main path (coalesced; main app only). Called after a
    /// successful sync and when the app comes to the foreground.
    ///
    func scheduleAutomaticBackup()

    /// The status of an account.
    ///
    /// - Parameter userId: The account.
    /// - Returns: The status.
    ///
    func status(userId: String) async -> EncryptedBackupStatus

    /// Publishes the user ID whose status changed.
    ///
    func statusChangesPublisher() -> AnyPublisher<String, Never>
}

// MARK: - EncryptedBackupError

/// Errors of the configuration calls of `EncryptedBackupService`.
///
enum EncryptedBackupError: Error, Equatable {
    /// The folder could not be bookmarked.
    case folderBookmarkFailed

    /// The backup is not on.
    case notEnabled
}

// MARK: - DefaultEncryptedBackupService

/// The default implementation of `EncryptedBackupService`.
///
actor DefaultEncryptedBackupService: EncryptedBackupService {
    // MARK: Constants

    /// The minimum time between two automatic backups.
    static let minimumInterval: TimeInterval = 24 * 60 * 60

    /// The minimum time between two automatic attempts after a failed one.
    static let retryInterval: TimeInterval = 60 * 60

    /// The number of backup files kept per account.
    static let keptBackups = 5

    /// The file name prefix of every backup file.
    static let fileNamePrefix = "passy-backup-"

    // MARK: Properties

    /// The app context (backups run in the main app only).
    private nonisolated let appContextHelper: AppContextHelper

    /// The settings store holding the configuration.
    private let appSettingsStore: AppSettingsStore

    /// The delay of a scheduled automatic run.
    private let automaticRunDelay: TimeInterval

    /// The error reporter.
    private let errorReporter: ErrorReporter

    /// The event service (a backup is a vault export for the organization event log).
    private let eventService: EventService

    /// The service creating the export.
    private let exportVaultService: ExportVaultService

    /// The file operations.
    private let fileSystem: EncryptedBackupFileSystem

    /// The queue running the blocking file operations.
    private let fileQueue = DispatchQueue(label: "com.passy.encryptedBackup.files", qos: .utility)

    /// The folder service (for the change detection).
    private let folderService: FolderService

    /// The keychain store of the backup password.
    private let passwordStore: EncryptedBackupPasswordStore

    /// The policy service.
    private let policyService: PolicyService

    /// The pending scheduled automatic run.
    private var scheduledRun: Task<Void, Never>?

    /// The accounts with a backup running.
    private var runningUserIds = Set<String>()

    /// The state service.
    private let stateService: StateService

    /// Publishes the user ID whose status changed.
    private nonisolated let statusSubject = PassthroughSubject<String, Never>()

    /// The clock.
    private let timeProvider: TimeProvider

    /// The vault timeout service (lock state).
    private let vaultTimeoutService: VaultTimeoutService

    // MARK: Initialization

    /// Creates the service.
    ///
    /// - Parameters:
    ///   - appContextHelper: The app context.
    ///   - appSettingsStore: The settings store holding the configuration.
    ///   - automaticRunDelay: The delay of a scheduled automatic run.
    ///   - errorReporter: The error reporter.
    ///   - eventService: The event service.
    ///   - exportVaultService: The service creating the export.
    ///   - fileSystem: The file operations.
    ///   - folderService: The folder service.
    ///   - passwordStore: The keychain store of the backup password.
    ///   - policyService: The policy service.
    ///   - stateService: The state service.
    ///   - timeProvider: The clock.
    ///   - vaultTimeoutService: The vault timeout service.
    ///
    init(
        appContextHelper: AppContextHelper,
        appSettingsStore: AppSettingsStore,
        automaticRunDelay: TimeInterval = 20,
        errorReporter: ErrorReporter,
        eventService: EventService,
        exportVaultService: ExportVaultService,
        fileSystem: EncryptedBackupFileSystem,
        folderService: FolderService,
        passwordStore: EncryptedBackupPasswordStore,
        policyService: PolicyService,
        stateService: StateService,
        timeProvider: TimeProvider,
        vaultTimeoutService: VaultTimeoutService,
    ) {
        self.appContextHelper = appContextHelper
        self.appSettingsStore = appSettingsStore
        self.automaticRunDelay = automaticRunDelay
        self.errorReporter = errorReporter
        self.eventService = eventService
        self.exportVaultService = exportVaultService
        self.fileSystem = fileSystem
        self.folderService = folderService
        self.passwordStore = passwordStore
        self.policyService = policyService
        self.stateService = stateService
        self.timeProvider = timeProvider
        self.vaultTimeoutService = vaultTimeoutService
    }

    // MARK: Configuration

    func changeFolder(_ folderURL: URL, userId: String) async throws {
        guard var settings = appSettingsStore.encryptedBackupSettings(userId: userId) else {
            throw EncryptedBackupError.notEnabled
        }
        settings.folderBookmark = try await bookmark(for: folderURL)
        settings.folderName = folderURL.lastPathComponent
        settings.lastFailure = nil
        // The new folder gets a backup on the next run even without changes.
        settings.lastContentFingerprint = nil
        appSettingsStore.setEncryptedBackupSettings(settings, userId: userId)
        statusSubject.send(userId)
    }

    func changePassword(_ password: String, userId: String) async throws {
        guard var settings = appSettingsStore.encryptedBackupSettings(userId: userId) else {
            throw EncryptedBackupError.notEnabled
        }
        try await passwordStore.setPassword(password, userId: userId)
        settings.lastContentFingerprint = nil
        if settings.lastFailure == .passwordMissing {
            settings.lastFailure = nil
        }
        appSettingsStore.setEncryptedBackupSettings(settings, userId: userId)
        statusSubject.send(userId)
    }

    func disable(userId: String) async throws {
        appSettingsStore.setEncryptedBackupSettings(nil, userId: userId)
        statusSubject.send(userId)
        try await passwordStore.deletePassword(userId: userId)
    }

    func enable(password: String, folderURL: URL, userId: String) async throws {
        let bookmark = try await bookmark(for: folderURL)
        try await passwordStore.setPassword(password, userId: userId)
        appSettingsStore.setEncryptedBackupSettings(
            EncryptedBackupSettings(folderBookmark: bookmark, folderName: folderURL.lastPathComponent),
            userId: userId,
        )
        statusSubject.send(userId)
    }

    // MARK: Status

    func status(userId: String) async -> EncryptedBackupStatus {
        guard let settings = appSettingsStore.encryptedBackupSettings(userId: userId) else {
            return EncryptedBackupStatus(isRunning: runningUserIds.contains(userId))
        }
        return EncryptedBackupStatus(
            isEnabled: true,
            folderName: settings.folderName,
            lastSuccessDate: settings.lastSuccessDate,
            lastFailure: settings.lastFailure,
            isRunning: runningUserIds.contains(userId),
        )
    }

    nonisolated func statusChangesPublisher() -> AnyPublisher<String, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    // MARK: Running

    func backUpNow(userId: String) async {
        await run(userId: userId, force: true)
    }

    func runAutomaticBackupIfDue() async {
        guard let userId = try? await stateService.getActiveAccountId() else { return }
        await run(userId: userId, force: false)
    }

    nonisolated func scheduleAutomaticBackup() {
        guard appContextHelper.appContext == .mainApp else { return }
        Task(priority: .utility) { await self.enqueueAutomaticRun() }
    }

    /// Starts the delayed automatic run unless one is pending.
    private func enqueueAutomaticRun() {
        guard scheduledRun == nil else { return }
        let delay = automaticRunDelay
        scheduledRun = Task.detached(priority: .utility) { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            await self?.runScheduled()
        }
    }

    /// The body of a scheduled run.
    private func runScheduled() async {
        scheduledRun = nil
        await runAutomaticBackupIfDue()
    }

    /// Whether an automatic run is due for a configuration.
    private func isAutomaticRunDue(_ settings: EncryptedBackupSettings) -> Bool {
        let now = timeProvider.presentTime
        if let lastSuccess = settings.lastSuccessDate, now.timeIntervalSince(lastSuccess) < Self.minimumInterval {
            return false
        }
        if settings.lastFailure != nil, let lastAttempt = settings.lastAttemptDate,
           now.timeIntervalSince(lastAttempt) < Self.retryInterval {
            return false
        }
        return true
    }

    /// Whether the account is the active one and its vault is unlocked.
    private func isActiveAndUnlocked(userId: String) async -> Bool {
        guard (try? await stateService.getActiveAccountId()) == userId else { return false }
        return await !vaultTimeoutService.isLocked(userId: userId)
    }

    /// Runs a backup of an account.
    ///
    /// - Parameters:
    ///   - userId: The account.
    ///   - force: `true` for "Back up now" (no schedule and change check).
    ///
    private func run(userId: String, force: Bool) async {
        guard appContextHelper.appContext == .mainApp,
              !runningUserIds.contains(userId),
              let settings = appSettingsStore.encryptedBackupSettings(userId: userId),
              force || isAutomaticRunDue(settings),
              await isActiveAndUnlocked(userId: userId)
        else { return }

        runningUserIds.insert(userId)
        statusSubject.send(userId)
        defer {
            runningUserIds.remove(userId)
            statusSubject.send(userId)
        }

        do {
            guard let fingerprint = try await writeBackup(userId: userId, settings: settings, force: force) else {
                return
            }
            updateSettings(userId: userId) { settings in
                settings.lastSuccessDate = self.timeProvider.presentTime
                settings.lastAttemptDate = self.timeProvider.presentTime
                settings.lastContentFingerprint = fingerprint
                settings.lastFailure = nil
            }
            await eventService.collect(eventType: .userClientExportedVault, cipherId: nil, organizationId: nil)
        } catch {
            let failure = error as? EncryptedBackupFailure ?? .exportFailed
            updateSettings(userId: userId) { settings in
                settings.lastAttemptDate = self.timeProvider.presentTime
                settings.lastFailure = failure
            }
        }
    }

    /// Exports and writes one backup.
    ///
    /// - Returns: The content fingerprint of the backup, `nil` when nothing was written (no changes, or the account
    ///   was locked, switched or turned the backup off meanwhile).
    ///
    private func writeBackup(userId: String, settings: EncryptedBackupSettings, force: Bool) async throws -> String? {
        if await policyService.policyAppliesToUser(.disablePersonalVaultExport, userId: userId) {
            throw EncryptedBackupFailure.disabledByPolicy
        }

        let password: String
        do {
            password = try await passwordStore.password(userId: userId)
        } catch {
            throw EncryptedBackupFailure.passwordMissing
        }

        let fingerprint: String
        let contents: String
        do {
            fingerprint = try await contentFingerprint()
            if !force, fingerprint == settings.lastContentFingerprint {
                return nil
            }
            contents = try await exportVaultService.exportVaultFileContents(
                format: .encryptedJson(password: password),
                includeArchivedItems: true,
            )
        } catch {
            errorReporter.log(error: error)
            throw EncryptedBackupFailure.exportFailed
        }
        guard Self.isPasswordProtectedExport(contents) else {
            throw EncryptedBackupFailure.exportFailed
        }

        // The account may have been switched, locked or the backup turned off during the export.
        guard await isActiveAndUnlocked(userId: userId),
              let current = appSettingsStore.encryptedBackupSettings(userId: userId),
              current.folderBookmark == settings.folderBookmark
        else { return nil }

        let fileName = Self.fileName(userId: userId, date: timeProvider.presentTime)
        let refreshedBookmark = try await onFileQueue { [fileSystem, errorReporter] in
            try Self.write(
                Data(contents.utf8),
                fileName: fileName,
                userId: userId,
                bookmark: settings.folderBookmark,
                fileSystem: fileSystem,
                errorReporter: errorReporter,
            )
        }
        if let refreshedBookmark {
            updateSettings(userId: userId) { $0.folderBookmark = refreshedBookmark }
        }
        return fingerprint
    }

    // MARK: Private

    /// Creates the bookmark of a folder from the document picker.
    private func bookmark(for folderURL: URL) async throws -> Data {
        try await onFileQueue { [fileSystem] in
            let didAccess = fileSystem.startAccessing(folderURL)
            defer { if didAccess { fileSystem.stopAccessing(folderURL) } }
            do {
                return try fileSystem.makeBookmark(for: folderURL)
            } catch {
                throw EncryptedBackupError.folderBookmarkFailed
            }
        }
    }

    /// The fingerprint of what the export would contain (same filter as the export: no trash, no organization items,
    /// no restricted item types; archived items included).
    private func contentFingerprint() async throws -> String {
        let ciphers = try await exportVaultService.fetchAllCiphersToExport(includeArchivedItems: true)
        let folders = try await folderService.fetchAllFolders()
        let content = EncryptedBackupContentFingerprint(
            items: ciphers.map { cipher in
                EncryptedBackupContentFingerprint.Item(
                    id: cipher.id ?? "",
                    revisionDate: cipher.revisionDate,
                    archivedDate: cipher.archivedDate,
                    folderId: cipher.folderId,
                    favorite: cipher.favorite,
                )
            }.sorted { $0.id < $1.id },
            folders: folders.map { folder in
                EncryptedBackupContentFingerprint.Folder(id: folder.id ?? "", revisionDate: folder.revisionDate)
            }.sorted { $0.id < $1.id },
        )
        return try DefaultDataFingerprintService().fingerprint(for: content)
    }

    /// Runs blocking file work on the file queue.
    private func onFileQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            fileQueue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    /// Changes the stored configuration of an account unless the backup was turned off meanwhile.
    private func updateSettings(userId: String, _ change: (inout EncryptedBackupSettings) -> Void) {
        guard var settings = appSettingsStore.encryptedBackupSettings(userId: userId) else { return }
        change(&settings)
        appSettingsStore.setEncryptedBackupSettings(settings, userId: userId)
    }
}

// MARK: - File handling

extension DefaultEncryptedBackupService {
    /// The short account tag in the file names (the first 8 hex digits of the SHA-256 of the user ID): several accounts
    /// can share a folder, and the file name does not show the e-mail address.
    static func accountTag(userId: String) -> String {
        SHA256.hash(data: Data(userId.utf8)).map { String(format: "%02x", $0) }.joined().prefix(8).description
    }

    /// The file name of a backup: `passy-backup-<tag>-<yyyyMMdd>-<HHmmss>.json` (UTC, sortable).
    static func fileName(userId: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(fileNamePrefix)\(accountTag(userId: userId))-\(formatter.string(from: date)).json"
    }

    /// Whether a file name is one of the account's own backups (exactly the pattern of `fileName(userId:date:)`).
    static func isOwnBackup(_ fileName: String, userId: String) -> Bool {
        let prefix = "\(fileNamePrefix)\(accountTag(userId: userId))-"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(".json") else { return false }
        let stamp = fileName.dropFirst(prefix.count).dropLast(".json".count)
        guard stamp.count == 15 else { return false }
        return stamp.enumerated().allSatisfy { index, character in
            index == 8 ? character == "-" : character.isASCII && character.isNumber
        }
    }

    /// Whether an export string is a password-protected encrypted export (never write anything else).
    static func isPasswordProtectedExport(_ contents: String) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: Data(contents.utf8)) as? [String: Any] else {
            return false
        }
        return object["encrypted"] as? Bool == true
            && object["passwordProtected"] as? Bool == true
            && (object["data"] as? String)?.isEmpty == false
            && (object["salt"] as? String)?.isEmpty == false
    }

    /// Writes a backup file into the bookmarked folder and removes the account's oldest backups beyond
    /// `keptBackups` (only after the new file was written; never the new file, never other files).
    ///
    /// - Returns: A fresh bookmark when the stored one was stale.
    ///
    static func write( // swiftlint:disable:this function_parameter_count
        _ data: Data,
        fileName: String,
        userId: String,
        bookmark: Data,
        fileSystem: EncryptedBackupFileSystem,
        errorReporter: ErrorReporter,
    ) throws -> Data? {
        let folderURL: URL
        let isStale: Bool
        do {
            (folderURL, isStale) = try fileSystem.resolveBookmark(bookmark)
        } catch {
            throw EncryptedBackupFailure.folderUnavailable
        }

        let didAccess = fileSystem.startAccessing(folderURL)
        defer { if didAccess { fileSystem.stopAccessing(folderURL) } }

        guard fileSystem.folderExists(at: folderURL) else {
            throw didAccess ? EncryptedBackupFailure.folderUnavailable : EncryptedBackupFailure.noAccess
        }

        var refreshedBookmark: Data?
        if isStale {
            refreshedBookmark = try? fileSystem.makeBookmark(for: folderURL)
        }

        do {
            try fileSystem.write(data, to: folderURL.appendingPathComponent(fileName, isDirectory: false))
        } catch {
            throw failure(for: error)
        }

        // Rotation: best effort, a failure here does not undo the successful backup.
        do {
            let ownBackups = try fileSystem.fileNames(inFolder: folderURL)
                .filter { $0 != fileName && isOwnBackup($0, userId: userId) }
                .sorted(by: >)
            for oldName in ownBackups.dropFirst(keptBackups - 1) {
                try fileSystem.removeFile(at: folderURL.appendingPathComponent(oldName, isDirectory: false))
            }
        } catch {
            errorReporter.log(error: error)
        }
        return refreshedBookmark
    }

    /// The failure for a file write error.
    static func failure(for error: Error) -> EncryptedBackupFailure {
        let nsError = error as NSError
        let posixCode: Int? = if nsError.domain == NSPOSIXErrorDomain {
            nsError.code
        } else if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
                  underlying.domain == NSPOSIXErrorDomain {
            underlying.code
        } else {
            nil
        }
        let cocoaCode: Int? = nsError.domain == NSCocoaErrorDomain ? nsError.code : nil
        let isCocoa = { (codes: [Int]) in cocoaCode.map(codes.contains) ?? false }
        let isPosix = { (codes: [Int32]) in posixCode.map { codes.map(Int.init).contains($0) } ?? false }
        if isCocoa([NSFileWriteOutOfSpaceError]) || isPosix([ENOSPC, EDQUOT]) {
            return .noSpace
        }
        if isCocoa([NSFileWriteNoPermissionError, NSFileReadNoPermissionError]) || isPosix([EACCES, EPERM]) {
            return .noAccess
        }
        if isCocoa([NSFileNoSuchFileError, NSFileWriteInvalidFileNameError]) || isPosix([ENOENT]) {
            return .folderUnavailable
        }
        return .writeFailed(nsError.localizedDescription)
    }
}
