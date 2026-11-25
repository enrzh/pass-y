import SwiftUI

// MARK: - PassYSectionFooter

/// The footer of a form section: one short explanation in the footnote style and the secondary colour, optionally
/// followed by a link-style action ("Learn more"). Replaces the Bitwarden field footers and info cards.
///
/// ```swift
/// Section { rows } footer: {
///     PassYSectionFooter(Localizations.passwordPromptFooter, actionTitle: Localizations.learnMore) { openHelp() }
/// }
/// ```
///
struct PassYSectionFooter: View {
    /// The explanation.
    let text: String

    /// The title of the link-style action, `nil` for none.
    var actionTitle: String?

    /// The accessibility identifier of the action.
    var actionIdentifier: String?

    /// The action.
    var action: (() -> Void)?

    /// Creates a section footer.
    ///
    /// - Parameters:
    ///   - text: The explanation.
    ///   - actionTitle: The title of a link-style action.
    ///   - actionIdentifier: The accessibility identifier of the action.
    ///   - action: The action.
    ///
    init(_ text: String, actionTitle: String? = nil, actionIdentifier: String? = nil, action: (() -> Void)? = nil) {
        self.text = text
        self.actionTitle = actionTitle
        self.actionIdentifier = actionIdentifier
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
            Text(text)
                .foregroundStyle(.secondary)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.tint)
                    .accessibilityIdentifier(actionIdentifier ?? actionTitle)
            }
        }
        .font(.footnote)
        .textCase(nil)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Section footer") {
    Form {
        Section {
            Text("Row")
        } footer: {
            PassYSectionFooter("Ask for the master password before showing this item.", actionTitle: "Learn more") {}
        }
    }
}
#endif
