import BitwardenResources
import SwiftUI

// MARK: - NativeForm environment

private struct IsNativeFormKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether the shared field components are rendered as rows of a native `Form`/`List`
    /// (no own card, background or rounded corners; sections become real `Section`s).
    var isNativeForm: Bool {
        get { self[IsNativeFormKey.self] }
        set { self[IsNativeFormKey.self] = newValue }
    }
}

private struct IsReadOnlyFieldStyleKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether native-form fields are shown in Apple's read-only (view) state: black label, grey value.
    /// In edit forms it stays false (grey label, black value).
    var isReadOnlyFieldStyle: Bool {
        get { self[IsReadOnlyFieldStyleKey.self] }
        set { self[IsReadOnlyFieldStyleKey.self] = newValue }
    }
}

private struct IsTitlePlaceholderKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether a native-form text field shows its title as the placeholder of a free, left-aligned field (Apple's
    /// name field) instead of as a label on the left (ui-r7).
    var isTitlePlaceholder: Bool {
        get { self[IsTitlePlaceholderKey.self] }
        set { self[IsTitlePlaceholderKey.self] = newValue }
    }
}

public extension View {
    /// The title of the text field becomes its placeholder; no label on the left (native forms only).
    func nativeTitleAsPlaceholder() -> some View {
        environment(\.isTitlePlaceholder, true)
    }

    /// Shows `BitwardenField` rows with a primary label and a secondary value (Apple Passwords view state).
    func readOnlyFieldStyle() -> some View {
        environment(\.isReadOnlyFieldStyle, true)
    }

    /// Marks the view hierarchy (a `Form` or `List`) as native: shared field components render as plain rows.
    func nativeFormRows() -> some View {
        environment(\.isNativeForm, true)
    }

    /// Applies the field card (leading padding, background, rounded corners) outside of a native form;
    /// inside a native form the row gets zero insets and keeps the system row background.
    func fieldCard(isEnabled: Bool = true, leadingPadding: CGFloat = 0) -> some View {
        modifier(FieldCardModifier(isEnabled: isEnabled, leadingPadding: leadingPadding))
    }
}

private struct FieldCardModifier: ViewModifier {
    @Environment(\.isNativeForm) private var isNativeForm

    let isEnabled: Bool
    let leadingPadding: CGFloat

    func body(content: Content) -> some View {
        if isNativeForm {
            content
                .padding(.leading, leadingPadding)
                .listRowInsets(EdgeInsets())
        } else {
            content
                .padding(.leading, leadingPadding)
                .background(
                    isEnabled
                        ? SharedAsset.Colors.backgroundSecondary.swiftUIColor
                        : SharedAsset.Colors.backgroundSecondaryDisabled.swiftUIColor,
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

public extension View {
    /// Inside a native form, removes the row insets (the content pads itself); no-op elsewhere.
    func nativeRowInsetsZero() -> some View {
        modifier(NativeRowInsetsModifier())
    }
}

private struct NativeRowInsetsModifier: ViewModifier {
    @Environment(\.isNativeForm) private var isNativeForm

    func body(content: Content) -> some View {
        if isNativeForm {
            content.listRowInsets(EdgeInsets())
        } else {
            content
        }
    }
}

// MARK: - Item data entry

private struct IsItemDataEntryKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether the text fields belong to a vault item editor: their masked values (password, authenticator key, card
    /// code, hidden fields) are vault data, not credentials for this app.
    var isItemDataEntry: Bool {
        get { self[IsItemDataEntryKey.self] }
        set { self[IsItemDataEntryKey.self] = newValue }
    }
}

public extension View {
    /// Marks the view hierarchy as a vault item editor (see `isItemDataEntry`).
    func itemDataEntryFields() -> some View {
        environment(\.isItemDataEntry, true)
    }

    /// In a vault item editor, takes a masked field out of iOS password AutoFill (`.oneTimeCode`); elsewhere no-op, so
    /// the content type set by the caller (e.g. `.password` on the login and master password screens) stays.
    func itemDataEntryContentType() -> some View {
        modifier(ItemDataEntryContentTypeModifier())
    }
}

/// With two or more masked fields that iOS treats as password fields (a secure field without a content type counts as
/// one) in the item editor, synthesized keyboard input kept only the last character of the field (1 of 21 in the
/// password, 1 of 16 in the authenticator key; every key also changed the other masked field), consistent with iOS
/// password AutoFill handling the form as a sign-up/password-change form. Software keyboard taps were not affected.
private struct ItemDataEntryContentTypeModifier: ViewModifier {
    @Environment(\.isItemDataEntry) private var isItemDataEntry

    func body(content: Content) -> some View {
        if isItemDataEntry {
            content.textContentType(.oneTimeCode)
        } else {
            content
        }
    }
}
