import Foundation
import SwiftUI
import ViewInspector
import XCTest

// swiftlint:disable file_length

/// A generic type wrapper around `ActionCard` to allow `ViewInspector` to find instances of
/// `ActionCard` without needing to know the details of its implementation.
///
public struct ActionCardType: BaseViewType {
    public static var typePrefix: String = "ActionCard"

    public static var namespacedPrefixes: [String] = [
        "BitwardenKit.ActionCard",
    ]
}

/// A generic type wrapper around `AsyncButton` to allow `ViewInspector` to find instances of `AsyncButton` without
/// needing to know the type of its `Label`.
///
public struct AsyncButtonType: BaseViewType {
    public static var typePrefix: String = "AsyncButton"

    public static var namespacedPrefixes: [String] = [
        "BitwardenKit.AsyncButton",
    ]
}

/// A generic type wrapper around `DateFieldPicker` to allow `ViewInspector` to find instances of
/// `DateFieldPicker` without needing to know the details of its implementation.
///
public struct DateFieldPickerType: BaseViewType {
    public static var typePrefix: String = "DateFieldPicker"

    public static var namespacedPrefixes: [String] = [
        "BitwardenKit.DateFieldPicker",
    ]
}

/// A generic type wrapper around `BitwardenSlider` to allow `ViewInspector` to find instances of `BitwardenSlider`
/// without needing to know the details of its implementation.
///
public struct BitwardenSliderType: BaseViewType {
    public static var typePrefix: String = "BitwardenSlider"

    public static var namespacedPrefixes: [String] = [
        "BitwardenKit.BitwardenSlider",
    ]
}

/// A generic type wrapper around `BitwardenStepper` to allow `ViewInspector` to find instances of
/// `BitwardenStepper` without needing to know the details of its implementation.
///
public struct BitwardenStepperType: BaseViewType {
    public static var typePrefix: String = "BitwardenStepper"

    public static var namespacedPrefixes: [String] = [
        "BitwardenKit.BitwardenStepper",
    ]
}

/// A generic type wrapper around `BitwardenTextField` to allow `ViewInspector` to find instances of
/// `BitwardenTextField` without needing to know the details of its implementation.
///
public struct BitwardenTextFieldType: BaseViewType {
    public static var typePrefix: String = "BitwardenTextField"

    public static var namespacedPrefixes: [String] = [
        "BitwardenKit.BitwardenTextField",
    ]
}

/// A generic type wrapper around ` BitwardenMenuFieldType` to allow `ViewInspector` to find instances of
/// ` BitwardenMenuFieldType` without needing to know the details of its implementation.
///
public struct BitwardenMenuFieldType: BaseViewType {
    public static var typePrefix: String = "BitwardenMenuField"

    public static var namespacedPrefixes: [String] = [
        "BitwardenKit.BitwardenMenuField",
    ]
}

/// A generic type wrapper around `BitwardenMultilineTextField` to allow `ViewInspector` to find
/// instances of `BitwardenMultilineTextField` without needing to know the details of its
/// implementation.
///
public struct BitwardenMultilineTextFieldType: BaseViewType {
    public static var typePrefix: String = "BitwardenMultilineTextField"

    public static var namespacedPrefixes: [String] = [
        "AuthenticatorShared.BitwardenMultilineTextField",
    ]
}

/// A generic type wrapper around `BitwardenUITextViewType` to allow `ViewInspector` to find
/// instances of `BitwardenUITextViewType` without needing to know the details of its
/// implementation.
///
public struct BitwardenUITextViewType: BaseViewType {
    public static var typePrefix: String = "BitwardenUITextView"

    public static var namespacedPrefixes: [String] = [
        "BitwardenKit.BitwardenUITextView",
    ]
}

/// Generic type wrappers around the Pass-Y form components (`PassYFormField`, `PassYSecureField`, `PassYPickerRow`,
/// `PassYMultilineField`, `PassYCopyRow`) so tests find them by title without knowing their implementation.
///
public struct PassYFormFieldType: BaseViewType {
    public static var typePrefix: String = "PassYFormField"

