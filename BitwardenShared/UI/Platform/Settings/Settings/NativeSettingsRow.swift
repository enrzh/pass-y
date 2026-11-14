import SwiftUI

// MARK: - NativeSettingsRow

/// A native settings row for a `Form`/`List`: SF Symbol, title, optional detail and a
/// trailing accessory (disclosure chevron by default, or an SF Symbol such as an external link).
///
struct NativeSettingsRow: View {
    // MARK: Types

    /// The trailing accessory of the row.
    enum Accessory {
        /// A disclosure chevron for pushing a screen.
        case disclosure

        /// An SF Symbol, e.g. `arrow.up.right.square` for an external link.
        case symbol(String)

        /// No accessory.
        case none
    }

    // MARK: Properties

    /// The trailing accessory.
    var accessory: Accessory = .disclosure

    /// The action performed on tap.
    let action: () -> Void

    /// The accessibility identifier of the row.
    var accessibilityIdentifier: String?

    /// The SF Symbol shown before the title.
    var symbol: String?

    /// The foreground style of the title.
    var titleStyle: Color = .primary

    /// The title of the row.
    let title: String

    // MARK: View

    var body: some View {
        Button(action: action) {
            HStack {
                if let symbol {
                    Label(title, systemImage: symbol)
                        .foregroundStyle(titleStyle)
                } else {
                    Text(title)
                        .foregroundStyle(titleStyle)
                }
                Spacer()
                switch accessory {
                case .disclosure:
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                case let .symbol(name):
                    Image(systemName: name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                case .none:
                    EmptyView()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
