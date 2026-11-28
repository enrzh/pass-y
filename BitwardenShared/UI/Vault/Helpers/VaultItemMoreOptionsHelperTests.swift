import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import BitwardenSdk
import TestHelpers
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// swiftlint:disable file_length

class VaultItemMoreOptionsHelperTests: BitwardenTestCase { // swiftlint:disable:this type_body_length
    // MARK: Properties

    var authRepository: MockAuthRepository!
    var configService: MockConfigService!
    var coordinator: MockCoordinator<VaultRoute, AuthAction>!
    var environmentService: MockEnvironmentService!
    var errorReporter: MockErrorReporter!
    var masterPasswordRepromptHelper: MockMasterPasswordRepromptHelper!
    var pasteboardService: MockPasteboardService!
    var settingsRepository: MockSettingsRepository!
    var stateService: MockStateService!
    var subject: VaultItemMoreOptionsHelper!
    var vaultRepository: MockVaultRepository!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        authRepository = MockAuthRepository()
        configService = MockConfigService()
        coordinator = MockCoordinator()
        environmentService = MockEnvironmentService()
        errorReporter = MockErrorReporter()
        masterPasswordRepromptHelper = MockMasterPasswordRepromptHelper()
        pasteboardService = MockPasteboardService()
        settingsRepository = MockSettingsRepository()
        stateService = MockStateService()
        vaultRepository = MockVaultRepository()