    public static var namespacedPrefixes: [String] = ["BitwardenShared.PassYFormField"]
}

/// See `PassYFormFieldType`.
public struct PassYSecureFieldType: BaseViewType {
    public static var typePrefix: String = "PassYSecureField"

    public static var namespacedPrefixes: [String] = ["BitwardenShared.PassYSecureField"]
}

/// See `PassYFormFieldType`.
public struct PassYPickerRowType: BaseViewType {
    public static var typePrefix: String = "PassYPickerRow"

    public static var namespacedPrefixes: [String] = ["BitwardenShared.PassYPickerRow"]
}

/// See `PassYFormFieldType`.
public struct PassYMultilineFieldType: BaseViewType {
    public static var typePrefix: String = "PassYMultilineField"

    public static var namespacedPrefixes: [String] = ["BitwardenShared.PassYMultilineField"]
}

/// See `PassYFormFieldType`.
public struct PassYDateRowType: BaseViewType {
    public static var typePrefix: String = "PassYDateRow"

    public static var namespacedPrefixes: [String] = ["BitwardenShared.PassYDateRow"]
}

/// See `PassYFormFieldType`.
public struct PassYCopyRowType: BaseViewType {
    public static var typePrefix: String = "PassYCopyRow"

    public static var namespacedPrefixes: [String] = ["BitwardenShared.PassYCopyRow"]
}

/// A generic type wrapper around `FloatingActionButton` to allow `ViewInspector` to find instances
/// of `FloatingActionButton` without needing to know the details of its implementation.
///
public struct FloatingActionButtonType: BaseViewType {
    public static var typePrefix: String = "FloatingActionButton"

    public static var namespacedPrefixes: [String] = [
        "BitwardenShared.FloatingActionButton",
    ]
}

/// A generic type wrapper around `LoadingView` to allow `ViewInspector` to find instances of
/// `LoadingView` without needing to know the details of its implementation.
///
public struct LoadingViewType: BaseViewType {
    public static var typePrefix: String = "LoadingView"

    public static var namespacedPrefixes: [String] = [
        "BitwardenShared.LoadingView",
    ]
}

// MARK: InspectableView

public extension InspectableView {
    // MARK: Methods

