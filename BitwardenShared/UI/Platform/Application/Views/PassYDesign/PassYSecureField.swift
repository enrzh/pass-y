import BitwardenResources
import SwiftUI

// MARK: - PassYSecureField

/// A secret row of a Pass-Y edit form (password, authenticator key, security code, hidden custom field): the label on
/// the left, the value masked by a `SecureField`, an eye button that reveals it as a plain monospaced `TextField` (same
/// accessibility identifier, so tests and VoiceOver find one field in both states) and optional trailing buttons.
/// Revealing keeps the keyboard focus on the field.
///
/// ```swift
/// PassYSecureField(
///     Localizations.password,
///     text: $password,
///     isRevealed: $isPasswordVisible,
///     identifier: "LoginPasswordEntry",
///     revealIdentifier: "ViewPasswordButton",
/// ) {
///     Button("Generate", systemImage: "arrow.clockwise") { generate() }
/// }
/// ```
///
struct PassYSecureField<Trailing: View>: View {
    // MARK: Properties

    /// The label (and the spoken name of the field).
    let title: String

    /// The secret.
    @Binding var text: String

    /// Whether the secret is shown in plain text; `nil` keeps the state inside the row.
    var isRevealed: Binding<Bool>?

    /// Whether the user may reveal the secret (no eye button otherwise; the value stays masked).
    var canReveal = true

    /// The accessibility identifier of the native field (masked and revealed).
    var identifier: String?

    /// The accessibility identifier of the eye button.
    var revealIdentifier: String?

    /// The field name VoiceOver reads on the eye button, `nil` for the generic password wording.
    var revealSpokenName: String?

    /// The external focus binding.
    var focus: PassYFieldFocus?

    /// Buttons after the eye button.
    let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isEnabled) private var isEnabled
    @SwiftUI.State private var buffer: PassYTextBuffer
    @SwiftUI.State private var localRevealed = false
    @FocusState private var isFocused: Bool

    // MARK: Initialization

    /// Creates a secret row.
    ///
    /// - Parameters:
    ///   - title: The label and spoken name.
    ///   - text: The secret.
    ///   - isRevealed: Whether the secret is shown; `nil` keeps the state inside the row.
    ///   - canReveal: Whether the user may reveal the secret.
    ///   - identifier: The accessibility identifier of the native field.
    ///   - revealIdentifier: The accessibility identifier of the eye button.
    ///   - focus: The external focus binding.
    ///   - trailing: Buttons after the eye button.
    ///
    init(
        _ title: String,
        text: Binding<String>,
        isRevealed: Binding<Bool>? = nil,
        canReveal: Bool = true,
        identifier: String? = nil,
        revealIdentifier: String? = nil,
        revealSpokenName: String? = nil,
        focus: PassYFieldFocus? = nil,
        @ViewBuilder trailing: () -> Trailing,
    ) {
        self.revealSpokenName = revealSpokenName
        self.title = title
        _text = text
        self.isRevealed = isRevealed
        self.canReveal = canReveal
        self.identifier = identifier
        self.revealIdentifier = revealIdentifier
        self.focus = focus
        self.trailing = trailing()
        _buffer = SwiftUI.State(initialValue: PassYTextBuffer(text.wrappedValue))
    }

    // MARK: View

    /// Whether the value is shown in plain text.
    private var revealed: Bool {
        canReveal && (isRevealed?.wrappedValue ?? localRevealed)
    }

    var body: some View {
        PassYFieldRowLayout(title: title, stacks: dynamicTypeSize.isAccessibilitySize) {
            field
        } trailing: {
            if canReveal {
                PassYRevealButton(isRevealed: revealed, fieldName: revealSpokenName, identifier: revealIdentifier) {
                    let keepsFocus = isFocused
                    if let isRevealed {
                        isRevealed.wrappedValue.toggle()
                    } else {
                        localRevealed.toggle()
                    }
                    // The masked and the plain field are two native fields: give the focus to the new one.
                    if keepsFocus {
                        Task { @MainActor in isFocused = true }
                    }
                }
            }
            trailing
        }
        .onChange(of: text) { _, newValue in
            buffer.storeChanged(to: newValue)
        }
    }

    /// The binding the native field edits.
    private var fieldText: Binding<String> {
        Binding(
            get: { buffer.text },
            set: { newValue in
                if buffer.userChanged(to: newValue) { text = newValue }
            },
        )
    }

    /// The masked or the plain native field.
    @ViewBuilder private var field: some View {
        Group {
            if revealed {
                TextField(title, text: fieldText, prompt: Text(""))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField(title, text: fieldText, prompt: Text(""))
            }
        }
        .font(.body.monospaced())
        .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
        .accessibilityIdentifier(identifier ?? title)
        .accessibilityLabel(title)
        .focused($isFocused)
        .passYFocused(focus)
    }
}

extension PassYSecureField where Trailing == EmptyView {
    /// Creates a secret row without trailing buttons.
    init(
        _ title: String,
        text: Binding<String>,
        isRevealed: Binding<Bool>? = nil,
        canReveal: Bool = true,
        identifier: String? = nil,
        revealIdentifier: String? = nil,
        revealSpokenName: String? = nil,
        focus: PassYFieldFocus? = nil,
    ) {
        self.init(
            title,
            text: text,
            isRevealed: isRevealed,
            canReveal: canReveal,
            identifier: identifier,
            revealIdentifier: revealIdentifier,
            revealSpokenName: revealSpokenName,
            focus: focus,
        ) { EmptyView() }
    }
}

// MARK: - PassYRevealButton

/// The eye button of a secret: `eye` while hidden, `eye.slash` while shown. VoiceOver reads which field it affects.
struct PassYRevealButton: View {
    /// Whether the secret is shown.
    let isRevealed: Bool

    /// The name of the field VoiceOver reads ("Account number is hidden"), `nil` for the password wording.
    var fieldName: String?

    /// The accessibility identifier.
    var identifier: String?

    /// Toggles the secret.
    let action: () -> Void

    /// What VoiceOver reads: the field-specific wording with a field name, the password wording without.
    var label: String {
        if let fieldName {
            return isRevealed
                ? Localizations.fieldValueIsVisibleTapToHide(fieldName)
                : Localizations.fieldValueIsNotVisibleTapToShow(fieldName)
        }
        return isRevealed ? Localizations.passwordIsVisibleTapToHide : Localizations.passwordIsNotVisibleTapToShow
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? "TextVisibilityToggle")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Secure fields") {
    @Previewable @SwiftUI.State var password = "Sup3r-Secret"
    @Previewable @SwiftUI.State var revealed = false
    Form {
        Section {
            PassYSecureField("Password", text: $password, isRevealed: $revealed, identifier: "LoginPasswordEntry") {
                Button("Generate", systemImage: "arrow.clockwise") {}
            }
            PassYSecureField("Security code", text: .constant("123"))
                .keyboardType(.numberPad)
            PassYSecureField("Hidden", text: .constant("secret"), canReveal: false)
        }
    }
}
#endif
