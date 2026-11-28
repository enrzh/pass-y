import BitwardenResources
import SwiftUI

// MARK: - SearchNoResultsView

/// A view that displays the no search results image and text.
///
public struct SearchNoResultsView<Content: View>: View {
    // MARK: Properties

    /// An optional view to display at the top of the scroll view above the no results image and text.
    var headerView: Content?

    // MARK: View

    public var body: some View {
        GeometryReader { reader in
            ScrollView {
                VStack(spacing: 0) {
                    if let headerView {
                        headerView
                    }

                    ContentUnavailableView {
                        Label {
                            Text(Localizations.thereAreNoItemsThatMatchTheSearch)
                                .accessibilityIdentifier("NoSearchResultsLabel")
                        } icon: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: reader.size.height)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Initialization

    /// Initialize a `SearchNoResultsView`.
    ///
    public init() where Content == EmptyView {
        headerView = nil
    }

    /// Initialize a `SearchNoResultsView` with a header view.
    ///
    /// - Parameter headerView: An optional view to display at the top of the scroll view above the
    ///     no results image and text.
    ///
    public init(headerView: () -> Content) {
        self.headerView = headerView()
    }
}

// MARK: - Previews

#Preview("No Results") {
    SearchNoResultsView()
}

#Preview("No Results With Header") {
    SearchNoResultsView {
        Text("Optional header text!")
    }
}
