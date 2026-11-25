import SwiftUI

// MARK: - PassYFooterText

/// The footer of a settings section: the explanation in the system footer style and an optional inline link button
/// ("Learn more"), as in iOS Settings. Use it as a `Section` footer.
///
/// ```swift
/// Section {
///     ...
/// } footer: {
///     PassYFooterText(Localizations.sessionTimeoutFooter, link: Localizations.learnMore) { openHelp() }
/// }
/// ```
///
struct PassYFooterText: View {
    // MARK: Properties

    /// The explanation.
    let text: String

    /// The title of the link, `nil` for none.
    var link: String?

    /// The accessibility identifier of the link.
    var linkIdentifier: String?

    /// The link action.
    var action: (() -> Void)?

    // MARK: Initialization

    /// Creates a footer.
    ///
    /// - Parameters:
    ///   - text: The explanation.
    ///   - link: The title of the link, `nil` for none.
    ///   - linkIdentifier: The accessibility identifier of the link.
    ///   - action: The link action.
    ///
    init(_ text: String, link: String? = nil, linkIdentifier: String? = nil, action: (() -> Void)? = nil) {
        self.text = text
        self.link = link
        self.linkIdentifier = linkIdentifier
        self.action = action
    }

    // MARK: View

    var body: some View {
        VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
            Text(text)
            if let link, let action {
                Button(link, action: action)
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(linkIdentifier ?? "")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Footer") {
    List {
        Section {
            Text("Session timeout")
        } footer: {
            PassYFooterText("Your vault locks after this time without activity.", link: "Learn more") {}
        }
    }
}
#endif
