import SwiftUI

// MARK: - PassYTextBuffer

/// The local text of a Pass-Y text field, decoupled from the store binding.
///
/// iOS AutoFill checks after filling a field that the field still holds what it filled; a value that comes back from
/// the store a moment later (an "echo") must not overwrite newer typing, and an echo arriving out of order must be
/// dropped instead of resetting the field to a stale value. Every value the field sends out is counted, the matching
/// echo is consumed, and only real outside changes (a generated password, a scanned key) replace the local text.
/// (Carried over from `BitwardenTextField`, which the edit forms used before.)
///
struct PassYTextBuffer: Equatable {
    /// The text shown in the field.
    private(set) var text: String

    /// Values sent outward whose echo has not come back yet, with their count.
    private var pendingEchoes: [String: Int] = [:]

    /// Creates a buffer holding `text`.
    init(_ text: String) {
        self.text = text
    }

    /// The user changed the field to `newValue`. Returns whether the value must be sent to the store.
    mutating func userChanged(to newValue: String) -> Bool {
        guard text != newValue else { return false }
        text = newValue
        pendingEchoes[newValue, default: 0] += 1
        return true
    }

    /// The store value changed to `newValue`: an echo of a sent value is consumed, anything else replaces the text.
    mutating func storeChanged(to newValue: String) {
        if let count = pendingEchoes[newValue], count > 0 {
            pendingEchoes[newValue] = count == 1 ? nil : count - 1
            return
        }
        guard newValue != text else { return }
        text = newValue
    }
}

// MARK: - PassYFieldFocus

/// An external focus binding for a Pass-Y field, applied to the native text field only (not to the whole row, which
/// would make Full Keyboard Access treat the label and the trailing buttons as one focus target).
///
/// ```swift
/// @FocusState private var focus: Field?
/// PassYFormField(Localizations.username, text: $user, focus: .field($focus, equals: .username))
/// ```
///
struct PassYFieldFocus {
    /// Applies `focused(_:equals:)` to the native field.
    fileprivate let apply: (AnyView) -> AnyView

    /// Focuses the field when `binding` equals `value`.
    static func field<Value: Hashable>(_ binding: FocusState<Value?>.Binding, equals value: Value) -> PassYFieldFocus {
        PassYFieldFocus { AnyView($0.focused(binding, equals: value)) }
    }
}

extension View {
    /// Applies an optional `PassYFieldFocus`.
    @ViewBuilder
    func passYFocused(_ focus: PassYFieldFocus?) -> some View {
        if let focus {
            focus.apply(AnyView(self))
        } else {
            self
        }
    }
}

// MARK: - PassYFormField

/// A text row of a Pass-Y edit form (Apple Passwords / Contacts): the label on the left in the secondary colour, the
/// value right of it, aligned to the trailing edge, and optional trailing buttons. At accessibility text sizes the
/// label stands above the value so neither is cut off. The `.free` style has no label: the title is the placeholder
/// of a field that starts at the leading edge (the item name).
///
/// Keyboard and AutoFill behaviour comes from the standard modifiers on the row (`textContentType`, `keyboardType`,
/// `textInputAutocapitalization`, `autocorrectionDisabled`, `submitLabel`, `onSubmit`); focus from `focus:`.
///
/// ```swift
/// PassYFormField(Localizations.username, text: $username, identifier: "LoginUsernameEntry") {
///     Button("Generate", systemImage: "arrow.clockwise") { generate() }
/// }
/// .textContentType(.username)
/// .textInputAutocapitalization(.never)
/// ```
///
struct PassYFormField<Trailing: View>: View {
    // MARK: Types

    /// The layout of the row.
    enum Style {
        /// Label left, value right (the default).
        case inline

        /// No label; the title is the placeholder of a leading-aligned field.
        case free
    }

    // MARK: Properties

    /// The label (and the spoken name of the field).
    let title: String

    /// The text.
    @Binding var text: String

    /// The placeholder (the title for `.free`).
    var prompt: String?

    /// The layout.
    var style: Style = .inline

    /// The accessibility identifier of the native text field.
    var identifier: String?

    /// Whether the value uses the monospaced body font (keys, numbers).
    var isMonospaced = false

    /// Whether the field is read-only.
    var isReadOnly = false

    /// The external focus binding.
    var focus: PassYFieldFocus?

