import BitwardenKit
import BitwardenKitMocks
import BitwardenSdk
import Combine
import TestHelpers
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// swiftlint:disable file_length type_body_length

class EncryptedBackupServiceTests: BitwardenTestCase {
    // MARK: Properties

    var appContextHelper: MockAppContextHelper!
    var appSettingsStore: MockAppSettingsStore!
    var errorReporter: MockErrorReporter!
    var eventService: MockEventService!
    var exportVaultService: MockExportVaultService!
    var fileSystem: FakeEncryptedBackupFileSystem!
    var folderService: MockFolderService!
    var passwordStore: FakeEncryptedBackupPasswordStore!
    var policyService: MockPolicyService!
    var stateService: MockStateService!
    var subject: DefaultEncryptedBackupService!
    var timeProvider: MockTimeProvider!
    var vaultTimeoutService: MockVaultTimeoutService!

    /// The backup folder of the tests.
    let folder = "/Backups"

    /// The current time of the tests.
    let now = Date(timeIntervalSince1970: 1_795_780_800) // 2026-11-27 12:00:00 UTC

    /// A password-protected export as the SDK returns it.
    let protectedExport = """
    {"encrypted":true,"passwordProtected":true,"salt":"c2FsdA==","kdfType":0,"kdfIterations":600000,\
    "encKeyValidation_DO_NOT_EDIT":"2.a|b|c","data":"2.d|e|f"}
    """

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        appContextHelper = MockAppContextHelper()
        appSettingsStore = MockAppSettingsStore()
        errorReporter = MockErrorReporter()
        eventService = MockEventService()
        exportVaultService = MockExportVaultService()
        fileSystem = FakeEncryptedBackupFileSystem()
        folderService = MockFolderService()
        passwordStore = FakeEncryptedBackupPasswordStore()
        policyService = MockPolicyService()
        stateService = MockStateService()
        timeProvider = MockTimeProvider(.mockTime(now))
        vaultTimeoutService = MockVaultTimeoutService()

        stateService.activeAccount = .fixture(profile: .fixture(userId: "1"))
        exportVaultService.exportVaultContentResult = .success(protectedExport)
        exportVaultService.fetchAllCiphersToExportResult = .success([.fixture(id: "c1")])
        fileSystem.folders[folder] = [:]