    /// Attempts to locate an action card with the provided title.
    ///
    /// - Parameters:
    ///   - title: The title to use while searching for a button.
    ///   - locale: The locale for text extraction.
    /// - Returns: An async button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(actionCard title: String) throws -> InspectableView<ActionCardType> {
        try find(ActionCardType.self, containing: title)
    }

    /// Attempts to locate an async button with the provided title.
    ///
    /// - Parameters:
    ///   - title: The title to use while searching for a button.
    ///   - locale: The locale for text extraction.
    /// - Returns: An async button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        asyncButton title: String,
        locale _: Locale = .testsDefault,
    ) throws -> InspectableView<AsyncButtonType> {
        try find(AsyncButtonType.self, containing: title)
    }

    /// Attempts to locate an async button with the provided accessibility label.
    ///
    /// - Parameters:
    ///   - accessibilityLabel: The accessibility label to use while searching for a button.
    ///   - locale: The locale for text extraction.
    /// - Returns: A button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        asyncButtonWithAccessibilityLabel accessibilityLabel: String,
        locale: Locale = .testsDefault,
    ) throws -> InspectableView<AsyncButtonType> {
        try find(AsyncButtonType.self) { view in
            try view.accessibilityLabel().string(locale: locale) == accessibilityLabel
        }
    }

    /// Attempts to locate an async button with the provided accessibility identifier.
    ///
    /// - Parameter accessibilityIdentifier: The accessibility identifier to use while searching for a button.
    /// - Returns: A button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        asyncButtonWithAccessibilityIdentifier accessibilityIdentifier: String,
    ) throws -> InspectableView<AsyncButtonType> {
        try find(AsyncButtonType.self) { view in
            try view.accessibilityIdentifier() == accessibilityIdentifier
        }
    }

    /// Attempts to locate a (plain SwiftUI) button with the provided accessibility identifier, e.g. a Pass-Y row
    /// button (`passYRowButton`).
    ///
    /// - Parameter accessibilityIdentifier: The accessibility identifier to use while searching for a button.
    /// - Returns: A button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        buttonWithAccessibilityIdentifier accessibilityIdentifier: String,
    ) throws -> InspectableView<ViewType.Button> {
        try find(ViewType.Button.self) { view in
            try view.accessibilityIdentifier() == accessibilityIdentifier
        }
    }

    /// Attempts to locate a bitwarden menu field with the provided title.
    ///
    /// - Parameters:
    ///   - title: The title to use while searching for a menu field.
    ///   - locale: The locale for text extraction.
    /// - Returns: A `BitwardenMenuFieldType`, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        bitwardenMenuField title: String,
        locale: Locale = .testsDefault,
    ) throws -> InspectableView<BitwardenMenuFieldType> {
        try find(BitwardenMenuFieldType.self, containing: title, locale: locale)
    }

    /// Attempts to locate a Pass-Y form field (`PassYFormField`) with the provided title.
    func find(passYFormField title: String, locale: Locale = .testsDefault) throws -> InspectableView<PassYFormFieldType> {
        try find(PassYFormFieldType.self) { view in
            let mirror = Mirror(reflecting: view)
            return mirror.descendant("content", "view", "title") as? String == title
        }
    }

    /// Attempts to locate a Pass-Y secure field (`PassYSecureField`) with the provided title.
    func find(passYSecureField title: String, locale: Locale = .testsDefault) throws -> InspectableView<PassYSecureFieldType> {
        try find(PassYSecureFieldType.self) { view in
            let mirror = Mirror(reflecting: view)
            return mirror.descendant("content", "view", "title") as? String == title
        }
    }

    /// Attempts to locate a Pass-Y picker row (`PassYPickerRow`) with the provided title.
    func find(passYPickerRow title: String, locale: Locale = .testsDefault) throws -> InspectableView<PassYPickerRowType> {
        try find(PassYPickerRowType.self) { view in
            let mirror = Mirror(reflecting: view)
            return mirror.descendant("content", "view", "title") as? String == title
        }
    }

    /// Attempts to locate a Pass-Y multi-line field (`PassYMultilineField`) with the provided title.
    func find(passYMultilineField title: String) throws -> InspectableView<PassYMultilineFieldType> {
        try find(PassYMultilineFieldType.self) { view in
            let mirror = Mirror(reflecting: view)
            return mirror.descendant("content", "view", "title") as? String == title
        }
    }

    /// Attempts to locate a Pass-Y date row (`PassYDateRow`) with the provided title.
    func find(passYDateRow title: String) throws -> InspectableView<PassYDateRowType> {
        try find(PassYDateRowType.self) { view in
            let mirror = Mirror(reflecting: view)
            return mirror.descendant("content", "view", "title") as? String == title
        }
    }

    /// Attempts to locate a Pass-Y copy row (`PassYCopyRow`) with the provided title.
    func find(passYCopyRow title: String) throws -> InspectableView<PassYCopyRowType> {
        try find(PassYCopyRowType.self) { view in
            let mirror = Mirror(reflecting: view)
            return mirror.descendant("content", "view", "title") as? String == title
        }
    }

    /// Attempts to locate a bitwarden text field with the provided title.
    ///
    /// - Parameters:
    ///   - title: The title to use while searching for a text field.
    ///   - locale: The locale for text extraction.
    /// - Returns: A `BitwardenTextFieldType`, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        bitwardenTextField title: String,
        locale: Locale = .testsDefault,
    ) throws -> InspectableView<BitwardenTextFieldType> {
        try find(BitwardenTextFieldType.self, containing: title, locale: locale)
    }

    /// Attempts to locate a date field picker with the provided title.
    ///
    /// - Parameters:
    ///   - title: The title to use while searching for a date field picker.
    ///   - locale: The locale for text extraction.
    /// - Returns: A `DateFieldPickerType`, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        dateFieldPicker title: String,
        locale: Locale = .testsDefault,
    ) throws -> InspectableView<DateFieldPickerType> {
        try find(DateFieldPickerType.self, containing: title, locale: locale)
    }

    /// Attempts to locate an floating action button with the provided accessibility identifier.
    ///
    /// - Parameter accessibilityIdentifier: The accessibility identifier to use while searching for
    ///     a floating action button.
    /// - Returns: A floating action button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        floatingActionButtonWithAccessibilityIdentifier accessibilityIdentifier: String,
    ) throws -> InspectableView<FloatingActionButtonType> {
        try find(FloatingActionButtonType.self) { view in
            try view.accessibilityIdentifier() == accessibilityIdentifier
        }
    }

    /// Attempts to locate a generic view with the provided accessibility label.
    ///
    /// - Parameters:
    ///   - type: The type of the view to locate.
    ///   - accessibilityLabel: The accessibility label to use while searching for the text field.
    ///   - locale: The locale for text extraction.
    /// - Returns: An `InspectableView` of the specified type, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find<T>(
        type: T.Type,
        accessibilityLabel: String,
        locale: Locale = .testsDefault,
    ) throws -> InspectableView<T> {
        try find(T.self) { view in
            try view.accessibilityLabel().string(locale: locale) == accessibilityLabel
        }
    }

    /// Attempts to locate a button with the provided id.
    ///
    /// - Parameter id: The id to use while searching for a button.
    /// - Returns: A button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(buttonWithId id: AnyHashable) throws -> InspectableView<ViewType.Button> {
        try find(ViewType.Button.self) { view in
            try view.id() == id
        }
    }

    /// Attempts to locate a button with the provided accessibility label.
    ///
    /// - Parameter accessibilityLabel: The accessibility label to use while searching for a button.
    /// - Returns: A button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        buttonWithAccessibilityLabel accessibilityLabel: String,
        locale: Locale = .testsDefault,
    ) throws -> InspectableView<ViewType.Button> {
        try find(ViewType.Button.self) { view in
            try view.accessibilityLabel().string(locale: locale) == accessibilityLabel
        }
    }

    /// Attempts to locate a picker with the provided label.
    ///
    /// - Parameter label: The label to use while searching for a picker.
    /// - Returns: A picker, if one can be located.
    /// - Throws: Throws an error if a picker was unable to be located.
    ///
    func find(
        picker label: String,
    ) throws -> InspectableView<ViewType.Picker> {
        try find(ViewType.Picker.self, containing: label)
    }

    /// Attempts to locate a text field with the provided label.
    ///
    /// - Parameter label: The label to use while searching for a text field.
    /// - Returns: A text field, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(textField label: String) throws -> InspectableView<ViewType.TextField> {
        try find(ViewType.TextField.self, containing: label)
    }

    /// Attempts to locate a secure field with the provided label.
    ///
    /// - Parameter label: The label to use while searching for a secure field.
    /// - Returns: A secure field, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(secureField label: String) throws -> InspectableView<ViewType.SecureField> {
        try find(ViewType.SecureField.self, containing: label)
    }

    /// Attempts to locate a slider with the provided accessibility label.
    ///
    /// - Parameter accessibilityLabel: The accessibility label to use while searching for a slider.
    /// - Returns: A slider, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        sliderWithAccessibilityLabel accessibilityLabel: String,
        locale: Locale = .testsDefault,
    ) throws -> InspectableView<BitwardenSliderType> {
        try find(BitwardenSliderType.self) { view in
            try view.accessibilityLabel().string(locale: locale) == accessibilityLabel
        }
    }

    /// Attempts to locate a toggle with the provided accessibility label.
    ///
    /// - Parameter accessibilityLabel: The accessibility label to use while searching for a toggle.
    /// - Returns: A toggle, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func find(
        toggleWithAccessibilityLabel accessibilityLabel: String,
        locale: Locale = .testsDefault,
    ) throws -> InspectableView<ViewType.Toggle> {
        try find(ViewType.Toggle.self) { view in
            try view.accessibilityLabel().string(locale: locale) == accessibilityLabel
        }
    }

    // MARK: Toolbar

    /// Attempts to locate the toolbar cancel default button.
    ///
    /// - Returns: A cancel toolbar button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func findCancelToolbarButton() throws -> InspectableView<ViewType.Button> {
        try find(ViewType.Button.self) { view in
            try view.accessibilityIdentifier() == "CancelButton"
        }
    }

    /// Attempts to locate the toolbar close default button.
    ///
    /// - Returns: A close toolbar button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func findCloseToolbarButton() throws -> InspectableView<ViewType.Button> {
        try find(ViewType.Button.self) { view in
            try view.accessibilityIdentifier() == "CloseButton"
        }
    }

    /// Attempts to locate the toolbar save default button.
    ///
    /// - Returns: A save toolbar button, if one can be located.
    /// - Throws: Throws an error if a view was unable to be located.
    ///
    func findSaveToolbarButton() throws -> InspectableView<AsyncButtonType> {
        try find(asyncButtonWithAccessibilityIdentifier: "SaveButton")
    }
}

