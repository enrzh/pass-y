import BitwardenResources
import SwiftUI

// MARK: - SectionHeaderView

/// A section header.
///
public struct SectionHeaderView: View {
    // MARK: Properties

    /// The section title.
    let title: String

    // MARK: View

    public var body: some View {
        Text(title)
            .font(.footnote)
            .accessibilityAddTraits(.isHeader)
            .foregroundColor(Color(.label).opacity(0.72)) // ui-r6: contrast (accessibility audit)
            .textCase(nil)
            .padding(.leading, 16)
    }

    // MARK: Initialization

    /// Initializes a new section header.
    ///
    /// - Parameters:
    ///   - title: The section title.
    ///
    public init(_ title: String) {
        self.title = title
    }
}

// MARK: Previews

#Preview {
    SectionHeaderView("Section header")
}
