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
    func test_pressed_tap() async throws {
        let button = try subject.inspect().find(asyncButtonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try await button.tap()
        XCTAssertEqual(processor.effects.last, .pressed)
    }

    /// ui-r6: no "..." button in the row; a disclosure chevron instead (options are in the context menu and swipe).
    @MainActor
    func test_noMoreButton_hasChevron() throws {
        XCTAssertThrowsError(try subject.inspect().find(asyncButtonWithAccessibilityLabel: Localizations.moreOptions))
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

    /// Test that tapping the totp copy button dispatches the `.copyTOTPCode` action.
    @MainActor
    func test_totpCopyButton_tap() throws {
        let totp = VaultListTOTP.fixture()
        processor.state = VaultListItemRowState(
            item: .fixtureTOTP(
                totp: totp,
            ),
            hasDivider: false,
            showWebIcons: true,
        )
        let button = try subject.inspect().find(buttonWithAccessibilityLabel: Localizations.copyTotp)
        try button.tap()
        waitFor(!processor.dispatchedActions.isEmpty)
        XCTAssertEqual(processor.dispatchedActions.last, .copyTOTPCode(totp.totpCode.code))
    }

    /// ui-r8: the row button has a rectangular content shape (the blank part between text and chevron and the side
    /// margins are tappable with `.plain`) and the chevron is part of the button, not beside it.
    @MainActor
    func test_rowButton_wholeRowIsHitArea() throws {
        let button = try subject.inspect().find(asyncButtonWithAccessibilityIdentifier: "VaultListItemRowButton")
        XCTAssertNoThrow(try button.find(ViewType.HStack.self) { (try? $0.contentShape(Rectangle.self)) != nil })
        XCTAssertNoThrow(try button.find(viewWithAccessibilityIdentifier: "CipherDisclosureChevron"))
    }

    /// ui-r8: folder rows (group rows) have the same whole-row hit area.
    @MainActor
    func test_groupRow_wholeRowIsHitArea() throws {
        processor.state = VaultListItemRowState(
            item: .fixtureGroup(group: .folder(id: "1", name: "Folder"), count: 3),
            hasDivider: false,
            showWebIcons: true,
        )
        let button = try subject.inspect().find(asyncButtonWithAccessibilityIdentifier: "VaultListItemRowButton")
        XCTAssertNoThrow(try button.find(ViewType.HStack.self) { (try? $0.contentShape(Rectangle.self)) != nil })
    }

    /// ui-r8: a row built from plain values reports presses through the closure (no `Store`).
    @MainActor
    func test_directInit_pressed() async throws {
        var effects: [VaultListItemRowEffect] = []
        let direct = VaultListItemRowView(
            state: VaultListItemRowState(item: .fixture(), hasDivider: false, showWebIcons: true),
            perform: { effects.append($0) },
            send: { _ in },
        )
        let button = try direct.inspect().find(asyncButtonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try await button.tap()
        XCTAssertEqual(effects, [.pressed])
    }

    /// ui-r8: the equatable cell used by the vault lists exposes the same identifier on the tappable button.
    @MainActor
    func test_cell_keepsIdentifier_andTapReachesEffect() async throws {
        var effects: [VaultListItemRowEffect] = []
        let cell = VaultListRowCell(
            state: VaultListItemRowState(item: .fixture(), hasDivider: false, showWebIcons: true),
            perform: { effects.append($0) },
            send: { _ in },
            timeProvider: MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31))),
            onDelete: nil,
        )
        let button = try cell.equatable().inspect().find(asyncButtonWithAccessibilityIdentifier: "VaultListItemRowButton")
        try await button.tap()
        XCTAssertEqual(effects, [.pressed])
    }
}