public extension InspectableView where View == AsyncButtonType {
    /// Simulates a tap on an `AsyncButton`. This method is asynchronous and allows the entire `async` `action` on the
    /// button to run before returning.
    ///
    func tap() async throws {
        typealias Callback = () async -> Void
        let mirror = Mirror(reflecting: self)
        if let action = mirror.descendant("content", "view", "action") as? Callback {
            await action()
        } else {
            throw InspectionError.attributeNotFound(
                label: "action",
                type: String(describing: AsyncButtonType.self),
            )
        }
    }
}

public extension InspectableView where View == BitwardenTextFieldType {
    /// Locates the raw binding on this textfield's text value. Can be used to simulate updating the text field.
    ///
    func inputBinding() throws -> Binding<String> {
        let mirror = Mirror(reflecting: self)
        if let binding = mirror.descendant("content", "view", "_text") as? Binding<String> {
            return binding
        } else {
            throw InspectionError.attributeNotFound(
                label: "_text",
                type: String(describing: BitwardenTextFieldType.self),
            )
        }
    }
}

public extension InspectableView where View == BitwardenMultilineTextFieldType {
    /// Locates the raw binding on this textfield's text value. Can be used to simulate updating the text field.
    ///
    func inputBinding() throws -> Binding<String> {
        let mirror = Mirror(reflecting: self)
        if let binding = mirror.descendant("content", "view", "_text") as? Binding<String> {
            return binding
        } else {
            throw InspectionError.attributeNotFound(
                label: "_text",
                type: String(describing: BitwardenMultilineTextFieldType.self),
            )
        }
    }
}

