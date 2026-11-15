import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - NativeSetupSection

/// A native, Apple-style replacement for the Bitwarden `ActionCard`: a section of a `Form`/`List` with a headline
/// row (SF Symbol, title, message), a prominent action row, an optional secondary row and a dismiss row.
///
struct NativeSetupSection: View {
    /// A tappable row of the section.
    struct Row {
        let title: String
        let action: () async -> Void

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

    /// The SF Symbol shown next to the headline.
    var systemImage = "checkmark.circle"

    /// The primary action row (for example "Turn on now").
    let action: Row

    /// An optional secondary action row (for example "Learn more").
    var secondary: Row?

    /// The dismiss row.
    var dismiss: Row?

    // MARK: View

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .accessibilityIdentifier("SetupSectionTitle")

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            AsyncButton {
                await action.action()
            } label: {
                Text(action.title).fontWeight(.semibold)
            }
            .accessibilityIdentifier("SetupSectionActionButton")

            if let secondary {
                AsyncButton {
                    await secondary.action()
                } label: {
                    Text(secondary.title)
                }
                .accessibilityIdentifier("SetupSectionSecondaryButton")
            }

            if let dismiss {
                AsyncButton {
                    await dismiss.action()
                } label: {
                    Text(dismiss.title).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("SetupSectionDismissButton")
            }
        }
    }
}
