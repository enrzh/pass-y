// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - VaultListItemRowViewTests

class VaultListItemRowViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<VaultListItemRowState, VaultListItemRowAction, VaultListItemRowEffect>!
    var subject: VaultListItemRowView!
    var timeProvider: MockTimeProvider!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        let state = VaultListItemRowState(item: .fixture(), hasDivider: false, showWebIcons: true)
        processor = MockProcessor(state: state)
        let store = Store(processor: processor)
        timeProvider = MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31)))
        subject = VaultListItemRowView(store: store, timeProvider: timeProvider)
    }

    override func tearDown() {
        super.tearDown()
        processor = nil
        subject = nil
        timeProvider = nil
    }

    // MARK: Tests

    /// Test that tapping the row dispatches the `.pressed` effect.
    @MainActor
    func test_pressed_tap() throws {
        let button = try subject.inspect().find(buttonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try button.tap()
        waitFor(processor.effects.last == .pressed)
        XCTAssertEqual(processor.effects.last, .pressed)
    }

    /// ui-r6: no "..." button in the row; a disclosure chevron instead (options are in the context menu and swipe).
    @MainActor
    func test_noMoreButton_hasChevron() throws {
        XCTAssertThrowsError(try subject.inspect().find(buttonWithAccessibilityLabel: Localizations.moreOptions))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "CipherDisclosureChevron"))
    }

    /// Test that the chevron isn't shown when displayed from an extension.
    @MainActor
    func test_chevron_notShownFromExtension() throws {
        processor.state = VaultListItemRowState(
            isFromExtension: true,
            item: .fixture(),
            hasDivider: false,
            showWebIcons: true,
        )
        XCTAssertThrowsError(
            try subject.inspect().find(viewWithAccessibilityIdentifier: "CipherDisclosureChevron"),
        )
    }

    /// PassYDesign: a tap on a code row copies the code (no separate copy button).
    @MainActor
    func test_totpRow_tapCopiesCode() throws {
        let totp = VaultListTOTP.fixture(timeProvider: timeProvider)
        processor.state = VaultListItemRowState(item: .fixtureTOTP(totp: totp), hasDivider: false, showWebIcons: true)
        XCTAssertThrowsError(try subject.inspect().find(buttonWithAccessibilityLabel: Localizations.copyTotp))
        let button = try subject.inspect().find(buttonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try button.tap()
        waitFor(!processor.dispatchedActions.isEmpty)
        XCTAssertEqual(processor.dispatchedActions.last, .copyTOTPCode(totp.totpCode.code))
        XCTAssertTrue(processor.effects.isEmpty, "copying does not open the item")
        XCTAssertNoThrow(try subject.inspect().find(text: "123 456"), "the code is shown in two groups")
    }

    /// PassYDesign: a code that needs the master password shows no code and a tap opens the item (reprompt).
    @MainActor
    func test_totpRow_requiresMasterPassword_tapOpensItem() throws {
        let totp = VaultListTOTP.fixture(requiresMasterPassword: true, timeProvider: timeProvider)
        processor.state = VaultListItemRowState(item: .fixtureTOTP(totp: totp), hasDivider: false, showWebIcons: true)
        XCTAssertThrowsError(try subject.inspect().find(text: "123 456"), "the code is hidden")
        let button = try subject.inspect().find(buttonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try button.tap()
        waitFor(processor.effects.last == .pressed)
        XCTAssertTrue(processor.dispatchedActions.isEmpty)
    }

    /// PassYDesign: in an extension list a tap on a code row picks the item instead of copying.
    @MainActor
    func test_totpRow_fromExtension_tapPicksItem() throws {
        let totp = VaultListTOTP.fixture(timeProvider: timeProvider)
        processor.state = VaultListItemRowState(
            isFromExtension: true,
            item: .fixtureTOTP(totp: totp),
            hasDivider: false,
            showTotpCopyButton: false,
            showWebIcons: true,
        )
        let button = try subject.inspect().find(buttonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try button.tap()
        waitFor(processor.effects.last == .pressed)
        XCTAssertTrue(processor.dispatchedActions.isEmpty)
    }

    /// ui-r8: the row button has a rectangular content shape (the blank part between text and chevron is tappable)
    /// and the chevron is part of the button, not beside it.
    @MainActor
    func test_rowButton_wholeRowIsHitArea() throws {
        let button = try subject.inspect().find(buttonWithAccessibilityIdentifier: "VaultListItemRowButton")
        XCTAssertNoThrow(try button.find(ViewType.HStack.self) { (try? $0.contentShape(Rectangle.self)) != nil })
        XCTAssertNoThrow(try button.find(viewWithAccessibilityIdentifier: "CipherDisclosureChevron"))
    }

    /// ui-r8: folder rows (group rows) have the same whole-row hit area and show their count.
    @MainActor
    func test_groupRow_wholeRowIsHitArea() throws {
        processor.state = VaultListItemRowState(
            item: .fixtureGroup(group: .folder(id: "1", name: "Folder"), count: 3),
            hasDivider: false,
            showWebIcons: true,
        )
        let button = try subject.inspect().find(buttonWithAccessibilityIdentifier: "VaultListItemRowButton")
        XCTAssertNoThrow(try button.find(ViewType.HStack.self) { (try? $0.contentShape(Rectangle.self)) != nil })
        XCTAssertEqual(try button.find(viewWithAccessibilityIdentifier: "GroupCountLabel").text().string(), "3")
    }

    /// PassYDesign: a favourite, shared item with attachments shows the three quiet badges.
    @MainActor
    func test_cipherRow_badges() throws {
        processor.state = VaultListItemRowState(
            item: .fixture(cipherListView: .fixture(organizationId: "org", favorite: true, attachments: 2)),
            hasDivider: false,
            showWebIcons: true,
        )
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "CipherFavoriteIcon"))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "CipherInCollectionIcon"))
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "CipherWithAttachmentsIcon"))
    }

    /// ui-r8: a row built from plain values reports presses through the closure (no `Store`).
    @MainActor
    func test_directInit_pressed() throws {
        var effects: [VaultListItemRowEffect] = []
        let direct = VaultListItemRowView(
            state: VaultListItemRowState(item: .fixture(), hasDivider: false, showWebIcons: true),
            perform: { effects.append($0) },
            send: { _ in },
        )
        let button = try direct.inspect().find(buttonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try button.tap()
        waitFor(!effects.isEmpty)
        XCTAssertEqual(effects, [.pressed])
    }

    /// ui-r8: the equatable cell used by the vault lists exposes the same identifier on the tappable button.
    @MainActor
    func test_cell_keepsIdentifier_andTapReachesEffect() throws {
        var effects: [VaultListItemRowEffect] = []
        let cell = VaultListRowCell(
            state: VaultListItemRowState(item: .fixture(), hasDivider: false, showWebIcons: true),
            perform: { effects.append($0) },
            send: { _ in },
            timeProvider: MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31))),
            onDelete: nil,
        )
        let button = try cell.equatable().inspect().find(buttonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try button.tap()
        waitFor(!effects.isEmpty)
        XCTAssertEqual(effects, [.pressed])
    }
}
