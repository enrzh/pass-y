import BitwardenResources
import SwiftUI

// MARK: - NumberedList

/// A view that displays a numbered list of views, separated by a divider (system fonts and colours; the `Form` row
/// it sits in draws the card).
///
/// Adapted from: https://movingparts.io/variadic-views-in-swiftui
///
struct NumberedList<Content: View>: View {
    // MARK: Properties

    /// The content to display in the numbered list. Each child view will receive it's own number.
    let content: Content

    // MARK: View

    var body: some View {
        // This uses SwiftUI's `VariadicView` API, which isn't part of SwiftUI's public API but
        // since much of SwiftUI itself uses this, there's a low likelihood of this being removed.
        _VariadicView.Tree(Layout()) {
            content
        }
    }

    // MARK: Initialization

    /// Initialize a `NumberedList`.
    ///
    /// - Parameter content: The content to display in the numbered list.
    ///
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

extension NumberedList {
    /// The layout for the numbered list.
    private struct Layout: _VariadicView_UnaryViewRoot {
        func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id

            VStack(spacing: 0) {
                ForEachIndexed(children) { index, child in
                    HStack(spacing: 12) {
                        Text(String(index + 1))
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.tint)
                            .frame(minWidth: 24, alignment: .center)

                        VStack(alignment: .leading, spacing: 0) {
                            child

                            if child.id != last {
                                Divider()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
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
    .padding()
    .background(SharedAsset.Colors.backgroundPrimary.swiftUIColor)
}
#endif
