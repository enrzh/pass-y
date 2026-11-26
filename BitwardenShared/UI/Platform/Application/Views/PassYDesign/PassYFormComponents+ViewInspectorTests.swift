// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenResources
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

// MARK: - PassYTextBufferTests

/// The local text buffer of the Pass-Y fields: echoes of sent values are dropped, outside changes replace the text.
class PassYTextBufferTests: BitwardenTestCase {
    /// Typing sends the value once; typing the same value again sends nothing.
    func test_userChanged_sendsOnlyChanges() {
        var buffer = PassYTextBuffer("")
        XCTAssertTrue(buffer.userChanged(to: "a"))
        XCTAssertFalse(buffer.userChanged(to: "a"))
        XCTAssertEqual(buffer.text, "a")
    }

    /// An echo arriving after newer typing does not reset the field; a real outside change replaces it.
    func test_storeChanged_dropsEchoesAndAppliesOutsideChanges() {
        var buffer = PassYTextBuffer("")
        _ = buffer.userChanged(to: "a")
        _ = buffer.userChanged(to: "ab")
        buffer.storeChanged(to: "a") // late echo of "a"
        XCTAssertEqual(buffer.text, "ab")
        buffer.storeChanged(to: "ab") // echo of "ab"
        XCTAssertEqual(buffer.text, "ab")
        buffer.storeChanged(to: "generated") // e.g. a generated password
        XCTAssertEqual(buffer.text, "generated")
    }

    /// A value typed twice (e.g. "a", "ab", "a") needs two echoes before an outside "a" counts again.
    func test_storeChanged_countsRepeatedValues() {
        var buffer = PassYTextBuffer("x")
        _ = buffer.userChanged(to: "a")
        _ = buffer.userChanged(to: "ab")
        _ = buffer.userChanged(to: "a")
        buffer.storeChanged(to: "a")
        buffer.storeChanged(to: "ab")
        XCTAssertEqual(buffer.text, "a")
        buffer.storeChanged(to: "a")
        XCTAssertEqual(buffer.text, "a")
    }
}

// MARK: - PassYFieldOrderTests

/// Previous/next field order of the keyboard navigation.
class PassYFieldOrderTests: BitwardenTestCase {
    func test_previousAndNext() {
        let order = PassYFieldOrder(fields: [1, 2, 3])
        XCTAssertEqual(order.next(1), 2)
        XCTAssertNil(order.next(3))
        XCTAssertEqual(order.previous(2), 1)
        XCTAssertNil(order.previous(1))
        XCTAssertNil(order.next(nil))
        XCTAssertNil(order.previous(9))
    }
}

// MARK: - PassYFormComponentsViewInspectorTests

