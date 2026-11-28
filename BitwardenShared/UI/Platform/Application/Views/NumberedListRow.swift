import BitwardenResources
import SwiftUI

/// A view that displays a single row within a `NumberedList`.
///
struct NumberedListRow: View {
    // MARK: Properties

    /// The title to display in the row.
    let title: String

    /// An optional subtitle to display in the row.
    let subtitle: String?

    // MARK: View

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(.body)
                .foregroundStyle(.primary)

            if let subtitle {
                Text(LocalizedStringKey(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: Initialization

    /// Initializes a `NumberedListRow`.
    ///
    /// - Parameters:
    ///   - title: The title to display in the row.
    ///   - subtitle: An optional subtitle to display in the row.
    ///
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    NumberedList {
        NumberedListRow(title: "Apple 🍎")
        NumberedListRow(title: "Banana 🍌")
        NumberedListRow(title: "Grapes 🍇")
    }
}
#endif
