// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import ViewInspector
import XCTest

@testable import BitwardenShared

class AutoFillViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<AutoFillState, AutoFillAction, AutoFillEffect>!
    var subject: AutoFillView!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        processor = MockProcessor(state: AutoFillState(shouldShowPasswordAutofill: true))
        let store = Store(processor: processor)

        subject = AutoFillView(store: store)
    }

    override func tearDown() {
        super.tearDown()

        processor = nil
        subject = nil
    }

    // MARK: Tests

    /// Tapping the app extension button dispatches the `.appExtensionTapped` action.
    @MainActor
    func test_appExtensionButton_tap() throws {
        let button = try subject.inspect().find(button: Localizations.appExtension)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .appExtensionTapped)
    }

    /// Updating the value of the default URI match type sends the `.defaultUriMatchTypeChanged` action.
    @MainActor
    func test_defaultUriMatchTypeChanged_updateValue() throws {
        processor.state.defaultUriMatchType = .host
        let picker = try subject.inspect().find(ViewType.Picker.self, containing: Localizations.defaultUriMatchDetection)
        try picker.select(value: UriMatchType.exact)
        XCTAssertEqual(processor.dispatchedActions.last, .defaultUriMatchTypeChanged(.exact))
    }

    /// Tapping the password auto-fill button dispatches the `.passwordAutoFillTapped` action.
    @MainActor
    func test_passwordAutoFillButton_tap() throws {
        let button = try subject.inspect().find(button: Localizations.passwordAutofill)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .passwordAutoFillTapped)
    }

    /// The Fill Assist toggle announces its name to VoiceOver.
    @MainActor
    func test_fillAssistToggle_accessibilityLabel() throws {
        processor.state.isFillAssistFeatureFlagEnabled = true
        _ = try subject.inspect().find(toggleWithAccessibilityLabel: Localizations.turnOnFillAssist)
    }

    /// Tapping the Fill Assist toggle sends the `.toggleFillAssist` action.
    @MainActor
    func test_fillAssistToggle_tap() throws {
        processor.state.isFillAssistFeatureFlagEnabled = true
        let toggle = try subject.inspect().find(toggleWithAccessibilityLabel: Localizations.turnOnFillAssist)
        try toggle.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .toggleFillAssist(true))
    }

    /// The Fill Assist learn more link sits in the section footer.
    @MainActor
    func test_fillAssistToggle_learnMoreButton_accessibility() throws {
        processor.state.isFillAssistFeatureFlagEnabled = true
        XCTAssertNoThrow(try subject.inspect().find(button: Localizations.learnMore))
    }

    /// The action card is hidden if the autofill setup progress is complete.
    @MainActor
    func test_setUpUnlockActionCard_hidden_complete() {
        processor.state.badgeState = .fixture(autofillSetupProgress: .complete)
        XCTAssertThrowsError(try subject.inspect().find(button: Localizations.dismiss))
        XCTAssertThrowsError(try subject.inspect().find(button: Localizations.getStarted))
    }

    /// The action card is hidden if there's no autofill setup progress.
    @MainActor
    func test_setUpUnlockActionCard_hidden_nilBadgeState() {
        processor.state.badgeState = nil
        XCTAssertThrowsError(try subject.inspect().find(button: Localizations.dismiss))
        XCTAssertThrowsError(try subject.inspect().find(button: Localizations.getStarted))
    }

    /// The action card is visible if the autofill setup progress isn't complete.
    @MainActor
    func test_setUpUnlockActionCard_visible_iOS18() async throws {
        processor.state.badgeState = .fixture(autofillSetupProgress: .setUpLater)
        let section = try subject.inspect().find(setupSection: Localizations.autofillWithBitwarden)
        _ = try section.find(text: Localizations.autofillWithBitwardenDescriptionLong)
        _ = try section.find(button: Localizations.turnOnNow)
        _ = try section.find(button: Localizations.learnMoreAboutAutofill)
        _ = try section.find(button: Localizations.dismiss)
    }

    /// Tapping the dismiss button in the set up autofill action card sends the
    /// `.dismissSetUpUnlockActionCard` effect.
    @MainActor
    func test_setUpUnlockActionCard_visible_tapDismiss_iOS18() async throws {
        processor.state.badgeState = .fixture(autofillSetupProgress: .setUpLater)
        let actionCard = try subject.inspect().find(setupSection: Localizations.autofillWithBitwarden)

        let button = try actionCard.find(button: Localizations.dismiss)
        try button.tap()
        try await waitForAsync { !self.processor.effects.isEmpty }
        XCTAssertEqual(processor.effects, [.dismissSetUpAutofillActionCard])
    }

    /// Tapping the get started button in the set up autofill action card sends the
    /// `.showSetUpUnlock` action.
    @MainActor
    func test_setUpUnlockActionCard_visible_tapGetStarted_iOS18() async throws {
        processor.state.badgeState = .fixture(autofillSetupProgress: .setUpLater)
        let actionCard = try subject.inspect().find(setupSection: Localizations.autofillWithBitwarden)

        let button = try actionCard.find(button: Localizations.turnOnNow)
        try button.tap()
        try await waitForAsync { !self.processor.effects.isEmpty }
        XCTAssertEqual(processor.effects, [.setUpAutofill])
    }
}