public extension InspectableView where View == BitwardenSliderType {
    /// Simulates a drag gesture on the slider to set a new value.
    ///
    func setValue(_ value: Double) throws {
        let mirror = Mirror(reflecting: self)
        if let valueBinding = mirror.descendant("content", "view", "_value") as? Binding<Double>,
           let range = mirror.descendant("content", "view", "range") as? ClosedRange<Double>,
           let step = mirror.descendant("content", "view", "step") as? Double {
            // Calculate the new value based on the fraction
            let newValue = (range.upperBound - range.lowerBound + step) * value + range.lowerBound

            // Set the new value
            valueBinding.wrappedValue = newValue
        } else {
            throw InspectionError.attributeNotFound(
                label: "_value",
                type: String(describing: BitwardenSliderType.self),
            )
        }
    }
}

public extension InspectableView where View == BitwardenUITextViewType {
    /// Locates the raw binding on this textfield's text value. Can be used to simulate updating the text field.
    ///
    func inputBinding() throws -> Binding<String> {
        let mirror = Mirror(reflecting: self)
        if let binding = mirror.descendant("content", "view", "_text") as? Binding<String> {
            return binding
        } else {
            throw InspectionError.attributeNotFound(
                label: "_text",
                type: String(describing: BitwardenUITextViewType.self),
            )
        }
    }
}