        makeSubject()
    }

    override func tearDown() {
        super.tearDown()

        appContextHelper = nil
        appSettingsStore = nil
        errorReporter = nil
        eventService = nil
        exportVaultService = nil
        fileSystem = nil
        folderService = nil
        passwordStore = nil
        policyService = nil
        stateService = nil
        subject = nil
        timeProvider = nil
        vaultTimeoutService = nil
    }

    // MARK: Helpers

    /// Creates the subject.
    @MainActor
    func makeSubject(delay: TimeInterval = 0) {
        subject = DefaultEncryptedBackupService(
            appContextHelper: appContextHelper,
            appSettingsStore: appSettingsStore,
            automaticRunDelay: delay,
            errorReporter: errorReporter,
            eventService: eventService,
            exportVaultService: exportVaultService,
            fileSystem: fileSystem,
            folderService: folderService,
            passwordStore: passwordStore,
            policyService: policyService,
            stateService: stateService,
            timeProvider: timeProvider,
            vaultTimeoutService: vaultTimeoutService,
        )
    }

    /// Turns the backup on for user 1 (as the setup sheet does).
    @MainActor
    func enable() async throws {
        try await subject.enable(
            password: "correct horse battery",
            folderURL: URL(fileURLWithPath: folder, isDirectory: true),
            userId: "1",
        )
    }

    /// The names of the files in the backup folder, sorted.
    var fileNames: [String] {
        fileSystem.folders[folder, default: [:]].keys.sorted()
    }

    /// The name of an own backup file of user 1 at a time offset from `now`.
    func ownFileName(offset: TimeInterval = 0, userId: String = "1") -> String {
        DefaultEncryptedBackupService.fileName(userId: userId, date: now.addingTimeInterval(offset))
    }

    /// The stored settings of user 1.
    var settings: EncryptedBackupSettings? {
        appSettingsStore.encryptedBackupSettingsByUserId["1"]
    }

    // MARK: Tests - Configuration

    /// `enable` keeps the password in the keychain store only and the folder as a bookmark in the settings.
    @MainActor
    func test_enable_storesPasswordInKeychainOnly() async throws {
        try await enable()

        XCTAssertEqual(passwordStore.passwords, ["1": "correct horse battery"])
        XCTAssertEqual(settings?.folderBookmark, FakeEncryptedBackupFileSystem.bookmark(folder))
        XCTAssertEqual(settings?.folderName, "Backups")
        XCTAssertNil(settings?.lastSuccessDate)
        let encoded = try String(decoding: JSONEncoder().encode(XCTUnwrap(settings)), as: UTF8.self)
        XCTAssertFalse(encoded.contains("correct horse battery"))
        XCTAssertEqual(fileSystem.openAccesses, 0)
        let status = await subject.status(userId: "1")
        XCTAssertEqual(status, EncryptedBackupStatus(isEnabled: true, folderName: "Backups"))
    }

    /// `enable` fails without storing anything when the folder cannot be bookmarked.
    @MainActor
    func test_enable_bookmarkFails() async {
        fileSystem.makeBookmarkError = BitwardenTestError.example

        await assertAsyncThrows(error: EncryptedBackupError.folderBookmarkFailed) {
            try await enable()
        }
        XCTAssertTrue(passwordStore.passwords.isEmpty)
        XCTAssertNil(settings)
    }

    /// `disable` removes the password, the bookmark and the status; the backup files stay.
    @MainActor
    func test_disable_removesConfigurationKeepsFiles() async throws {
        try await enable()
        await subject.backUpNow(userId: "1")
        XCTAssertEqual(fileNames.count, 1)

        try await subject.disable(userId: "1")

        XCTAssertTrue(passwordStore.passwords.isEmpty)
        XCTAssertNil(settings)
        XCTAssertEqual(fileNames.count, 1)
        let status = await subject.status(userId: "1")
        XCTAssertEqual(status, .off)
    }

    /// After `disable`, neither "Back up now" nor an automatic run writes anything.
    @MainActor
    func test_disable_noMoreRuns() async throws {
        try await enable()
        try await subject.disable(userId: "1")

        await subject.backUpNow(userId: "1")
        await subject.runAutomaticBackupIfDue()

        XCTAssertTrue(fileNames.isEmpty)
        XCTAssertNil(exportVaultService.exportVaultContentsFormat)
    }

    /// `changePassword` stores the new password and forces the next automatic run (no unchanged skip).
    @MainActor
    func test_changePassword() async throws {
        try await enable()
        await subject.backUpNow(userId: "1")

        try await subject.changePassword("a brand new password", userId: "1")

        XCTAssertEqual(passwordStore.passwords["1"], "a brand new password")
        XCTAssertNil(settings?.lastContentFingerprint)
    }

    /// `changePassword` and `changeFolder` throw while the backup is off.
    @MainActor
    func test_change_notEnabled() async {
        await assertAsyncThrows(error: EncryptedBackupError.notEnabled) {
            try await subject.changePassword("a brand new password", userId: "1")
        }
        await assertAsyncThrows(error: EncryptedBackupError.notEnabled) {
            try await subject.changeFolder(URL(fileURLWithPath: "/Other"), userId: "1")
        }
        XCTAssertTrue(passwordStore.passwords.isEmpty)
    }

    /// `changeFolder` stores the new bookmark and clears an old folder error.
    @MainActor
    func test_changeFolder() async throws {
        try await enable()
        fileSystem.folders[folder] = nil
        await subject.backUpNow(userId: "1")
        XCTAssertEqual(settings?.lastFailure, .folderUnavailable)

        fileSystem.folders["/Other"] = [:]
        try await subject.changeFolder(URL(fileURLWithPath: "/Other", isDirectory: true), userId: "1")
        await subject.backUpNow(userId: "1")

        XCTAssertEqual(settings?.folderName, "Other")
        XCTAssertNil(settings?.lastFailure)
        XCTAssertEqual(fileSystem.folders["/Other"]?.keys.sorted(), [ownFileName()])
    }

    // MARK: Tests - Back up now

    /// "Back up now" writes a password-protected export (archived items included) into the folder under the own
    /// file name pattern, records the success and collects the export event.
    @MainActor
    func test_backUpNow_writesEncryptedExport() async throws {
        try await enable()

        await subject.backUpNow(userId: "1")

        XCTAssertEqual(exportVaultService.exportVaultContentsFormat, .encryptedJson(password: "correct horse battery"))
        XCTAssertEqual(exportVaultService.exportVaultContentsIncludeArchived, true)
        XCTAssertEqual(fileNames, [ownFileName()])
        XCTAssertEqual(fileSystem.folders[folder]?[ownFileName()], Data(protectedExport.utf8))
        XCTAssertTrue(ownFileName().hasPrefix("passy-backup-"))
        XCTAssertEqual(settings?.lastSuccessDate, now)
        XCTAssertNotNil(settings?.lastContentFingerprint)
        XCTAssertNil(settings?.lastFailure)
        XCTAssertEqual(eventService.collectEventType, .userClientExportedVault)
        XCTAssertEqual(fileSystem.openAccesses, 0)
    }

    /// A result that is not a password-protected export (plain JSON, account-key encrypted) is never written.
    @MainActor
    func test_backUpNow_rejectsUnprotectedExport() async throws {
        try await enable()
        for contents in [
            #"{"encrypted":false,"items":[]}"#,
            #"{"encrypted":true,"encKeyValidation_DO_NOT_EDIT":"2.a|b|c","data":"2.d|e|f"}"#,
            "not json",
        ] {
            exportVaultService.exportVaultContentResult = .success(contents)

            await subject.backUpNow(userId: "1")

            XCTAssertTrue(fileNames.isEmpty, contents)
            XCTAssertEqual(settings?.lastFailure, .exportFailed)
        }
        XCTAssertNil(settings?.lastSuccessDate)
    }

    /// A failing export is reported and writes nothing.
    @MainActor
    func test_backUpNow_exportFails() async throws {
        try await enable()
        exportVaultService.exportVaultContentResult = .failure(BitwardenTestError.example)

        await subject.backUpNow(userId: "1")

        XCTAssertTrue(fileNames.isEmpty)
        XCTAssertEqual(settings?.lastFailure, .exportFailed)
        XCTAssertEqual(settings?.lastAttemptDate, now)
        XCTAssertEqual(errorReporter.errors.last as? BitwardenTestError, .example)
    }

    /// An organization policy that disables the export stops the backup before any export.
    @MainActor
    func test_backUpNow_policy() async throws {
        try await enable()
        policyService.policyAppliesToUserResult[.disablePersonalVaultExport] = true

        await subject.backUpNow(userId: "1")

        XCTAssertNil(exportVaultService.exportVaultContentsFormat)
        XCTAssertTrue(fileNames.isEmpty)
        XCTAssertEqual(settings?.lastFailure, .disabledByPolicy)
    }

    /// A missing keychain password (restore onto another device) is a visible status, not a silent skip.
    @MainActor
    func test_backUpNow_passwordMissing() async throws {
        try await enable()
        passwordStore.passwords = [:]

        await subject.backUpNow(userId: "1")

        XCTAssertNil(exportVaultService.exportVaultContentsFormat)
        XCTAssertEqual(settings?.lastFailure, .passwordMissing)
        let status = await subject.status(userId: "1")
        XCTAssertEqual(status.lastFailure, .passwordMissing)
    }

    /// A locked vault, another active account or an extension context run nothing (silently).
    @MainActor
    func test_backUpNow_lockedOtherAccountExtension() async throws {
        try await enable()

        vaultTimeoutService.isClientLocked["1"] = true
        await subject.backUpNow(userId: "1")
        vaultTimeoutService.isClientLocked["1"] = false

        stateService.activeAccount = .fixture(profile: .fixture(userId: "2"))
        await subject.backUpNow(userId: "1")
        stateService.activeAccount = .fixture(profile: .fixture(userId: "1"))

        appContextHelper.appContext = .appExtension
        await subject.backUpNow(userId: "1")

        XCTAssertNil(exportVaultService.exportVaultContentsFormat)
        XCTAssertTrue(fileNames.isEmpty)
        XCTAssertNil(settings?.lastFailure)
        XCTAssertNil(settings?.lastAttemptDate)
    }

    /// When the account is switched during the export, the export is discarded.
    @MainActor
    func test_backUpNow_accountSwitchedDuringExport() async throws {
        let switchingExport = SwitchingExportVaultService()
        switchingExport.exportVaultContentResult = .success(protectedExport)
        switchingExport.onExport = { [weak self] in
            self?.stateService.activeAccount = .fixture(profile: .fixture(userId: "2"))
        }
        exportVaultService = switchingExport
        makeSubject()
        try await enable()

        await subject.backUpNow(userId: "1")

        XCTAssertTrue(fileNames.isEmpty)
        XCTAssertNil(settings?.lastSuccessDate)
        XCTAssertNil(settings?.lastFailure)
    }

    // MARK: Tests - File errors

    /// A bookmark that cannot be resolved is "folder unavailable".
    @MainActor
    func test_backUpNow_bookmarkUnresolvable() async throws {
        try await enable()
        fileSystem.resolveError = BitwardenTestError.example

        await subject.backUpNow(userId: "1")

        XCTAssertEqual(settings?.lastFailure, .folderUnavailable)
    }

    /// A deleted folder is "folder unavailable"; without access it is "no access".
    @MainActor
    func test_backUpNow_folderMissingOrNoAccess() async throws {
        try await enable()
        fileSystem.folders[folder] = nil

        await subject.backUpNow(userId: "1")
        XCTAssertEqual(settings?.lastFailure, .folderUnavailable)

        fileSystem.grantsAccess = false
        await subject.backUpNow(userId: "1")
        XCTAssertEqual(settings?.lastFailure, .noAccess)
        XCTAssertEqual(fileSystem.openAccesses, 0)
    }

    /// A stale bookmark is refreshed and the backup is written.
    @MainActor
    func test_backUpNow_staleBookmarkRefreshed() async throws {
        try await enable()
        let original = try XCTUnwrap(settings?.folderBookmark)
        fileSystem.staleBookmarks = [original]
        fileSystem.makeBookmarkError = nil

        await subject.backUpNow(userId: "1")

        XCTAssertEqual(fileNames, [ownFileName()])
        XCTAssertEqual(settings?.folderBookmark, FakeEncryptedBackupFileSystem.bookmark(folder))
        XCTAssertNil(settings?.lastFailure)
    }

    /// Write errors map to "no space", "no access" and a provider message; a failed write never deletes old backups
    /// and keeps the last success.
    @MainActor
    func test_backUpNow_writeErrors_keepOldBackups() async throws {
        try await enable()
        let older = (1 ... 5).map { ownFileName(offset: -Double($0) * 86400 * 2) }
        for name in older {
            fileSystem.folders[folder]?[name] = Data("old".utf8)
        }
        appSettingsStore.encryptedBackupSettingsByUserId["1"]?.lastSuccessDate = now.addingTimeInterval(-172_800)

        let cases: [(Error, EncryptedBackupFailure)] = [
            (NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError), .noSpace),
            (NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC)), .noSpace),
            (NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError), .noAccess),
            (NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError), .folderUnavailable),
            (
                NSError(domain: "NSFileProviderErrorDomain", code: -1004, userInfo: [
                    NSLocalizedDescriptionKey: "The server is not reachable",
                ]),
                .writeFailed("The server is not reachable"),
            ),
        ]
        for (error, failure) in cases {
            fileSystem.writeError = error

            await subject.backUpNow(userId: "1")

            XCTAssertEqual(settings?.lastFailure, failure)
            XCTAssertEqual(fileNames, older.sorted())
            XCTAssertTrue(fileSystem.removedFiles.isEmpty)
            XCTAssertEqual(settings?.lastSuccessDate, now.addingTimeInterval(-172_800))
        }
    }

    /// A failed rotation does not turn a written backup into a failure.
    @MainActor
    func test_backUpNow_rotationErrorKeepsSuccess() async throws {
        try await enable()
        fileSystem.listError = BitwardenTestError.example

        await subject.backUpNow(userId: "1")

        XCTAssertEqual(fileNames, [ownFileName()])
        XCTAssertNil(settings?.lastFailure)
        XCTAssertEqual(errorReporter.errors.last as? BitwardenTestError, .example)
    }

    // MARK: Tests - Rotation

    /// Rotation keeps the newest 5 own backups and never touches other files (other accounts, other apps, similar
    /// names).
    @MainActor
    func test_rotation_keepsFiveOwnAndForeignFiles() async throws {
        try await enable()
        let ownOld = (1 ... 6).map { ownFileName(offset: -Double($0) * 86400) }
        let otherAccount = ownFileName(offset: -10 * 86400, userId: "2")
        let tag = DefaultEncryptedBackupService.accountTag(userId: "1")
        let foreign = [
            otherAccount,
            "bitwarden_encrypted_export_20261101000000.json",
            "passy-backup-\(tag)-20200101-000000.json.bak",
            "passy-backup-\(tag)-20200101-000000 copy.json",
            "passy-backup-\(tag)-2020010-1000000.json",
            "passy-backup-\(tag)-notes.json",
            "Passy-Backup-\(tag)-20200101-000000.json",
            "notes.txt",
        ]
        for name in ownOld + foreign {
            fileSystem.folders[folder]?[name] = Data("x".utf8)
        }

        await subject.backUpNow(userId: "1")

        let expectedOwn = [ownFileName()] + ownOld.prefix(4)
        XCTAssertEqual(fileNames, (expectedOwn + foreign).sorted())
        XCTAssertEqual(fileSystem.removedFiles.sorted(), ownOld.suffix(2).sorted())
    }

    /// The file name pattern matches only the account's own backups.
    @MainActor
    func test_isOwnBackup() {
        let tag = DefaultEncryptedBackupService.accountTag(userId: "1")
        XCTAssertEqual(tag.count, 8)
        XCTAssertTrue(DefaultEncryptedBackupService.isOwnBackup("passy-backup-\(tag)-20261127-120000.json", userId: "1"))
        XCTAssertFalse(DefaultEncryptedBackupService.isOwnBackup("passy-backup-\(tag)-20261127-120000.json", userId: "2"))
        XCTAssertFalse(DefaultEncryptedBackupService.isOwnBackup("passy-backup-\(tag)-20261127080000.json", userId: "1"))
        XCTAssertFalse(DefaultEncryptedBackupService.isOwnBackup("passy-backup-\(tag)-2026112a-080000.json", userId: "1"))
        XCTAssertFalse(DefaultEncryptedBackupService.isOwnBackup("x-passy-backup-\(tag)-20261127-120000.json", userId: "1"))
        XCTAssertEqual(ownFileName(), "passy-backup-\(tag)-20261127-120000.json")
    }

    /// iCloud placeholders report their real name.
    @MainActor
    func test_realName_iCloudPlaceholder() {
        XCTAssertEqual(DefaultEncryptedBackupFileSystem.realName(of: ".a.json.icloud"), "a.json")
        XCTAssertEqual(DefaultEncryptedBackupFileSystem.realName(of: "a.json"), "a.json")
        XCTAssertEqual(DefaultEncryptedBackupFileSystem.realName(of: ".icloud"), ".icloud")
    }

    // MARK: Tests - Scheduling

    /// The first automatic run of a new configuration writes a backup.
    @MainActor
    func test_automatic_firstRun() async throws {
        try await enable()

        await subject.runAutomaticBackupIfDue()

        XCTAssertEqual(fileNames, [ownFileName()])
    }

    /// Less than 24 h after the last backup nothing runs, even with changes.
    @MainActor
    func test_automatic_notDueWithin24Hours() async throws {
        try await enable()
        await subject.backUpNow(userId: "1")
        exportVaultService.exportVaultContentsFormat = nil
        exportVaultService.fetchAllCiphersToExportResult = .success([.fixture(id: "c1"), .fixture(id: "c2")])

        timeProvider.timeConfig = .mockTime(now.addingTimeInterval(23 * 3600))
        await subject.runAutomaticBackupIfDue()

        XCTAssertNil(exportVaultService.exportVaultContentsFormat)
        XCTAssertEqual(fileNames.count, 1)
    }

    /// 24 h later without changes nothing is written.
    @MainActor
    func test_automatic_unchangedContent() async throws {
        try await enable()
        await subject.backUpNow(userId: "1")
        exportVaultService.exportVaultContentsFormat = nil

        timeProvider.timeConfig = .mockTime(now.addingTimeInterval(25 * 3600))
        await subject.runAutomaticBackupIfDue()

        XCTAssertNil(exportVaultService.exportVaultContentsFormat)
        XCTAssertEqual(fileNames.count, 1)
        XCTAssertEqual(settings?.lastSuccessDate, now)
    }

    /// 24 h later with a changed item, a changed folder, or a newly archived item a new backup is written.
    @MainActor
    func test_automatic_changedContent() async throws {
        try await enable()
        await subject.backUpNow(userId: "1")
        let changes: [() -> Void] = [
            { self.exportVaultService.fetchAllCiphersToExportResult = .success([
                .fixture(id: "c1", revisionDate: Date(timeIntervalSince1970: 1)),
            ]) },
            { self.folderService.fetchAllFoldersResult = .success([.fixture(id: "f1", revisionDate: self.now)]) },
            { self.exportVaultService.fetchAllCiphersToExportResult = .success([
                .fixture(archivedDate: self.now, id: "c1", revisionDate: Date(timeIntervalSince1970: 1)),
            ]) },
        ]
        for (index, change) in changes.enumerated() {
            change()
            timeProvider.timeConfig = .mockTime(now.addingTimeInterval(Double(index + 1) * 25 * 3600))

            await subject.runAutomaticBackupIfDue()

            XCTAssertEqual(fileNames.count, index + 2)
            XCTAssertEqual(settings?.lastSuccessDate, timeProvider.presentTime)
        }
    }

    /// "Back up now" ignores the schedule and the change check.
    @MainActor
    func test_backUpNow_ignoresSchedule() async throws {
        try await enable()
        await subject.backUpNow(userId: "1")

        timeProvider.timeConfig = .mockTime(now.addingTimeInterval(60))
        await subject.backUpNow(userId: "1")

        XCTAssertEqual(fileNames.count, 2)
    }

    /// After a failure, automatic runs wait an hour before the next attempt.
    @MainActor
    func test_automatic_retryAfterFailure() async throws {
        try await enable()
        fileSystem.writeError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        await subject.runAutomaticBackupIfDue()
        XCTAssertEqual(settings?.lastFailure, .noSpace)
        fileSystem.writeError = nil

        timeProvider.timeConfig = .mockTime(now.addingTimeInterval(30 * 60))
        await subject.runAutomaticBackupIfDue()
        XCTAssertTrue(fileNames.isEmpty)

        timeProvider.timeConfig = .mockTime(now.addingTimeInterval(61 * 60))
        await subject.runAutomaticBackupIfDue()
        XCTAssertEqual(fileNames.count, 1)
        XCTAssertNil(settings?.lastFailure)
    }

    /// Automatic runs need the active account unlocked.
    @MainActor
    func test_automatic_lockedOrLoggedOut() async throws {
        try await enable()

        vaultTimeoutService.isClientLocked["1"] = true
        await subject.runAutomaticBackupIfDue()
        stateService.activeAccount = nil
        await subject.runAutomaticBackupIfDue()

        XCTAssertTrue(fileNames.isEmpty)
        XCTAssertNil(settings?.lastAttemptDate)
    }

    /// `scheduleAutomaticBackup` runs the automatic backup in the background after the delay, coalesced.
    @MainActor
    func test_scheduleAutomaticBackup() async throws {
        try await enable()

        subject.scheduleAutomaticBackup()
        subject.scheduleAutomaticBackup()
        try await waitForAsync { self.fileSystem.writtenURLs.count == 1 }

        // A later schedule after the run starts a new (not due) run.
        subject.scheduleAutomaticBackup()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(fileSystem.writtenURLs.count, 1)
    }

    /// `scheduleAutomaticBackup` does nothing in an extension.
    @MainActor
    func test_scheduleAutomaticBackup_extension() async throws {
        try await enable()
        appContextHelper.appContext = .appExtension

        subject.scheduleAutomaticBackup()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(fileSystem.writtenURLs.isEmpty)
    }

    /// The status publisher reports the running state and the result.
    @MainActor
    func test_statusChangesPublisher() async throws {
        try await enable()
        var changes = [String]()
        let cancellable = subject.statusChangesPublisher().sink { changes.append($0) }
        defer { cancellable.cancel() }

        await subject.backUpNow(userId: "1")

        XCTAssertEqual(changes, ["1", "1"])
        let status = await subject.status(userId: "1")
        XCTAssertFalse(status.isRunning)
        XCTAssertEqual(status.lastSuccessDate, now)
    }
}

// MARK: - SwitchingExportVaultService

/// An export service that runs a closure during the export (to switch the account mid-run).
private class SwitchingExportVaultService: MockExportVaultService {
    var onExport: (() -> Void)?

    override func exportVaultFileContents(format: ExportFileType, includeArchivedItems: Bool) async throws -> String {
        onExport?()
        return try await super.exportVaultFileContents(format: format, includeArchivedItems: includeArchivedItems)
    }
}
