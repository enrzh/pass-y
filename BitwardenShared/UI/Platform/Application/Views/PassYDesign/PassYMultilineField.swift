import SwiftUI

// MARK: - PassYMultilineField

/// A multi-line text row (notes, Send text, SSH key, Send message): a system `TextEditor` that grows with its text,
/// with the title as the placeholder while it is empty (Apple Notes / Reminders style, no label column), the store
/// binding decoupled through `PassYTextBuffer` like the single-line fields. A `TextEditor` is a text view for
/// VoiceOver and UI tests (`textViews[...]`), which the Send tests rely on.
///
/// ```swift
/// PassYMultilineField(Localizations.notes, text: $notes, identifier: "ItemNotesEntry")
/// ```
///
struct PassYMultilineField: View {
    /// The placeholder and spoken name.
    let title: String

    /// The text.
    @Binding var text: String

    /// The accessibility identifier of the text view.
    var identifier: String?

    /// Whether the text is monospaced (keys).
    var isMonospaced = false

    /// Whether the text can be edited.
    var isEditable = true

    /// The height of three lines of body text, the minimum of the editor.
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 66

    @Environment(\.isEnabled) private var isEnabled
    @SwiftUI.State private var buffer: PassYTextBuffer

    /// Creates a multi-line text row.
    ///
    /// - Parameters:
    ///   - title: The placeholder and spoken name.
    ///   - text: The text.
    ///   - identifier: The accessibility identifier of the text view.
    ///   - isMonospaced: Whether the text is monospaced.
    ///   - isEditable: Whether the text can be edited.
    ///
    init(
        _ title: String,
        text: Binding<String>,
        identifier: String? = nil,
        isMonospaced: Bool = false,
        isEditable: Bool = true,
    ) {
        self.title = title
        _text = text
        self.identifier = identifier
        self.isMonospaced = isMonospaced
        self.isEditable = isEditable
        _buffer = SwiftUI.State(initialValue: PassYTextBuffer(text.wrappedValue))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if buffer.text.isEmpty {
                Text(title)
                    .foregroundStyle(Color(.placeholderText))
                    // The text view insets its text by 8 pt at the top and 5 pt at the leading edge.
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .accessibilityHidden(true)
            }
            TextEditor(
                text: Binding(
                    get: { buffer.text },
                    set: { newValue in
                        if buffer.userChanged(to: newValue) { text = newValue }
                    },
                ),
            )
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(minHeight: minHeight)
            .disabled(!isEditable)
            .foregroundStyle(isEnabled && isEditable ? Color.primary : Color.secondary)
            .accessibilityIdentifier(identifier ?? title)
            .accessibilityLabel(title)
        }
        .font(isMonospaced ? .body.monospaced() : .body)
        // Aligns the text with the other rows (the text view adds its own 5 pt inset).
        .padding(.horizontal, -5)
        .onChange(of: text) { _, newValue in
            buffer.storeChanged(to: newValue)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Multiline field") {
    @Previewable @SwiftUI.State var notes = ""
    Form {
        Section { PassYMultilineField("Notes", text: $notes) }
        Section { PassYMultilineField("Key", text: .constant("ssh-ed25519 AAAA..."), isMonospaced: true) }
    }
}
#endif