/// The raw text binding of a Pass-Y text component, to simulate typing.
private func passYTextBinding<T>(_ view: InspectableView<T>, type: String) throws -> Binding<String> {
    let mirror = Mirror(reflecting: view)
    if let binding = mirror.descendant("content", "view", "_text") as? Binding<String> {
        return binding
    }
    throw InspectionError.attributeNotFound(label: "_text", type: type)
}

public extension InspectableView where View == PassYFormFieldType {
    /// Locates the raw binding on this field's text value. Can be used to simulate updating the field.
    func inputBinding() throws -> Binding<String> {
        try passYTextBinding(self, type: "PassYFormField")
    }
}

public extension InspectableView where View == PassYSecureFieldType {
    /// Locates the raw binding on this field's text value. Can be used to simulate updating the field.
    func inputBinding() throws -> Binding<String> {
        try passYTextBinding(self, type: "PassYSecureField")
    }
}

public extension InspectableView where View == PassYMultilineFieldType {
    /// Locates the raw binding on this field's text value. Can be used to simulate updating the field.
    func inputBinding() throws -> Binding<String> {
        try passYTextBinding(self, type: "PassYMultilineField")
    }
}

public extension InspectableView where View == PassYDateRowType {
    /// Locates the raw binding on this row's date. Can be used to simulate picking a date.
    func inputBinding() throws -> Binding<Date?> {
        let mirror = Mirror(reflecting: self)
        if let binding = mirror.descendant("content", "view", "_date") as? Binding<Date?> {
            return binding
        }
        throw InspectionError.attributeNotFound(label: "_date", type: "PassYDateRow")
    }
}

public extension InspectableView where View == PassYPickerRowType {
    /// Selects a new value in the picker row.
    func select(newValue: any Hashable) throws {
        try find(ViewType.Picker.self).select(value: newValue)
    }
}

public extension InspectableView where View == BitwardenMenuFieldType {
    /// Selects a new value in the menu field.
    ///
    func select(newValue: any Hashable) throws {
        let picker = try find(ViewType.Picker.self)
        try picker.select(value: newValue)
    }
}

public extension InspectableView where View == BitwardenStepperType {
    /// Decrements the stepper.
    ///
    func decrement() throws {
        let button = try find(buttonWithId: "decrement")
        try button.tap()
    }

    /// Increments the stepper.
    ///
    func increment() throws {
        let button = try find(buttonWithId: "increment")
        try button.tap()
    }
}

public extension InspectableView where View == DateFieldPickerType {
    /// Locates the raw binding on this field's date value. Can be used to simulate selecting a date.
    ///
    func inputBinding() throws -> Binding<Date?> {
        let mirror = Mirror(reflecting: self)
        if let binding = mirror.descendant("content", "view", "_date") as? Binding<Date?> {
            return binding
        } else {
            throw InspectionError.attributeNotFound(
                label: "_date",
                type: String(describing: DateFieldPickerType.self),
            )
        }
    }
}

public extension InspectableView where View == FloatingActionButtonType {
    /// Simulates a tap on an `AsyncButton` within a `FloatingActionButton`. This method is
    /// asynchronous and allows the entire `async` `action` on the button to run before returning.
    ///
    @MainActor
    func tap() async throws {
        let button = try find(AsyncButtonType.self)
        try await button.tap()
    }
}
