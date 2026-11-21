// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import ViewInspector
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - VaultGroupViewTests

class VaultGroupViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<VaultGroupState, VaultGroupAction, VaultGroupEffect>!
    var subject: VaultGroupView!
    var timeProvider: MockTimeProvider!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        processor = MockProcessor(
            state: VaultGroupState(
                itemTypesUserCanCreate: CipherType.canCreateCases,
                searchVaultFilterType: .allVaults,
                vaultFilterType: .allVaults,
            ),
        )
        timeProvider = MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31)))
        subject = VaultGroupView(
            store: Store(processor: processor),
            timeProvider: timeProvider,
        )
    }

    override func tearDown() {
        super.tearDown()
        processor = nil
        subject = nil
        timeProvider = nil
    }

    // MARK: Tests

    /// Before iOS 26 (no `navigationSubtitle`) "N Items" is a plain secondary text row at the top of the list.
    @MainActor
    func test_itemCount_fallbackRow_withoutNavigationSubtitle() throws {
        subject = VaultGroupView(
            store: Store(processor: processor),
            timeProvider: timeProvider,
            supportsNavigationSubtitle: false,
        )
        processor.state.loadingState = .data([
            VaultListSection(
                id: "1",
                items: [
                    try XCTUnwrap(VaultListItem(cipherListView: .fixture(id: "1", name: "A"))),
                    try XCTUnwrap(VaultListItem(cipherListView: .fixture(id: "2", name: "B"))),
                ],
                name: "Items",
            ),
        ])
        let header = try subject.inspect().find(viewWithAccessibilityIdentifier: "ItemCountHeader").text()
        XCTAssertEqual(try header.string(), "2 Items")
    }

    /// With the navigation subtitle (iOS 26) there is no extra row.
    @MainActor
    func test_itemCount_noFallbackRow_withNavigationSubtitle() throws {
        subject = VaultGroupView(
            store: Store(processor: processor),
            timeProvider: timeProvider,
            supportsNavigationSubtitle: true,
        )
        processor.state.loadingState = .data([
            VaultListSection(
                id: "1",
                items: [try XCTUnwrap(VaultListItem(cipherListView: .fixture(id: "1", name: "A")))],
                name: "Items",
            ),
        ])
        XCTAssertThrowsError(try subject.inspect().find(viewWithAccessibilityIdentifier: "ItemCountHeader"))
    }

    /// Tapping the add item button dispatches the `.addItemPressed` action.
    @MainActor
    func test_addItemEmptyStateButton_tap() throws {
        processor.state.loadingState = .data([])
        let button = try subject.inspect().find(button: Localizations.addLogin)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .addItemPressed(nil))
    }

    /// Tapping an item in the add item menu dispatches the `.addItemPressed` action.
    @MainActor
    func test_addItemEmptyStateButton_hidden_restrictItemPolicy_enabled() throws {
        processor.state.loadingState = .data([])
        processor.state.group = .card
        processor.state.itemTypesUserCanCreate = [.login, .identity, .secureNote]
        XCTAssertThrowsError(try subject.inspect().find(button: Localizations.addCard))
    }

    /// Add item floating action button is hidden when in card group and restrict item policy is enabled.
    @MainActor
    func test_addItemFloatingActionButton_hidden_restrictItemPolicy_enabled() async throws {
        processor.state.loadingState = .data([])
        processor.state.group = .card
        processor.state.itemTypesUserCanCreate = [.login, .identity, .secureNote]

        XCTAssertThrowsError(
            try subject.inspect().find(
                floatingActionButtonWithAccessibilityIdentifier: "AddItemFloatingActionButton",
            ),
        )
    }

    /// Tapping an item in the add item menu dispatches the `.addItemPressed` action.
    @MainActor
    func test_addItemMenuEmptyState_tap() throws {
        processor.state.loadingState = .data([])
        processor.state.group = .folder(id: "1", name: "Folder")
        let button = try subject.inspect()
            .find(viewWithAccessibilityIdentifier: "AddItemButton")
            .find(button: Localizations.typeSecureNote)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .addItemPressed(.secureNote))
    }

    /// Tapping a vault item dispatches the `.itemPressed` effect.
    @MainActor
    func test_vaultItem_tap() async throws {
        let item = VaultListItem.fixture(cipherListView: .fixture(name: "Item"))
        let section = VaultListSection(id: "Items", items: [item], name: Localizations.items)
        processor.state.loadingState = .data([section])
        let button = try subject.inspect().find(asyncButton: "Item")
        try await button.tap()
        XCTAssertEqual(processor.effects.last, .itemPressed(item))
    }

    /// Tapping the vault item copy totp button dispatches the `.copyTOTPCode` action.
    @MainActor
    func test_vaultItem_copyTOTPButton_tap() throws {
        processor.state.loadingState = .data(
            [
                VaultListSection(
                    id: "Items",
                    items: [
                        .fixtureTOTP(
                            totp: .fixture(
                                timeProvider: timeProvider,
                            ),
                        ),
                    ],
                    name: Localizations.items,
                ),
            ],
        )
        let button = try subject.inspect().find(buttonWithAccessibilityLabel: Localizations.copyTotp)
        try button.tap()
        waitFor(!processor.dispatchedActions.isEmpty)
        XCTAssertEqual(processor.dispatchedActions.last, .copyTOTPCode("123456"))
    }

    /// ui-r6: list rows have a disclosure chevron and no "..." button; the options live in the context menu and
    /// the swipe actions.
    @MainActor
    func test_vaultItem_noMoreButton_hasChevron() throws {
        let item = VaultListItem.fixture()
        let section = VaultListSection(id: "Items", items: [item], name: Localizations.items)
        processor.state.loadingState = .data([section])
        XCTAssertThrowsError(try subject.inspect().find(asyncButtonWithAccessibilityLabel: Localizations.moreOptions))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "CipherDisclosureChevron"))
    }

    /// ui-r8: the identifier `VaultListItemRowButton` (used by the UI tests and VoiceOver users of the identifier) sits
    /// on the tappable row button of the group list, the item name stays its label, and a tap reaches the processor.
    @MainActor
    func test_vaultItem_rowButtonKeepsIdentifierAndLabel() async throws {
        let item = VaultListItem.fixture(cipherListView: .fixture(name: "Item"))
        processor.state.loadingState = .data([VaultListSection(id: "Items", items: [item], name: Localizations.items)])
        let button = try subject.inspect().find(asyncButtonWithAccessibilityIdentifier: "VaultListItemRowButton")
        XCTAssertNoThrow(try button.find(text: "Item"), "the item name is the label of the row button")
        try await button.tap()
        XCTAssertEqual(processor.effects.last, .itemPressed(item))
    }

    /// ui-r8: a folder row of the group list has the same identifier and hit area.
    @MainActor
    func test_folderRow_keepsIdentifier() throws {
        let folder = VaultListItem.fixtureGroup(group: .folder(id: "1", name: "Folder"), count: 2)
        processor.state.loadingState = .data([VaultListSection(id: "Items", items: [folder], name: Localizations.items)])
        XCTAssertNoThrow(try subject.inspect().find(asyncButtonWithAccessibilityIdentifier: "VaultListItemRowButton"))
    }
}
