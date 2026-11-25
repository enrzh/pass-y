import SwiftUI

// MARK: - PassYLoadingContent

/// Shows the content of a `LoadingState`: the data through `content`, an error as a `PassYEmptyState`, and while
/// loading the system spinner, which only appears after a short delay (most loads finish within a few frames, so
/// there is no spinner flicker). The spinner is the plain `ProgressView`, which XCUITest does not count as a
/// running animation.
///
/// ```swift
/// PassYLoadingContent(state: store.state.loadingState) { devices in
///     List(devices) { ... }
/// }
/// ```
///
struct PassYLoadingContent<T: Equatable & Sendable, Content: View>: View {
    // MARK: Properties

    /// The loading state.
    let state: LoadingState<T>

    /// The content for loaded data.
    @ViewBuilder let content: (T) -> Content

    // MARK: View

    var body: some View {
        switch state {
        case .loading:
            PassYDelayedSpinner()
        case let .data(data):
            content(data)
        case let .error(message):
            PassYEmptyState(message, systemImage: "exclamationmark.triangle")
        }
    }
}

// MARK: - PassYDelayedSpinner

/// The system spinner, shown only after `delay` seconds, centred in the available space.
struct PassYDelayedSpinner: View {
    /// The delay before the spinner appears.
    static let delay: Double = 0.4

    @SwiftUI.State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                ProgressView()
                    .controlSize(.large)
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

// MARK: - Previews

#if DEBUG
#Preview("Loading content") {
    PassYLoadingContent(state: LoadingState<[String]>.data(["A", "B"])) { items in
        List(items, id: \.self) { Text($0) }
    }
}

#Preview("Loading") {
    PassYLoadingContent(state: LoadingState<[String]>.loading(nil)) { _ in EmptyView() }
}
#endif
