import BitwardenResources
import SwiftUI

// MARK: - PassYPasswordField

/// A password (or PIN) field for a `Form`: the system `SecureField`, swapped for a `TextField` while revealed, and an
/// eye button that shows or hides the value. No autocapitalisation or autocorrection; the content type, keyboard and
/// submit label are the caller's. Apply `.focused(...)` and `.onSubmit` to the field itself (both reach the text
/// field inside).
///
/// The reveal state is the caller's (usually the processor's state), so it survives re-renders and is testable.
///
/// ```swift
/// PassYPasswordField(Localizations.masterPassword, text: $password, isRevealed: revealed,
///                  fieldIdentifier: "LoginMasterPasswordEntry") { revealed = $0 }
///     .focused($focus, equals: .password)
///     .submitLabel(.go)
///     .onSubmit { logIn() }
/// ```
///
struct PassYPasswordField: View {
    // MARK: Properties

    /// The placeholder and accessibility label.
    let title: String

    /// The value.
    @Binding var text: String

    /// Whether the value is shown in clear text.
    let isRevealed: Bool

    /// The text content type (`.password`, `.newPassword`, `.oneTimeCode`).
    var contentType: UITextContentType? = .password

    /// The keyboard type (`.numberPad` for a PIN).
    var keyboard: UIKeyboardType = .default

    /// The accessibility identifier of the text field.
    var fieldIdentifier: String?

    /// The accessibility identifier of the eye button.
    var toggleIdentifier: String? = "PasswordVisibilityToggle"

    /// Called with the new reveal state when the eye button is tapped.
    let onRevealChange: (Bool) -> Void

    // MARK: Initialization

    /// Creates a secure field.
    ///
    /// - Parameters:
    ///   - title: The placeholder and accessibility label.
    ///   - text: The value.
    ///   - isRevealed: Whether the value is shown in clear text.
    ///   - contentType: The text content type.
    ///   - keyboard: The keyboard type.
    ///   - fieldIdentifier: The accessibility identifier of the text field.
    ///   - toggleIdentifier: The accessibility identifier of the eye button.
    ///   - onRevealChange: Called with the new reveal state when the eye button is tapped.
    ///
    init(
        _ title: String,
        text: Binding<String>,
        isRevealed: Bool,
        contentType: UITextContentType? = .password,
        keyboard: UIKeyboardType = .default,
        fieldIdentifier: String? = nil,
        toggleIdentifier: String? = "PasswordVisibilityToggle",
        onRevealChange: @escaping (Bool) -> Void,
    ) {
        self.title = title
        _text = text
        self.isRevealed = isRevealed
        self.contentType = contentType
        self.keyboard = keyboard
        self.fieldIdentifier = fieldIdentifier
        self.toggleIdentifier = toggleIdentifier
        self.onRevealChange = onRevealChange
    }

    // MARK: View

    var body: some View {
        HStack(spacing: PassYDesign.Spacing.small) {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                        .fontDesign(.monospaced)
                        .accessibilityIdentifier(fieldIdentifier ?? "")
                } else {
                    SecureField(title, text: $text)
                        .accessibilityIdentifier(fieldIdentifier ?? "")
                }
            }
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)

            Button {
                onRevealChange(!isRevealed)
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(toggleIdentifier ?? "")
            .accessibilityLabel(
                isRevealed ? PassYPasswordField.hideLabel : PassYPasswordField.showLabel,
            )
        }
    }

    /// The VoiceOver label of the eye button while the value is hidden.
    static var showLabel: String { Localizations.passwordIsNotVisibleTapToShow }

    /// The VoiceOver label of the eye button while the value is shown.
    static var hideLabel: String { Localizations.passwordIsVisibleTapToHide }
}

// MARK: - Previews

#if DEBUG
#Preview("Password field") {
    @Previewable @SwiftUI.State var text = "correct horse"
    @Previewable @SwiftUI.State var revealed = false
    Form {
        PassYPasswordField("Master password", text: $text, isRevealed: revealed) { revealed = $0 }
        PassYPasswordField("PIN", text: $text, isRevealed: true, keyboard: .numberPad, toggleIdentifier: nil) { _ in }
    }
}
#endif
