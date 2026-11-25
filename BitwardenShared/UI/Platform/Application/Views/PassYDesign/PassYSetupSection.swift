import SwiftUI

// MARK: - PassYSetupSection

/// A "set up" prompt as a section of a settings `Form` (like the iOS Settings suggestions): a headline row with a small
/// tinted SF Symbol tile and an explanation, a prominent action row, an optional secondary row and a quiet dismiss row.
/// Each row is a plain system button; async actions run in a `Task`.
///
/// ```swift
/// PassYSetupSection(title: Localizations.setUpUnlock, systemImage: "lock.open.fill",
///                   action: .init(title: Localizations.getStarted) { store.send(.showSetUpUnlock) },
///                   dismiss: .init(title: Localizations.dismiss) { await store.perform(.dismiss) })
/// ```
///
struct PassYSetupSection: View {
    // MARK: Types

    /// A tappable row of the section.
    struct Row {
        /// The title of the row.
        let title: String

        /// The action of the row.
        let action: () async -> Void

        /// Creates a row.
        ///
        /// - Parameters:
        ///   - title: The title of the row.
        ///   - action: The action of the row.
        ///
        init(title: String, action: @escaping () async -> Void) {
            self.title = title
            self.action = action
        }
    }

    // MARK: Properties

    /// The headline of the section.
    let title: String

    /// The explanation under the headline.
    var message: String?

    /// The SF Symbol of the headline tile.
    var systemImage = "checkmark.circle.fill"

    /// The colour of the headline tile.
    var tint: Color = .accentColor

    /// The primary action row (for example "Turn on now").
    let action: Row

    /// An optional secondary action row (for example "Learn more").
    var secondary: Row?

    /// The dismiss row.
    var dismiss: Row?

    // MARK: View

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: PassYDesign.Spacing.medium) {
                PassYIconTile(systemImage: systemImage, tint: tint, size: PassYDesign.IconSize.small)
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
                    Text(title)
                        .font(.headline)
                        .accessibilityIdentifier("SetupSectionTitle")
                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .passYListSeparatorLeading()
            }
            .padding(.vertical, PassYDesign.Spacing.xSmall)

            rowButton(action, identifier: "SetupSectionActionButton") { title in
                Text(title).fontWeight(.semibold)
            }

            if let secondary {
                rowButton(secondary, identifier: "SetupSectionSecondaryButton") { Text($0) }
            }

            if let dismiss {
                rowButton(dismiss, identifier: "SetupSectionDismissButton") { title in
                    Text(title).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// A row button that runs the row's async action.
    private func rowButton(
        _ row: Row,
        identifier: String,
        @ViewBuilder label: (String) -> some View,
    ) -> some View {
        Button {
            Task { await row.action() }
        } label: {
            label(row.title)
        }
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Setup section") {
    Form {
        PassYSetupSection(
            title: "Autofill with Pass-Y",
            message: "Fill passwords in apps and websites.",
            systemImage: "key.fill",
            tint: .green,
            action: .init(title: "Turn on now") {},
            secondary: .init(title: "Learn more") {},
            dismiss: .init(title: "Dismiss") {},
        )
    }
}
#endif
