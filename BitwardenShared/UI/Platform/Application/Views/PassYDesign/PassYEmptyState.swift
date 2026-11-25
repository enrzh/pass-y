import SwiftUI

// MARK: - PassYEmptyState

/// The empty state of a page or list: the system `ContentUnavailableView` (symbol, title, description) with optional
/// actions below (use `PassYButtonStyles`). Lay it over an empty list with `passYEmptyListState()` so the list (and
/// its large title) stays in place.
///
/// ```swift
/// List { ... }
///     .overlay {
///         if items.isEmpty {
///             PassYEmptyState("No items", systemImage: "tray", message: "Items you add appear here.") {
///                 Button("New item", systemImage: "plus") { add() }.passYButtonStyle(.primary)
///             }
///             .passYEmptyListState()
///         }
///     }
/// ```
///
struct PassYEmptyState<Actions: View>: View {
    // MARK: Properties

    /// The title.
    let title: String

    /// The SF Symbol.
    let systemImage: String

    /// The description below the title.
    var message: String?

    /// The accessibility identifier of the title.
    var identifier: String?

    /// The actions below the description.
    let actions: Actions

    // MARK: Initialization

    /// Creates an empty state.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - systemImage: The SF Symbol.
    ///   - message: The description below the title.
    ///   - identifier: The accessibility identifier of the title.
    ///   - actions: The actions below the description.
    ///
    init(
        _ title: String,
        systemImage: String,
        message: String? = nil,
        identifier: String? = nil,
        @ViewBuilder actions: () -> Actions,
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.identifier = identifier
        self.actions = actions()
    }

    // MARK: View

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .accessibilityIdentifier(identifier ?? "")
            } icon: {
                Image(systemName: systemImage)
            }
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            actions
        }
    }
}

extension PassYEmptyState where Actions == EmptyView {
    /// Creates an empty state without actions.
    init(_ title: String, systemImage: String, message: String? = nil, identifier: String? = nil) {
        self.init(title, systemImage: systemImage, message: message, identifier: identifier) { EmptyView() }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty state") {
    PassYEmptyState(
        "No verification codes",
        systemImage: "lock.rotation",
        message: "Add an authenticator key to a login to see its codes here.",
    ) {
        Button("New login", systemImage: "plus") {}
            .passYButtonStyle(.primary)
    }
}

#Preview("Search") {
    ContentUnavailableView.search(text: "bank")
}
#endif
