import SwiftUI

// MARK: - PassYActionStack

/// The actions at the end of an auth or one-off page, as a borderless section of a `Form`: the buttons stacked with
/// the Pass-Y spacing and side margins (one `.passYButtonStyle(.primary, fillsWidth: true)` button, further actions as
/// secondary or plain buttons). The section has no card, separators or insets.
///
/// ```swift
/// Form {
///     Section { PassYHeroHeader(title: Localizations.expiredLink) }.passYPlainListRow()
///     PassYActionStack {
///         Button(Localizations.restartRegistration) { restart() }.passYButtonStyle(.primary, fillsWidth: true)
///         Button(Localizations.logIn) { logIn() }.buttonStyle(.borderless)
///     }
/// }
/// ```
///
struct PassYActionStack<Content: View>: View {
    /// The buttons.
    let content: Content

    /// Creates an action stack.
    ///
    /// - Parameter content: The buttons.
    ///
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Section {
            VStack(spacing: PassYDesign.Spacing.medium) {
                content
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PassYDesign.Spacing.large)
            .padding(.vertical, PassYDesign.Spacing.small)
        }
        .passYPlainListRow()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Action stack") {
    Form {
        Section { PassYHeroHeader(title: "Link expired", message: "Restart the registration.") }
            .passYPlainListRow()
        PassYActionStack {
            Button {} label: { Text("Restart registration").frame(maxWidth: .infinity) }
                .passYButtonStyle(.primary, fillsWidth: true)
            Button("Log in") {}
                .buttonStyle(.borderless)
        }
    }
}
#endif
