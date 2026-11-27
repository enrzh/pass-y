// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import XCTest

@testable import BitwardenShared

class VaultSettingsViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<VaultSettingsState, VaultSettingsAction, VaultSettingsEffect>!
    var subject: VaultSettingsView!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        processor = MockProcessor(state: VaultSettingsState())
        let store = Store(processor: processor)

        subject = VaultSettingsView(store: store)
    }

    override func tearDown() {
        super.tearDown()

        processor = nil
        subject = nil
    }

    // MARK: Tests

    /// Tapping the export vault button dispatches the `.exportVaultTapped` action.
    @MainActor
    func test_exportVaultButton_tap() throws {
        let button = try subject.inspect().find(button: Localizations.exportVault)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .exportVaultTapped)
    }

    /// The encrypted backup row shows "Off" and dispatches `.encryptedBackupTapped`.
    @MainActor
    func test_encryptedBackupButton_tap() throws {
        XCTAssertNoThrow(try subject.inspect().find(text: Localizations.off))
        try subject.inspect().find(button: Localizations.encryptedBackup).tap()
        XCTAssertEqual(processor.dispatchedActions.last, .encryptedBackupTapped)
    }

    /// Tapping the folders button dispatches the `.foldersTapped` action.
    @MainActor
    func test_foldersButton_tap() throws {
        let button = try subject.inspect().find(button: Localizations.myFolders)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .foldersTapped)
    }

    /// The action card is hidden if the import logins setup progress is incomplete or complete.
    @MainActor
    func test_importLoginsActionCard_hidden() {
        processor.state.badgeState = .fixture(importLoginsSetupProgress: .incomplete)
        XCTAssertThrowsError(try subject.inspect().find(setupSection: Localizations.importSavedLogins))

        processor.state.badgeState = .fixture(importLoginsSetupProgress: .complete)
        XCTAssertThrowsError(try subject.inspect().find(setupSection: Localizations.importSavedLogins))
    }

    /// The action card is visible if the import logins setup progress is set up later.
    @MainActor
    func test_importLoginsActionCard_visible() async throws {
        processor.state.badgeState = .fixture(importLoginsSetupProgress: .setUpLater)
        let section = try subject.inspect().find(setupSection: Localizations.importSavedLogins)
        _ = try section.find(text: Localizations.importSavedLoginsDescriptionLong)
        _ = try section.find(button: Localizations.getStarted)
        _ = try section.find(button: Localizations.dismiss)
    }

    /// Tapping the dismiss button in the import logins action card sends the
    /// `.dismissImportLoginsActionCard` effect.
    @MainActor
    func test_importLoginsActionCard_visible_tapDismiss() async throws {
        processor.state.badgeState = .fixture(importLoginsSetupProgress: .setUpLater)
        let actionCard = try subject.inspect().find(setupSection: Localizations.importSavedLogins)

        let button = try actionCard.find(button: Localizations.dismiss)
        try button.tap()
        try await waitForAsync { !self.processor.effects.isEmpty }
        XCTAssertEqual(processor.effects, [.dismissImportLoginsActionCard])
    }

    /// Tapping the get started button in the import logins action card sends the
    /// `.showImportLogins` action.
    @MainActor
    func test_importLoginsActionCard_visible_tapGetStarted() async throws {
        processor.state.badgeState = .fixture(importLoginsSetupProgress: .setUpLater)
        let actionCard = try subject.inspect().find(setupSection: Localizations.importSavedLogins)

        let button = try actionCard.find(button: Localizations.getStarted)
        try button.tap()
        try await waitForAsync { !self.processor.dispatchedActions.isEmpty }
        XCTAssertEqual(processor.dispatchedActions, [.showImportLogins])
    }
}
