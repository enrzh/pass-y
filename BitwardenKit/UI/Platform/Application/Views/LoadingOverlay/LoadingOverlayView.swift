import SwiftUI

/// A loading overlay: the system spinner and the progress text on a glass card, centred over a dimmed page.
///
struct LoadingOverlayView: View {
    // MARK: Properties

    /// The state used to configure the display of the view.
    let state: LoadingOverlayState

    // MARK: View

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text(state.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(minWidth: 160)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("LoadingViewImage")
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.black.opacity(0.2).ignoresSafeArea())
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    LoadingOverlayView(state: LoadingOverlayState(title: "Progress..."))
}
#endif