        subject = DefaultVaultItemMoreOptionsHelper(
            coordinator: coordinator.asAnyCoordinator(),
            masterPasswordRepromptHelper: masterPasswordRepromptHelper,
            services: ServiceContainer.withMocks(
                authRepository: authRepository,
                configService: configService,
                environmentService: environmentService,
                errorReporter: errorReporter,
                pasteboardService: pasteboardService,
                settingsRepository: settingsRepository,
                stateService: stateService,
                vaultRepository: vaultRepository,
            ),
        )
    }

    override func tearDown() {
        super.tearDown()

        authRepository = nil
        configService = nil
        coordinator = nil
        environmentService = nil
        errorReporter = nil
        masterPasswordRepromptHelper = nil
        pasteboardService = nil
        settingsRepository = nil
        stateService = nil
        subject = nil
        vaultRepository = nil
    }

    // MARK: moveToFolder Tests

    /// `moveToFolder(_:folderId:handleDisplayToast:)` saves the cipher in the folder and shows the "Moved to" toast.
    @MainActor
    func test_moveToFolder() async throws {
        vaultRepository.fetchCipherResult = .success(.loginFixture(folderId: nil, id: "1"))
        vaultRepository.fetchFolderResult = .success(.fixture(id: "f1", name: "Work"))
        var toast: Toast?

        await subject.moveToFolder(.fixture(cipherListView: .fixture(id: "1")), folderId: "f1") { toast = $0 }

        XCTAssertEqual(vaultRepository.updateCipherCiphers.last?.folderId, "f1")
        XCTAssertEqual(toast, Toast(title: Localizations.movedToX("Work")))
        XCTAssertTrue(coordinator.errorAlertsShown.isEmpty)
    }

    /// `moveToFolder(_:folderId:handleDisplayToast:)` with `nil` removes the item from its folder.
    @MainActor
    func test_moveToFolder_noFolder() async throws {
        vaultRepository.fetchCipherResult = .success(.loginFixture(folderId: "f1", id: "1"))
        var toast: Toast?

        await subject.moveToFolder(.fixture(cipherListView: .fixture(id: "1")), folderId: nil) { toast = $0 }

        XCTAssertEqual(vaultRepository.updateCipherCiphers.count, 1)
        XCTAssertNil(vaultRepository.updateCipherCiphers.last?.folderId)
        XCTAssertEqual(toast, Toast(title: Localizations.movedToX(Localizations.folderNone)))
    }

    /// `moveToFolder(_:folderId:handleDisplayToast:)` does nothing for the item's current folder.
    @MainActor
    func test_moveToFolder_currentFolder() async throws {
        vaultRepository.fetchCipherResult = .success(.loginFixture(folderId: "f1", id: "1"))
        var toast: Toast?

        await subject.moveToFolder(.fixture(cipherListView: .fixture(id: "1")), folderId: "f1") { toast = $0 }

        XCTAssertTrue(vaultRepository.updateCipherCiphers.isEmpty)
        XCTAssertNil(toast)
    }

    /// `moveToFolder(_:folderId:handleDisplayToast:)` moves only after the master password re-prompt.
    @MainActor
    func test_moveToFolder_passwordReprompt() async throws {
        masterPasswordRepromptHelper.repromptForMasterPasswordAutoComplete = false
        let cipher = CipherView.loginFixture(folderId: nil, id: "1", reprompt: .password)
        vaultRepository.fetchCipherResult = .success(cipher)

        await subject.moveToFolder(.fixture(cipherListView: .fixture(id: "1")), folderId: "f1") { _ in }

        XCTAssertEqual(masterPasswordRepromptHelper.repromptForMasterPasswordCipherView, cipher)
        XCTAssertTrue(vaultRepository.updateCipherCiphers.isEmpty)
        await masterPasswordRepromptHelper.repromptForMasterPasswordCompletion?()
        XCTAssertEqual(vaultRepository.updateCipherCiphers.last?.folderId, "f1")
    }

    /// `moveToFolder(_:folderId:handleDisplayToast:)` moves the cipher of a code row.
    @MainActor
    func test_moveToFolder_codeRow() async throws {
        vaultRepository.fetchCipherResult = .success(.loginFixture(folderId: nil, id: "123"))
        let item = VaultListItem.fixtureTOTP(totp: .fixture(id: "123", timeProvider: MockTimeProvider(.currentTime)))

        await subject.moveToFolder(item, folderId: "f1") { _ in }

        XCTAssertEqual(vaultRepository.updateCipherCiphers.last?.folderId, "f1")
    }

    /// `moveToFolder(_:folderId:handleDisplayToast:)` shows the error alert when saving fails (no toast).
    @MainActor
    func test_moveToFolder_error() async throws {
        vaultRepository.fetchCipherResult = .success(.loginFixture(folderId: nil, id: "1"))
        vaultRepository.updateCipherResult = .failure(BitwardenTestError.example)
        var toast: Toast?

        await subject.moveToFolder(.fixture(cipherListView: .fixture(id: "1")), folderId: "f1") { toast = $0 }

        XCTAssertNil(toast)
        XCTAssertEqual(coordinator.errorAlertsShown as? [BitwardenTestError], [.example])
        XCTAssertEqual(errorReporter.errors as? [BitwardenTestError], [.example])
    }

    /// `moveToNewFolder(_:handleDisplayToast:onFolderCreated:)` asks for a name, creates the folder and moves the item
    /// into it.
    @MainActor
    func test_moveToNewFolder() async throws {
        vaultRepository.fetchCipherResult = .success(.loginFixture(folderId: nil, id: "1"))
        settingsRepository.addFolderResult = .success(.fixture(id: "new", name: "Travel"))
        var toast: Toast?
        var created = false

        await subject.moveToNewFolder(
            .fixture(cipherListView: .fixture(id: "1")),
            handleDisplayToast: { toast = $0 },
            onFolderCreated: { created = true },
        )
        let alert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(alert.title, Localizations.addFolder)
        try alert.setText("Travel", forTextFieldWithId: "name")
        try await alert.tapAction(title: Localizations.save)

        XCTAssertEqual(settingsRepository.addedFolderName, "Travel")
        XCTAssertTrue(created)
        XCTAssertEqual(vaultRepository.updateCipherCiphers.last?.folderId, "new")
        XCTAssertEqual(toast, Toast(title: Localizations.movedToX("Travel")))
    }

    // MARK: performMoreOptionsAction Tests

    /// `performMoreOptionsAction(_:for:...)` with `.view` navigates to the `.viewItem` route.
    @MainActor
    func test_performMoreOptionsAction_view() async throws {
        stateService.activeAccount = .fixture()
        let cipherView = CipherView.fixture(id: "id")
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture(id: "id")))

        await subject.performMoreOptionsAction(
            .view,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(coordinator.routes.last, .viewItem(id: item.id, masterPasswordRepromptCheckCompleted: true))
    }

    /// `performMoreOptionsAction(_:for:...)` with `.edit` navigates to the `.editItem` route and
    /// passes the delegate it was given as the navigation context.
    @MainActor
    func test_performMoreOptionsAction_edit() async throws {
        stateService.activeAccount = .fixture()
        let cipherView = CipherView.fixture()
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        let delegate = MockCipherItemOperationDelegate()
        await subject.performMoreOptionsAction(
            .edit,
            for: item,
            delegate: delegate,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(coordinator.routes.last, .editItem(cipherView))
        XCTAssertIdentical(coordinator.contexts.last as AnyObject, delegate)
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyUsername` copies the cipher's username.
    @MainActor
    func test_performMoreOptionsAction_copyUsername() async throws {
        stateService.activeAccount = .fixture()
        let cipherView = CipherView.loginFixture(login: .fixture(username: "username"))
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .copyUsername,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(pasteboardService.copyReceivedString, "username")
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyPassword` presents the master password
    /// re-prompt alert and copies the password once confirmed.
    @MainActor
    func test_performMoreOptionsAction_copyPassword_passwordReprompt() async throws {
        stateService.activeAccount = .fixture()
        masterPasswordRepromptHelper.repromptForMasterPasswordAutoComplete = false
        let cipherView = CipherView.loginFixture(login: .fixture(password: "secretPassword"), reprompt: .password)
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .copyPassword,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(masterPasswordRepromptHelper.repromptForMasterPasswordCipherView, cipherView)
        XCTAssertNil(pasteboardService.copyReceivedString)

        await masterPasswordRepromptHelper.repromptForMasterPasswordCompletion?()
        XCTAssertEqual(pasteboardService.copyReceivedString, "secretPassword")
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyPassword` does nothing if the cipher has no password.
    @MainActor
    func test_performMoreOptionsAction_copyPassword_noPassword() async throws {
        stateService.activeAccount = .fixture()
        let cipherView = CipherView.loginFixture()
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .copyPassword,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertNil(pasteboardService.copyReceivedString)
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyTotp` generates and copies the TOTP code.
    @MainActor
    func test_performMoreOptionsAction_copyTotp() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.refreshTOTPCodeResult = .success(
            LoginTOTPState(
                authKeyModel: TOTPKeyModel(authenticatorKey: .standardTotpKey),
                codeModel: TOTPCodeModel(code: "123321", codeGenerationDate: Date(), period: 30),
            ),
        )
        let cipherView = CipherView.fixture(login: .fixture(totp: "totpKey"))
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .copyTotp,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(pasteboardService.copyReceivedString, "123321")
    }

    /// `performMoreOptionsAction(_:for:...)` with `.launch` opens the cipher's URI.
    @MainActor
    func test_performMoreOptionsAction_launch() async throws {
        stateService.activeAccount = .fixture()
        let cipherView = CipherView.loginFixture(
            login: .fixture(uris: [.fixture(uri: URL.example.relativeString, match: nil)]),
        )
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        var urlToOpen: URL?
        await subject.performMoreOptionsAction(
            .launch,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { urlToOpen = $0 },
        )

        XCTAssertEqual(urlToOpen, .example)
    }

    /// `performMoreOptionsAction(_:for:...)` with `.archive` archives the cipher.
    @MainActor
    func test_performMoreOptionsAction_archive() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.doesActiveAccountHavePremiumResult = true
        vaultRepository.archiveCipherResult = .success(())
        let cipherView = CipherView.loginFixture(archivedDate: nil, deletedDate: nil)
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        var toastToDisplay: Toast?
        await subject.performMoreOptionsAction(
            .archive,
            for: item,
            delegate: nil,
            handleDisplayToast: { toastToDisplay = $0 },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        let confirmAlert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(confirmAlert.title, Localizations.archiveItem)
        coordinator.loadingOverlaysShown = []
        try await confirmAlert.tapAction(title: Localizations.archive)

        XCTAssertEqual(coordinator.loadingOverlaysShown.last?.title, Localizations.sendingToArchive)
        XCTAssertEqual(vaultRepository.archiveCipher, [cipherView])
        XCTAssertEqual(toastToDisplay, Toast(title: Localizations.itemMovedToArchive))
    }

    /// `performMoreOptionsAction(_:for:...)` with `.archive` does not archive when the user cancels
    /// the confirmation alert.
    @MainActor
    func test_performMoreOptionsAction_archive_confirmationCancel() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.doesActiveAccountHavePremiumResult = true

        let cipherView = CipherView.loginFixture(archivedDate: nil, deletedDate: nil)
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        var toastToDisplay: Toast?
        await subject.performMoreOptionsAction(
            .archive,
            for: item,
            delegate: nil,
            handleDisplayToast: { toastToDisplay = $0 },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        let confirmAlert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(confirmAlert.title, Localizations.archiveItem)

        try await confirmAlert.tapCancel()

        XCTAssertTrue(vaultRepository.archiveCipher.isEmpty)
        XCTAssertNil(toastToDisplay)
    }

    /// `performMoreOptionsAction(_:for:...)` with `.archive` presents the master password re-prompt
    /// alert and archives the cipher when the master password is confirmed.
    @MainActor
    func test_performMoreOptionsAction_archive_passwordReprompt() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.doesActiveAccountHavePremiumResult = true
        masterPasswordRepromptHelper.repromptForMasterPasswordAutoComplete = false

        let cipherView = CipherView.loginFixture(archivedDate: nil, deletedDate: nil, reprompt: .password)
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        var toastToDisplay: Toast?
        await subject.performMoreOptionsAction(
            .archive,
            for: item,
            delegate: nil,
            handleDisplayToast: { toastToDisplay = $0 },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        coordinator.loadingOverlaysShown = []
        vaultRepository.archiveCipherResult = .success(())

        let confirmAlert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(confirmAlert.title, Localizations.archiveItem)
        try await confirmAlert.tapAction(title: Localizations.archive)

        // Validate master password re-prompt is shown.
        XCTAssertEqual(masterPasswordRepromptHelper.repromptForMasterPasswordCipherView, cipherView)

        // Validate archive operation hasn't occurred yet.
        XCTAssertTrue(vaultRepository.archiveCipher.isEmpty)
        XCTAssertNil(toastToDisplay)

        // Complete the master password reprompt.
        await masterPasswordRepromptHelper.repromptForMasterPasswordCompletion?()

        // Validate archive operation completes successfully.
        XCTAssertEqual(coordinator.loadingOverlaysShown.last?.title, Localizations.sendingToArchive)
        XCTAssertEqual(vaultRepository.archiveCipher, [cipherView])
        XCTAssertEqual(toastToDisplay, Toast(title: Localizations.itemMovedToArchive))
    }

    /// `performMoreOptionsAction(_:for:...)` with `.archive` displays an alert and invokes the
    /// Premium upgrade navigation callback when archiving is unavailable.
    @MainActor
    func test_performMoreOptionsAction_archiveUnavailable_invokesPremiumUpgradeCallback() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.doesActiveAccountHavePremiumResult = false

        let cipherView = CipherView.loginFixture(archivedDate: nil, deletedDate: nil)
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        var toastToDisplay: Toast?
        var navigatedToPremiumUpgrade = false
        coordinator.loadingOverlaysShown = []
        vaultRepository.archiveCipherResult = .success(())
        await subject.performMoreOptionsAction(
            .archive,
            for: item,
            delegate: nil,
            handleDisplayToast: { toastToDisplay = $0 },
            handleNavigateToPremiumUpgrade: { navigatedToPremiumUpgrade = true },
            handleOpenURL: { _ in },
        )

        let archiveUnavailableAlert = try XCTUnwrap(coordinator.alertShown.last)

        XCTAssertEqual(archiveUnavailableAlert.alertActions.map(\.title), [Localizations.ok])

        try await archiveUnavailableAlert.tapAction(title: Localizations.ok)

        XCTAssertNil(coordinator.loadingOverlaysShown.last?.title)
        XCTAssertTrue(vaultRepository.archiveCipher.isEmpty)
        XCTAssertNil(toastToDisplay)
        XCTAssertFalse(navigatedToPremiumUpgrade)
    }

    /// `performMoreOptionsAction(_:for:...)` with `.unarchive` unarchives the cipher.
    @MainActor
    func test_performMoreOptionsAction_unarchive() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.unarchiveCipherResult = .success(())
        let cipherView = CipherView.loginFixture(archivedDate: .now, deletedDate: nil)
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        var toastToDisplay: Toast?
        await subject.performMoreOptionsAction(
            .unarchive,
            for: item,
            delegate: nil,
            handleDisplayToast: { toastToDisplay = $0 },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(coordinator.loadingOverlaysShown.last?.title, Localizations.movingItemToVault)
        XCTAssertEqual(vaultRepository.unarchiveCipher, [cipherView])
        XCTAssertEqual(toastToDisplay, Toast(title: Localizations.itemMovedToVault))
    }

    /// `performMoreOptionsAction(_:for:...)` with `.unarchive` presents the master password
    /// re-prompt alert and unarchives the cipher when the master password is confirmed.
    @MainActor
    func test_performMoreOptionsAction_unarchive_passwordReprompt() async throws {
        stateService.activeAccount = .fixture()
        masterPasswordRepromptHelper.repromptForMasterPasswordAutoComplete = false
        vaultRepository.unarchiveCipherResult = .success(())

        let cipherView = CipherView.loginFixture(archivedDate: .now, deletedDate: nil, reprompt: .password)
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture(archivedDate: .now)))

        var toastToDisplay: Toast?
        await subject.performMoreOptionsAction(
            .unarchive,
            for: item,
            delegate: nil,
            handleDisplayToast: { toastToDisplay = $0 },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        // Validate master password re-prompt is shown.
        XCTAssertEqual(masterPasswordRepromptHelper.repromptForMasterPasswordCipherView, cipherView)

        // Validate unarchive operation hasn't occurred yet.
        XCTAssertTrue(vaultRepository.unarchiveCipher.isEmpty)
        XCTAssertNil(toastToDisplay)

        // Complete the master password reprompt.
        coordinator.loadingOverlaysShown = []
        await masterPasswordRepromptHelper.repromptForMasterPasswordCompletion?()

        // Validate unarchive operation completes successfully.
        XCTAssertEqual(coordinator.loadingOverlaysShown.last?.title, Localizations.movingItemToVault)
        XCTAssertEqual(vaultRepository.unarchiveCipher, [cipherView])
        XCTAssertEqual(toastToDisplay, Toast(title: Localizations.itemMovedToVault))
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyCardNumber` copies the card's number.
    @MainActor
    func test_performMoreOptionsAction_copyCardNumber() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.fetchCipherResult = .success(.cardFixture(card: .fixture(code: "123", number: "123456789")))
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture(type: .card(.init(brand: nil)))))

        await subject.performMoreOptionsAction(
            .copyCardNumber,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(pasteboardService.copyReceivedString, "123456789")
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copySecurityCode` copies the card's security code.
    @MainActor
    func test_performMoreOptionsAction_copySecurityCode() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.fetchCipherResult = .success(.cardFixture(card: .fixture(code: "123", number: "123456789")))
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture(type: .card(.init(brand: nil)))))

        await subject.performMoreOptionsAction(
            .copySecurityCode,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(pasteboardService.copyReceivedString, "123")
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyNotes` copies the cipher's notes.
    @MainActor
    func test_performMoreOptionsAction_copyNotes() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.fetchCipherResult = .success(.fixture(notes: "Test Note", type: .secureNote))
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture(type: .secureNote)))

        await subject.performMoreOptionsAction(
            .copyNotes,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(pasteboardService.copyReceivedString, "Test Note")
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyTotp` presents the master password
    /// re-prompt alert and copies the TOTP code when the master password is confirmed.
    @MainActor
    func test_performMoreOptionsAction_copyTotp_passwordReprompt() async throws {
        stateService.activeAccount = .fixture()
        masterPasswordRepromptHelper.repromptForMasterPasswordAutoComplete = false

        vaultRepository.refreshTOTPCodeResult = .success(
            LoginTOTPState(
                authKeyModel: TOTPKeyModel(authenticatorKey: .standardTotpKey),
                codeModel: TOTPCodeModel(code: "123321", codeGenerationDate: Date(), period: 30),
            ),
        )
        let cipherView = CipherView.fixture(
            login: .fixture(totp: "totpKey"),
            reprompt: .password,
        )
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        var toastToDisplay: Toast?
        await subject.performMoreOptionsAction(
            .copyTotp,
            for: item,
            delegate: nil,
            handleDisplayToast: { toastToDisplay = $0 },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        // Validate master password re-prompt is shown.
        XCTAssertEqual(masterPasswordRepromptHelper.repromptForMasterPasswordCipherView, cipherView)

        // Validate string is copied only if master password reprompt completes successfully.
        XCTAssertNil(pasteboardService.copyReceivedString)
        await masterPasswordRepromptHelper.repromptForMasterPasswordCompletion?()
        XCTAssertEqual(pasteboardService.copyReceivedString, "123321")
        XCTAssertEqual(
            toastToDisplay,
            Toast(title: Localizations.valueHasBeenCopied(Localizations.verificationCodeTotp)),
        )
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyTotp` copies the TOTP code if the user
    /// doesn't have Premium but the organization uses TOTP.
    @MainActor
    func test_performMoreOptionsAction_copyTotp_organizationUseTotp() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.doesActiveAccountHavePremiumResult = false
        vaultRepository.refreshTOTPCodeResult = .success(
            LoginTOTPState(
                authKeyModel: TOTPKeyModel(authenticatorKey: .standardTotpKey),
                codeModel: TOTPCodeModel(code: "123321", codeGenerationDate: Date(), period: 30),
            ),
        )

        vaultRepository.fetchCipherResult = .success(.fixture(
            login: .fixture(totp: "totpKey"),
            organizationUseTotp: true,
        ))
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture(organizationUseTotp: true)))

        var toastToDisplay: Toast?
        await subject.performMoreOptionsAction(
            .copyTotp,
            for: item,
            delegate: nil,
            handleDisplayToast: { toastToDisplay = $0 },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(pasteboardService.copyReceivedString, "123321")
        XCTAssertEqual(
            toastToDisplay,
            Toast(title: Localizations.valueHasBeenCopied(Localizations.verificationCodeTotp)),
        )
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyTotp` logs an error if refreshing the TOTP
    /// code doesn't return a code.
    @MainActor
    func test_performMoreOptionsAction_copyTotp_refreshTOTPEmpty() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.refreshTOTPCodeResult = .success(
            LoginTOTPState(authKeyModel: TOTPKeyModel(authenticatorKey: .standardTotpKey)),
        )

        vaultRepository.fetchCipherResult = .success(.fixture(login: .fixture(totp: "totpKey")))
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .copyTotp,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(coordinator.alertShown.last, .defaultAlert(title: Localizations.anErrorHasOccurred))
        XCTAssertEqual(errorReporter.errors as? [TOTPServiceError], [.unableToGenerateCode(nil)])
    }

    /// `performMoreOptionsAction(_:for:...)` with `.copyTotp` logs an error if refreshing the TOTP
    /// code fails.
    @MainActor
    func test_performMoreOptionsAction_copyTotp_refreshTOTPError() async throws {
        stateService.activeAccount = .fixture()
        vaultRepository.refreshTOTPCodeResult = .failure(BitwardenTestError.example)

        vaultRepository.fetchCipherResult = .success(.fixture(login: .fixture(totp: "totpKey")))
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .copyTotp,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(coordinator.alertShown.last, .defaultAlert(title: Localizations.anErrorHasOccurred))
        XCTAssertEqual(errorReporter.errors as? [BitwardenTestError], [.example])
    }

    /// `performMoreOptionsAction(_:for:...)` with `.edit` presents the master password re-prompt
    /// alert and navigates to the edit view when the master password is confirmed.
    @MainActor
    func test_performMoreOptionsAction_edit_passwordReprompt() async throws {
        stateService.activeAccount = .fixture()
        masterPasswordRepromptHelper.repromptForMasterPasswordAutoComplete = false

        let cipherView = CipherView.fixture(reprompt: .password)
        vaultRepository.fetchCipherResult = .success(cipherView)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .edit,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        // Validate master password re-prompt is shown.
        XCTAssertEqual(masterPasswordRepromptHelper.repromptForMasterPasswordCipherView, cipherView)

        // Validate the route is only navigated to if master password reprompt completes successfully.
        XCTAssertTrue(coordinator.routes.isEmpty)
        await masterPasswordRepromptHelper.repromptForMasterPasswordCompletion?()
        XCTAssertEqual(coordinator.routes, [.editItem(cipherView)])
    }

    /// `performMoreOptionsAction(_:for:...)` with `.edit` routes the saved confirmation through the
    /// caller's delegate rather than a toast closure held by the helper.
    @MainActor
    func test_performMoreOptionsAction_edit_savedToastComesFromDelegate() async throws {
        stateService.activeAccount = .fixture()

        vaultRepository.fetchCipherResult = .success(.fixture(type: .identity))
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        var displayedToast: Toast?
        let delegate = MockCipherItemOperationDelegate()
        await subject.performMoreOptionsAction(
            .edit,
            for: item,
            delegate: delegate,
            handleDisplayToast: { displayedToast = $0 },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        let context = try XCTUnwrap(coordinator.contexts.last as? CipherItemOperationDelegate)
        XCTAssertTrue(context.itemUpdated(type: .driversLicense))

        // The helper doesn't display the toast itself, the delegate is left to do it.
        XCTAssertNil(displayedToast)
        XCTAssertTrue(delegate.itemUpdatedCalled)
        XCTAssertEqual(delegate.itemUpdatedType, .driversLicense)
    }

    /// `performMoreOptionsAction(_:for:...)` with `.edit` does not show the password re-prompt
    /// alert when the user has no master password.
    @MainActor
    func test_performMoreOptionsAction_edit_noPassword() async throws {
        let account = Account.fixture()
        stateService.activeAccount = account
        stateService.userHasMasterPassword = [account.profile.userId: false]

        // Although the cipher calls for a password reprompt, it won't be shown
        // because the user has no password.
        let login = CipherView.fixture(reprompt: .password)
        vaultRepository.fetchCipherResult = .success(login)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture(reprompt: .password)))

        await subject.performMoreOptionsAction(
            .edit,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertTrue(coordinator.alertShown.isEmpty)
        XCTAssertEqual(coordinator.routes.last, .editItem(login))
    }

    /// `performMoreOptionsAction(_:for:...)` does nothing when the cipher fetched is `nil`.
    @MainActor
    func test_performMoreOptionsAction_noCipher() async throws {
        vaultRepository.fetchCipherResult = .success(nil)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .view,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertTrue(coordinator.alertShown.isEmpty)
        XCTAssertTrue(coordinator.routes.isEmpty)
    }

    /// `performMoreOptionsAction(_:for:...)` logs an error and shows an alert when fetching the cipher throws.
    @MainActor
    func test_performMoreOptionsAction_fetchCipherThrows() async throws {
        vaultRepository.fetchCipherResult = .failure(BitwardenTestError.example)
        let item = try XCTUnwrap(VaultListItem(cipherListView: .fixture()))

        await subject.performMoreOptionsAction(
            .view,
            for: item,
            delegate: nil,
            handleDisplayToast: { _ in },
            handleNavigateToPremiumUpgrade: {},
            handleOpenURL: { _ in },
        )

        XCTAssertEqual(errorReporter.errors as? [BitwardenTestError], [.example])
        let alert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(alert.title, Localizations.anErrorHasOccurred)
    }
}

class MockVaultItemMoreOptionsHelper: VaultItemMoreOptionsHelper {
    var performActionCalled = false
    var performActionKind: MoreOptionsActionKind?
    var performActionItem: VaultListItem?
    var performActionDelegate: CipherItemOperationDelegate?
    var performActionHandleDisplayToast: ((Toast) -> Void)?
    var performActionHandlePremiumUpgrade: (() async -> Void)?
    var performActionHandleOpenURL: ((URL) -> Void)?

    func performMoreOptionsAction( // swiftlint:disable:this function_parameter_count
        _ kind: MoreOptionsActionKind,
        for item: VaultListItem,
        delegate: CipherItemOperationDelegate?,
        handleDisplayToast: @escaping (Toast) -> Void,
        handleNavigateToPremiumUpgrade: @escaping () async -> Void,
        handleOpenURL: @escaping (URL) -> Void,
    ) async {
        performActionCalled = true
        performActionKind = kind
        performActionItem = item
        performActionDelegate = delegate
        performActionHandleDisplayToast = handleDisplayToast
        performActionHandlePremiumUpgrade = handleNavigateToPremiumUpgrade
        performActionHandleOpenURL = handleOpenURL
    }

    var moveToFolderItem: VaultListItem?
    var moveToFolderId: String?
    var moveToFolderHandleDisplayToast: ((Toast) -> Void)?

    func moveToFolder(_ item: VaultListItem, folderId: String?, handleDisplayToast: @escaping (Toast) -> Void) async {
        moveToFolderItem = item
        moveToFolderId = folderId
        moveToFolderHandleDisplayToast = handleDisplayToast
    }

    var moveToNewFolderItem: VaultListItem?
    var moveToNewFolderOnFolderCreated: (() async -> Void)?

    func moveToNewFolder(
        _ item: VaultListItem,
        handleDisplayToast: @escaping (Toast) -> Void,
        onFolderCreated: @escaping () async -> Void,
    ) async {
        moveToNewFolderItem = item
        moveToNewFolderOnFolderCreated = onFolderCreated
    }
}
