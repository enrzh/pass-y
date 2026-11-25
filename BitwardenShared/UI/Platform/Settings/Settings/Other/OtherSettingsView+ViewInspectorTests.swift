// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import ViewInspector
import XCTest

@testable import BitwardenShared

class OtherSettingsViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<OtherSettingsState, OtherSettingsAction, OtherSettingsEffect>!
    var subject: OtherSettingsView!

    override func setUp() {
        super.setUp()

        processor = MockProcessor(state: OtherSettingsState())

        subject = OtherSettingsView(store: Store(processor: processor))
    }

    override func tearDown() {
        super.tearDown()

        processor = nil
        subject = nil
    }

    // MARK: Tests

    /// ui-r9: the Other page has no watch toggle (the watch app and its connectivity were removed).
    @MainActor
    func test_noWatchOption() throws {
        XCTAssertThrowsError(try subject.inspect().find(ViewType.Toggle.self, where: { toggle in
            ((try? toggle.labelView().find(ViewType.Text.self).string()) ?? "").lowercased().contains("watch")
        }))
        XCTAssertThrowsError(try subject.inspect().find(text: "Connect to Watch"))
    }

    /// Tapping the sync now button performs the `.syncNow` effect.
    @MainActor
    func test_syncNow_tapped() async throws {
        let button = try subject.inspect().find(button: Localizations.syncNow)
        try button.tap()
        try await waitForAsync { !self.processor.effects.isEmpty }
        XCTAssertEqual(processor.effects.last, .syncNow)
    }

    /// The connect to watch toggle is hidden if the device is not an iPhone.
    @MainActor
    func test_connectToWatchToggle_hidden() async throws {
        processor.state.shouldShowConnectToWatchToggle = false
        XCTAssertThrowsError(try subject.inspect().find(toggleWithAccessibilityLabel: Localizations.connectToWatch))
    }

    /// The connect to watch toggle is visible if the device is an iPhone.
    @MainActor
    func test_connectToWatchToggle_visible() async throws {
        processor.state.shouldShowConnectToWatchToggle = true
        XCTAssertNoThrow(try subject.inspect().find(toggleWithAccessibilityLabel: Localizations.connectToWatch))
    }
}
