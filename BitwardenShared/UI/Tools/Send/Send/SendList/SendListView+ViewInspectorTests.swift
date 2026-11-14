// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - SendListViewTests

class SendListViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<SendListState, SendListAction, SendListEffect>!
    var subject: SendListView!

    override func setUp() {
        super.setUp()

        processor = MockProcessor(state: SendListState())
        subject = SendListView(store: Store(processor: processor))
    }

    override func tearDown() {
        super.tearDown()

        processor = nil
        subject = nil
    }

    // MARK: Tests

    /// When restricted to a single Send type by policy, tapping the add control in the bottom bar opens
    /// that type directly (no menu).
    @MainActor
    func test_addControl_restrictedSendType_tap() async throws {
        var added: [SendType] = []
        let bar = SendBottomBar(
            addSend: { added.append($0) },
            restrictedSendType: .text,
            isEditing: .constant(false),
            text: .constant(""),
        )
        let button = try bar.inspect().find(asyncButtonWithAccessibilityIdentifier: "AddItemFloatingActionButton")
        try await button.tap()
        XCTAssertEqual(added, [.text])
    }

    /// Without a restriction, the bottom bar menu offers Text and File and each adds that type.
    @MainActor
    func test_addControl_menu_offersTextAndFile() async throws {
        var added: [SendType] = []
        let bar = SendBottomBar(
            addSend: { added.append($0) },
            restrictedSendType: nil,
            isEditing: .constant(false),
            text: .constant(""),
        )
        try await bar.inspect().find(asyncButton: Localizations.text).tap()
        try await bar.inspect().find(asyncButton: Localizations.file).tap()
        XCTAssertEqual(added, [.text, .file])
    }

    /// Tapping the add item floating action menu and selecting the file type performs the `.addItemPressed` effect.
    @MainActor
    func test_addItemFloatingActionMenu_file_tap() async throws {
        let fabMenuButton = try subject.inspect().find(asyncButton: Localizations.file)
        try await fabMenuButton.tap()
        XCTAssertEqual(processor.effects.last, .addItemPressed(.file))
    }

    /// When restricted to a single Send type by policy, the add item floating action menu is not
    /// shown (the chooser is bypassed).
    @MainActor
    func test_addItemFloatingActionMenu_restrictedSendType_hidden() throws {
        processor.state.restrictedSendType = .text
        XCTAssertThrowsError(try subject.inspect().find(asyncButton: Localizations.file))
    }

    /// Tapping the add item floating action menu and selecting the text type performs the `.addItemPressed` effect.
    @MainActor
    func test_addItemFloatingActionMenu_text_tap() async throws {
        let fabMenuButton = try subject.inspect().find(asyncButton: Localizations.text)
        try await fabMenuButton.tap()
        XCTAssertEqual(processor.effects.last, .addItemPressed(.text))
    }

    /// When restricted to a single Send type by policy, tapping the empty state's New Send button
    /// opens that type directly, performing the `.addItemPressed` effect without showing the menu.
    @MainActor
    func test_emptyState_addSendButton_restrictedSendType_tap() async throws {
        processor.state = .empty
        processor.state.restrictedSendType = .file
        let button = try subject.inspect().find(asyncButton: Localizations.newSend)
        try await button.tap()
        XCTAssertEqual(processor.effects.last, .addItemPressed(.file))
    }

    /// Tapping the add a send button in the empty state performs the `.addItemPressed` effect.
    @MainActor
    func test_emptyState_addSendButton_sendTypeFile_tap() async throws {
        processor.state = .empty
        processor.state.type = .file
        let button = try subject.inspect().find(asyncButton: Localizations.newSend)
        try await button.tap()
        XCTAssertEqual(processor.effects.last, .addItemPressed(.file))
    }

    /// Tapping the add a send button in the empty state performs the `.addItemPressed` effect.
    @MainActor
    func test_emptyState_addSendButton_sendTypeText_tap() async throws {
        processor.state = .empty
        processor.state.type = .text
        let button = try subject.inspect().find(asyncButton: Localizations.newSend)
        try await button.tap()
        XCTAssertEqual(processor.effects.last, .addItemPressed(.text))
    }

    /// Tapping the info button dispatches the `.infoButtonPressed` action.
    @MainActor
    func test_infoButton_tap() throws {
        let button = try subject.inspect().find(button: Localizations.aboutSend)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .infoButtonPressed)
    }
}
