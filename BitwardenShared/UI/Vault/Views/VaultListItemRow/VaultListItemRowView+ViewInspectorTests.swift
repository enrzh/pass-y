// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
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
}
