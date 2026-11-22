import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - DelayedLoadingIndicator

/// The indicator of a `LoadingView`, shown only after `delay` seconds so that quick loads show no spinner at all.
/// Before that the area is empty (the page background). Nothing animates while it is hidden.
struct DelayedLoadingIndicator: View {
    /// The seconds to wait before the indicator is shown.
    static let delay: Double = 0.4

    /// An optional message displayed below the loading indicator.
    var loadingMessage: String?

    /// Whether the indicator is shown.
    @SwiftUI.State private var isVisible: Bool

    /// - Parameters:
    ///   - loadingMessage: An optional message displayed below the loading indicator.
    ///   - initiallyVisible: Shows the indicator at once (tests).
    init(loadingMessage: String? = nil, initiallyVisible: Bool = false) {
        self.loadingMessage = loadingMessage
        _isVisible = SwiftUI.State(initialValue: initiallyVisible)
    }

    var body: some View {
        // No `withAnimation`, no transition and no custom repeat-forever rotation: the indicator is the system spinner,
        // which XCUITest does not count as a running animation, and nothing here can outlive its view.
        ZStack {
            if isVisible {
                VStack(spacing: 24) {
                    ProgressView()
                        .controlSize(.large)
                    if let loadingMessage {
                        Text(loadingMessage)
                            .styleGuide(.headline, weight: .semibold)
                            .foregroundColor(Color(asset: SharedAsset.Colors.textPrimary))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(Self.delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            isVisible = true
        }
    }
}

// MARK: - LoadingView

/// A view that displays either a loading indicator or the content view for a set of loaded data.
struct LoadingView<T: Equatable & Sendable, Contents: View, ErrorView: View>: View {
    /// A view builder for displaying the loaded contents of this view.
    @ViewBuilder var contents: (T) -> Contents

    /// A view builder for displaying the error view with an error message.
    @ViewBuilder var errorView: (String) -> ErrorView

    /// An optional message displayed below the loading indicator while in the loading state.
    var loadingMessage: String?

    /// The state of this view.
    var state: LoadingState<T>

    var body: some View {
        switch state {
        case .loading:
            // ui-r9: no spinner flicker. Most loads finish within a few frames; the indicator only appears when the
            // load really takes a while (see `DelayedLoadingIndicator`).
            DelayedLoadingIndicator(loadingMessage: loadingMessage)
        case let .data(data):
            contents(data)
        case let .error(errorMessage):
            errorView(errorMessage)
        }
    }

    /// Initializer that shows nothing for the error state.
    ///
    /// - Parameters:
    ///   - state: The state of this view.
    ///   - loadingMessage: An optional message to display below the loading indicator.
    ///   - contents: A view builder for displaying the loaded contents of this view.
    ///
    init(
        state: LoadingState<T>,
        loadingMessage: String? = nil,
        @ViewBuilder contents: @escaping (T) -> Contents,
    ) where ErrorView == EmptyView {
        self.state = state
        self.loadingMessage = loadingMessage
        self.contents = contents
        errorView = { _ in EmptyView() }
    }

    /// Initializer for when both a content view and an error view are needed.
    ///
    /// - Parameters:
    ///   - state: The state of this view.
    ///   - loadingMessage: An optional message to display below the loading indicator.
    ///   - contents: A view builder for displaying the loaded contents of this view.
    ///   - errorView: A view builder for displaying the error view with an error message.
    ///
    init(
        state: LoadingState<T>,
        loadingMessage: String? = nil,
        @ViewBuilder contents: @escaping (T) -> Contents,
        @ViewBuilder errorView: @escaping (String) -> ErrorView,
    ) {
        self.state = state
        self.loadingMessage = loadingMessage
        self.contents = contents
        self.errorView = errorView
    }
}