/// The Pass-Y form components: identifiers, bindings, reveal, copy and menu actions.
class PassYFormComponentsViewInspectorTests: BitwardenTestCase {
    /// A form field writes typed text to its binding and carries its identifier on the native field.
    @MainActor
    func test_formField_bindingAndIdentifier() throws {
        var value = ""
        let binding = Binding(get: { value }, set: { value = $0 })
        let subject = PassYFormField("Username", text: binding, identifier: "LoginUsernameEntry")
        XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "LoginUsernameEntry"))
        try subject.inspect().find(ViewType.TextField.self).setInput("octo")
        XCTAssertEqual(value, "octo")
        XCTAssertNoThrow(try subject.inspect().find(text: "Username"), "inline label")
    }

    /// A free field has no label column.
    @MainActor
    func test_formField_free_hasNoLabel() throws {
        let free = PassYFormField("Item name (required)", text: .constant(""), style: .free)
        let inline = PassYFormField("Item name (required)", text: .constant(""))
        XCTAssertEqual(
            try free.inspect().findAll(ViewType.Text.self).count + 1,
            try inline.inspect().findAll(ViewType.Text.self).count,
            "the free field has no label text",
        )
    }

    /// A masked secure field is a `SecureField`; the eye button reveals it as a `TextField` with the same identifier.
    @MainActor
    func test_secureField_revealSwapsField() throws {
        var revealed = false
        let isRevealed = Binding(get: { revealed }, set: { revealed = $0 })
        let masked = PassYSecureField(
            "Password",
            text: .constant("secret"),
            isRevealed: isRevealed,
            identifier: "LoginPasswordEntry",
            revealIdentifier: "ViewPasswordButton",
        )
        XCTAssertNoThrow(try masked.inspect().find(ViewType.SecureField.self))
        XCTAssertNoThrow(try masked.inspect().find(viewWithAccessibilityIdentifier: "LoginPasswordEntry"))
        XCTAssertThrowsError(try masked.inspect().find(ViewType.TextField.self))
        try masked.inspect().find(buttonWithAccessibilityLabel: Localizations.passwordIsNotVisibleTapToShow).tap()
        XCTAssertTrue(revealed)

        let shown = PassYSecureField(
            "Password",
            text: .constant("secret"),
            isRevealed: .constant(true),
            identifier: "LoginPasswordEntry",
        )
        XCTAssertNoThrow(try shown.inspect().find(ViewType.TextField.self))
        XCTAssertNoThrow(try shown.inspect().find(viewWithAccessibilityIdentifier: "LoginPasswordEntry"))
        XCTAssertNoThrow(try shown.inspect().find(buttonWithAccessibilityLabel: Localizations.passwordIsVisibleTapToHide))
    }

    /// A secret that may not be revealed has no eye button.
    @MainActor
    func test_secureField_cannotReveal_noEyeButton() throws {
        let subject = PassYSecureField("Password", text: .constant("secret"), canReveal: false)
        XCTAssertThrowsError(try subject.inspect().find(buttonWithAccessibilityLabel: Localizations.passwordIsNotVisibleTapToShow))
    }

    /// A copy row shows the value, masks a hidden secret and offers Copy and Reveal in its menu.
    @MainActor
    func test_copyRow_valueMaskAndMenu() throws {
        var copied = 0
        var toggled = 0
        let plain = PassYCopyRow("Username", value: "octo", identifier: "LoginUsernameEntry") { copied += 1 }
        XCTAssertNoThrow(try plain.inspect().find(text: "octo"))
        try plain.inspect().tapPassYCopyRow(valueIdentifier: "LoginUsernameEntry")
        XCTAssertEqual(copied, 1)

        let secret = PassYCopyRow(
            "Password",
            value: "Sup3r",
            secret: .init(isRevealed: false, revealIdentifier: "ShowLoginPasswordButton") { toggled += 1 },
            identifier: "LoginPasswordEntry",
        ) { copied += 1 }
        XCTAssertNoThrow(try secret.inspect().find(text: PassYValueText.mask))
        XCTAssertThrowsError(try secret.inspect().find(text: "Sup3r"), "hidden secret is masked")
        try secret.inspect().find(buttonWithAccessibilityIdentifier: "ShowLoginPasswordButton").tap()
        XCTAssertEqual(toggled, 1)
        try secret.inspect().tapPassYCopyRow(valueIdentifier: "LoginPasswordEntry")
        XCTAssertEqual(copied, 2)
    }

    /// A value that cannot be copied does nothing on tap and has no copy hint.
    @MainActor
    func test_copyRow_notCopyable_noCopyAction() throws {
        let subject = PassYCopyRow("Passkey", value: "Created today", identifier: "Passkey", copy: nil)
        XCTAssertNoThrow(try subject.inspect().tapPassYCopyRow(valueIdentifier: "Passkey"))
        XCTAssertEqual(try subject.inspect().find(viewWithAccessibilityIdentifier: "Passkey").accessibilityHint().string(), "")
    }

    /// A secret the user may not reveal has no eye button.
    @MainActor
    func test_copyRow_cannotReveal_noEyeButton() throws {
        let subject = PassYCopyRow(
            "Key",
            value: "secret",
            secret: .init(isRevealed: false, revealIdentifier: "Eye", canReveal: false) {},
            copy: nil,
        )
        XCTAssertThrowsError(try subject.inspect().find(buttonWithAccessibilityIdentifier: "Eye"))
        XCTAssertNoThrow(try subject.inspect().find(text: PassYValueText.mask))
    }

    /// The eye button reads the field name when one is given.
    @MainActor
    func test_revealButton_spokenName() {
        XCTAssertEqual(
            PassYRevealButton(isRevealed: false, fieldName: "PIN") {}.label,
            Localizations.fieldValueIsNotVisibleTapToShow("PIN"),
        )
        XCTAssertEqual(PassYRevealButton(isRevealed: true) {}.label, Localizations.passwordIsVisibleTapToHide)
    }

    /// The code expiry reports a later period only.
    func test_codeExpiry_isExpired() {
        let generated = Date(timeIntervalSince1970: 30 * 1000 + 5)
        XCTAssertFalse(PassYCodeExpiry.isExpired(generatedAt: generated, now: generated.addingTimeInterval(20), period: 30))
        XCTAssertTrue(PassYCodeExpiry.isExpired(generatedAt: generated, now: generated.addingTimeInterval(25), period: 30))
    }

    /// The readable width adds side insets only on wide pages.
    func test_readableWidth_margin() {
        XCTAssertNil(PassYReadableWidthModifier.margin(forWidth: 390, maxWidth: 680))
        XCTAssertNil(PassYReadableWidthModifier.margin(forWidth: 744, maxWidth: 680))
        XCTAssertEqual(PassYReadableWidthModifier.margin(forWidth: 1180, maxWidth: 680), 250)
    }

    /// Revealed secrets tint digits and symbols, letters keep the default colour.
    func test_valueText_tinted() {
        let tinted = PassYValueText.tinted("a1!")
        let colors = tinted.runs.map(\.foregroundColor)
        XCTAssertEqual(colors, [nil, .blue, .orange])
        XCTAssertEqual(String(tinted.characters).replacingOccurrences(of: "\u{200B}", with: ""), "a1!")
    }

    /// A picker row selects through its inline picker and runs extra actions.
    @MainActor
    func test_pickerRow_selectAndActions() throws {
        var selection = UriMatchType.domain
        var added = false
        let subject = PassYPickerRow(
            "Match",
            options: UriMatchType.allCases,
            selection: Binding(get: { selection }, set: { selection = $0 }),
            identifier: "FolderPicker",
        ) {
            Button("Add folder") { added = true }
        }
        XCTAssertEqual(try subject.inspect().find(ViewType.Menu.self).accessibilityIdentifier(), "FolderPicker")
        try subject.inspect().find(ViewType.Picker.self).select(value: UriMatchType.exact)
        XCTAssertEqual(selection, .exact)
        try subject.inspect().find(button: "Add folder").tap()
        XCTAssertTrue(added)
    }

    /// A toggle row writes its binding and carries the identifier and label.
    @MainActor
    func test_toggleRow() throws {
        var isOn = false
        let subject = PassYToggleRow(
            "Re-prompt",
            isOn: Binding(get: { isOn }, set: { isOn = $0 }),
            identifier: "MasterPasswordRepromptToggle",
            accessibilityLabel: "Password prompt",
        )
        let toggle = try subject.inspect().find(toggleWithAccessibilityLabel: "Password prompt")
        XCTAssertEqual(try toggle.accessibilityIdentifier(), "MasterPasswordRepromptToggle")
        try toggle.tap()
        XCTAssertTrue(isOn)
    }

    /// An inline button row runs a synchronous action at once.
    @MainActor
    func test_inlineButtonRow_syncAction() throws {
        var tapped = false
        let subject = PassYInlineButtonRow("New URI", systemImage: "plus", identifier: "AddUri") { tapped = true }
        let button = try subject.inspect().find(ViewType.Button.self)
        XCTAssertEqual(try button.accessibilityIdentifier(), "AddUri")
        try button.tap()
        XCTAssertTrue(tapped)
    }

    /// An inline button row awaits an asynchronous action.
    @MainActor
    func test_inlineButtonRow_asyncAction() async {
        var ran = false
        let subject = PassYInlineButtonRow("Check") { () async in ran = true }
        await subject.perform()
        XCTAssertTrue(ran)
    }

    /// The disclosure row toggles its options.
    @MainActor
    func test_disclosureSection_toggles() throws {
        var expanded = false
        let subject = PassYDisclosureSection(
            "Additional options",
            isExpanded: Binding(get: { expanded }, set: { expanded = $0 }),
        ) {
            Section { Text("Notes") }
        }
        XCTAssertThrowsError(try subject.inspect().find(text: "Notes"), "collapsed")
        try subject.inspect().find(buttonWithAccessibilityIdentifier: "ExpandSectionButton").tap()
        XCTAssertTrue(expanded)
    }

    /// The stepper row shows the word for the lowest value and the number otherwise.
    @MainActor
    func test_stepperRow_valueText() {
        XCTAssertEqual(PassYStepperRow("Count", value: .constant(0), in: 0 ... 9, lowestValueText: "None").valueText, "None")
        XCTAssertEqual(PassYStepperRow("Count", value: .constant(3), in: 0 ... 9, lowestValueText: "None").valueText, "3")
    }

    /// The multiline field writes its binding.
    @MainActor
    func test_multilineField_binding() throws {
        var notes = ""
        let subject = PassYMultilineField("Notes", text: Binding(get: { notes }, set: { notes = $0 }), identifier: "Notes")
        let editor = try subject.inspect().find(ViewType.TextEditor.self)
        XCTAssertEqual(try editor.accessibilityIdentifier(), "Notes")
        try editor.setInput("hello")
        XCTAssertEqual(notes, "hello")
    }
}

// MARK: - InspectableView + Pass-Y rows

extension InspectableView {
    /// Taps a `PassYCopyRow` (copies its value): finds its value by identifier and calls the row's tap gesture
    /// (ViewInspector cannot open context menus).
    @MainActor
    func tapPassYCopyRow(valueIdentifier: String) throws {
        try passYCallTapGesture(find(viewWithAccessibilityIdentifier: valueIdentifier), levels: 6)
    }

    /// Finds a `PassYInlineButtonRow` by its title; `await row.perform()` taps it (also for async actions).
    @MainActor
    func find(passYInlineButtonRow title: String) throws -> PassYInlineButtonRow {
        try find(ViewType.View<PassYInlineButtonRow>.self) { view in
            try view.actualView().title == title
        }
        .actualView()
    }
}

/// Calls the nearest tap gesture at or above `view`, at most `levels` parents up.
@MainActor
private func passYCallTapGesture<T>(_ view: InspectableView<T>, levels: Int) throws {
    if (try? view.callOnTapGesture()) != nil { return }
    guard levels > 0 else { throw InspectionError.notSupported("No tap gesture above the value") }
    try passYCallTapGesture(view.parent(), levels: levels - 1)
}
