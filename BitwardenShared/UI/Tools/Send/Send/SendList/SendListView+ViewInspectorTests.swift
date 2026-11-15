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

    /// Without a restriction the bottom bar menu offers Text and File and each adds that type.
    @MainActor
    func test_addEntries_offersTextAndFile() {
        var added: [SendType] = []
        let entries = SendListView.addEntries(restrictedSendType: nil) { added.append($0) }
        XCTAssertEqual(Set(entries.map(\.title)), Set([SendType.text.localizedName, SendType.file.localizedName]))
        entries.forEach { $0.action() }
        XCTAssertEqual(Set(added), [.text, .file])
        XCTAssertEqual(added.count, 2)
    }

    /// When restricted to a single Send type by policy the bottom bar has one entry for that type (the chooser is
    /// bypassed).
    @MainActor
    func test_addEntries_restrictedSendType_singleEntry() {
        var added: [SendType] = []
        let entries = SendListView.addEntries(restrictedSendType: .text) { added.append($0) }
        XCTAssertEqual(entries.count, 1)
        entries.first?.action()
        XCTAssertEqual(added, [.text])
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
        let menu = try subject.inspect().find(ViewType.Menu.self, containing: Localizations.options)
        let button = try menu.find(button: Localizations.aboutSend)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .infoButtonPressed)
    }
}