    /// Buttons after the field.
    let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isEnabled) private var isEnabled
    @SwiftUI.State private var buffer: PassYTextBuffer

    // MARK: Initialization

    /// Creates a text row.
    ///
    /// - Parameters:
    ///   - title: The label and spoken name.
    ///   - text: The text.
    ///   - prompt: The placeholder.
    ///   - style: The layout.
    ///   - identifier: The accessibility identifier of the native text field.
    ///   - isMonospaced: Whether the value is monospaced.
    ///   - isReadOnly: Whether the field is read-only.
    ///   - focus: The external focus binding.
    ///   - trailing: Buttons after the field.
    ///
    init(
        _ title: String,
        text: Binding<String>,
        prompt: String? = nil,
        style: Style = .inline,
        identifier: String? = nil,
        isMonospaced: Bool = false,
        isReadOnly: Bool = false,
        focus: PassYFieldFocus? = nil,
        @ViewBuilder trailing: () -> Trailing,
    ) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.style = style
        self.identifier = identifier
        self.isMonospaced = isMonospaced
        self.isReadOnly = isReadOnly
        self.focus = focus
        self.trailing = trailing()
        _buffer = SwiftUI.State(initialValue: PassYTextBuffer(text.wrappedValue))
    }

    // MARK: View

    var body: some View {
        PassYFieldRowLayout(
            title: style == .free ? nil : title,
            stacks: dynamicTypeSize.isAccessibilitySize,
        ) {
            field
        } trailing: {
            trailing
        }
        .onChange(of: text) { _, newValue in
            buffer.storeChanged(to: newValue)
        }
    }

    /// The native text field.
    private var field: some View {
        TextField(
            title,
            text: Binding(
                get: { buffer.text },
                set: { newValue in
                    if buffer.userChanged(to: newValue) { text = newValue }
                },
            ),
            prompt: Text(prompt ?? (style == .free ? title : "")),
        )
        .font(isMonospaced ? .body.monospaced() : .body)
        .multilineTextAlignment(style == .free || dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        .foregroundStyle(isEnabled && !isReadOnly ? Color.primary : Color.secondary)
        .disabled(isReadOnly)
        .accessibilityIdentifier(identifier ?? title)
        .accessibilityLabel(title)
        .passYFocused(focus)
    }
}

extension PassYFormField where Trailing == EmptyView {
    /// Creates a text row without trailing buttons.
    init(
        _ title: String,
        text: Binding<String>,
        prompt: String? = nil,
        style: Style = .inline,
        identifier: String? = nil,
        isMonospaced: Bool = false,
        isReadOnly: Bool = false,
        focus: PassYFieldFocus? = nil,
    ) {
        self.init(
            title,
            text: text,
            prompt: prompt,
            style: style,
            identifier: identifier,
            isMonospaced: isMonospaced,
            isReadOnly: isReadOnly,
            focus: focus,
        ) { EmptyView() }
    }
}

// MARK: - PassYFieldRowLayout

/// The shared layout of the Pass-Y field rows: label left and field right, or (accessibility sizes) label above the
/// field; trailing buttons at the end. At least 44 pt high.
struct PassYFieldRowLayout<Field: View, Trailing: View>: View {
    /// The label, `nil` for a free field.
    let title: String?

    /// Whether the label stands above the field.
    let stacks: Bool

    /// The field.
    @ViewBuilder let field: () -> Field

    /// Buttons after the field.
    @ViewBuilder let trailing: () -> Trailing

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: PassYDesign.Spacing.medium) {
            if stacks {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
                    label
                    field()
                }
            } else {
                label
                field()
            }
            trailing()
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder private var label: some View {
        if let title {
            Text(title)
                .font(.body)
                .foregroundStyle(isEnabled ? Color.secondary : Color(.tertiaryLabel))
                .lineLimit(stacks ? nil : 2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Form fields") {
    @Previewable @SwiftUI.State var name = ""
    @Previewable @SwiftUI.State var user = "octo@example.test"
    Form {
        Section {
            PassYFormField("Item name (required)", text: $name, style: .free, identifier: "ItemNameEntry")
        }
        Section {
            PassYFormField("Username", text: $user) {
                Button("Generate", systemImage: "arrow.clockwise") {}
            }
            .textContentType(.username)
            PassYFormField("Card number", text: .constant("4111 1111 1111 1111"), isMonospaced: true)
            PassYFormField("Read-only", text: .constant("Locked"), isReadOnly: true)
        }
    }
}
#endif
