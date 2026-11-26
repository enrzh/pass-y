// swiftlint:disable:this file_name
import BitwardenKit
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

// MARK: - PassYSettingsComponentsTests

/// Tests of the settings and auth components of PassYDesign (`PassYSettingsRow`, `PassYToggleRow`, `PassYValueRow`,
/// `PassYFooterText`, `PassYHeroHeader`, `PassYPasswordField`, `PassYSetupSection`).
class PassYSettingsComponentsTests: BitwardenTestCase {
    /// The actions run by the setup section rows.
    var performed: [String] = []

    // MARK: PassYSettingsRow

    /// A settings row is one button with its title, value and badge; a tap runs the action.
    @MainActor
    func test_settingsRow_tapAndContent() throws {
        var taps = 0
        let subject = PassYSettingsRow("Account security", systemImage: "lock.fill", value: "On", badge: "2") {
            taps += 1
        }
        let button = try subject.inspect().find(button: "Account security")
        XCTAssertNoThrow(try button.find(text: "On"))
        XCTAssertNoThrow(try button.find(text: "2"))
        XCTAssertNoThrow(try button.find(PassYDisclosureChevron.self))
        try button.tap()
        XCTAssertEqual(taps, 1)
    }

    /// A destructive row has the destructive role and a red tile; rows without an accessory have no chevron.
    @MainActor
    func test_settingsRow_destructive() throws {
        let subject = PassYSettingsRow("Log out", systemImage: "rectangle.portrait", role: .destructive,
                                       accessory: .none) {}
        XCTAssertEqual(subject.tint, .red)
        XCTAssertEqual(subject.role, .destructive)
        XCTAssertThrowsError(try subject.inspect().find(PassYDisclosureChevron.self))
    }

    /// The row identifier is on the button.
    @MainActor
    func test_settingsRow_identifier() throws {
        let subject = PassYSettingsRow("Vault", identifier: "VaultSettingsButton") {}
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "VaultSettingsButton").button())
    }

    // MARK: PassYToggleRow

    /// The toggle row writes its binding and carries the identifier and the title.
    @MainActor
    func test_toggleRow_binding() throws {
        var isOn = false
        let binding = Binding(get: { isOn }, set: { isOn = $0 })
        let subject = PassYToggleRow("Unlock with PIN", subtitle: "Use a PIN", systemImage: "lock", isOn: binding,
                                     identifier: "UnlockWithPinSwitch")
        let toggle = try subject.inspect().find(ViewType.Toggle.self)
        XCTAssertEqual(try toggle.accessibilityIdentifier(), "UnlockWithPinSwitch")
        XCTAssertNoThrow(try toggle.find(text: "Use a PIN"))
        try toggle.tap()
        XCTAssertTrue(isOn)
    }

    // MARK: PassYValueRow

    /// The value row shows its title and value.
    @MainActor
    func test_valueRow_content() throws {
        let subject = PassYValueRow("Version", value: "1.0 (1)")
        XCTAssertNoThrow(try subject.inspect().find(text: "Version"))
        XCTAssertNoThrow(try subject.inspect().find(text: "1.0 (1)"))
    }

    // MARK: PassYFooterText

    /// The footer shows its text; the link button runs its action; without an action there is no button.
    @MainActor
    func test_footerText_link() throws {
        var taps = 0
        let subject = PassYFooterText("Explanation", link: "Learn more") { taps += 1 }
        XCTAssertNoThrow(try subject.inspect().find(text: "Explanation"))
        try subject.inspect().find(button: "Learn more").tap()
        XCTAssertEqual(taps, 1)
        XCTAssertThrowsError(try PassYFooterText("Only text").inspect().find(ViewType.Button.self))
    }

    // MARK: PassYHeroHeader

    /// The header shows its title and message; the shield mark is drawn by default.
    @MainActor
    func test_heroHeader_content() throws {
        let subject = PassYHeroHeader(title: "Log in", message: "Welcome back")
        XCTAssertNoThrow(try subject.inspect().find(text: "Log in"))
        XCTAssertNoThrow(try subject.inspect().find(text: "Welcome back"))
        XCTAssertNoThrow(try subject.inspect().find(PassYShieldMark.self))
        XCTAssertThrowsError(try PassYHeroHeader(mark: .none, title: "T").inspect().find(PassYShieldMark.self))
    }

    /// The shield path stays inside the 1024 grid and the Y lies inside the shield.
    func test_shieldMark_geometry() {
        let bounds = PassYShieldMark.shieldPath(scale: 0.93).boundingRect
        XCTAssertTrue(CGRect(x: 0, y: 0, width: 1024, height: 1024).contains(bounds))
        XCTAssertTrue(bounds.contains(PassYShieldMark.yPath.boundingRect))
    }

    // MARK: PassYPasswordField

    /// Hidden: a secure field; revealed: a text field. The eye button asks for the opposite state.
    @MainActor
    func test_secureField_reveal() throws {
        var requested: Bool?
        let hidden = PassYPasswordField("Password", text: .constant("x"), isRevealed: false,
                                      fieldIdentifier: "Field") { requested = $0 }
        XCTAssertNoThrow(try hidden.inspect().find(ViewType.SecureField.self))
        XCTAssertThrowsError(try hidden.inspect().find(ViewType.TextField.self))
        try hidden.inspect().find(viewWithAccessibilityIdentifier: "PasswordVisibilityToggle").button().tap()
        XCTAssertEqual(requested, true)

        let revealed = PassYPasswordField("Password", text: .constant("x"), isRevealed: true) { requested = $0 }
        XCTAssertNoThrow(try revealed.inspect().find(ViewType.TextField.self))
        try revealed.inspect().find(viewWithAccessibilityIdentifier: "PasswordVisibilityToggle").button().tap()
        XCTAssertEqual(requested, false)
    }

    // MARK: PassYSetupSection

    /// The setup section is a native `Section`; its rows run their async actions.
    @MainActor
    func test_setupSection_rows() async throws {
        performed = []
        let subject = PassYSetupSection(
            title: "Headline",
            message: "Message",
            action: .init(title: "Turn on") { self.performed.append("action") },
            secondary: .init(title: "Learn more") { self.performed.append("secondary") },
            dismiss: .init(title: "Dismiss") { self.performed.append("dismiss") },
        )
        XCTAssertNoThrow(try subject.inspect().find(ViewType.Section.self))
        XCTAssertNoThrow(try subject.inspect().find(text: "Message"))
        try subject.inspect().find(button: "Turn on").tap()
        try subject.inspect().find(button: "Learn more").tap()
        try subject.inspect().find(button: "Dismiss").tap()
        try await waitForAsync { self.performed.count == 3 }
        XCTAssertEqual(Set(performed), ["action", "secondary", "dismiss"])
    }

    /// Without secondary and dismiss rows only the action row exists.
    @MainActor
    func test_setupSection_optionalRowsHidden() throws {
        let subject = PassYSetupSection(title: "Headline", action: .init(title: "Get started") {})
        XCTAssertNoThrow(try subject.inspect().find(button: "Get started"))
        XCTAssertThrowsError(try subject.inspect().find(button: "Dismiss"))
    }
}

// MARK: - InspectableView + PassYSetupSection

extension InspectableView {
    /// Finds the `Section` of a `PassYSetupSection` by its headline.
    func find(setupSection title: String) throws -> InspectableView<ViewType.Section> {
        try find(ViewType.Section.self) { section in
            (try? section.find(text: title)) != nil
        }
    }
}
