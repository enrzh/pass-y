import BitwardenResources
import SwiftUI

// MARK: - ContentBlock

/// A view that displays a block of content, where each content item is separated by a divider.
/// The block has the secondary background color applied with rounded corners.
///
/// Adapted from: https://movingparts.io/variadic-views-in-swiftui
///
public struct ContentBlock<Content: View>: View {
    // MARK: Properties

    /// The content to display in the content block.
    let content: Content

    /// The amount of leading padding to apply to the divider.
    let dividerLeadingPadding: CGFloat

    // MARK: View

    @Environment(\.isNativeForm) private var isNativeForm

    public var body: some View {
        if isNativeForm {
            // Native `Form`: every child is its own row, separators and corners come from the system.
            _VariadicView.Tree(NativeRows()) {
                content
            }
        } else {
            variadicBody
        }
    }

    private var variadicBody: some View {
        // This uses SwiftUI's `VariadicView` API, which isn't part of SwiftUI's public API but
        // since much of SwiftUI itself uses this, there's a low likelihood of this being removed.
        _VariadicView.Tree(Layout(dividerLeadingPadding: dividerLeadingPadding)) {
            content
        }
    }

    // MARK: Initialization

    /// Initialize a `ContentBlock`.
    ///
    /// - Parameters:
    ///   - dividerLeadingPadding: The amount of leading padding to apply to the divider. Defaults
    ///     to `0` which will cause the divider to span the full width of the view.
    ///   - content: The content to display in the content block.
    ///
    public init(dividerLeadingPadding: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.dividerLeadingPadding = dividerLeadingPadding
    }
}

extension ContentBlock {
    /// Rows of a native form: each child is a row with zero insets (children pad themselves).
    private struct NativeRows: _VariadicView_MultiViewRoot {
        func body(children: _VariadicView.Children) -> some View {
            ForEach(children) { child in
                child
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets())
            }
        }
    }

    /// The layout for the content block.
    private struct Layout: _VariadicView_UnaryViewRoot {
        // MARK: Properties

        /// The amount of leading padding to apply to the divider.
        let dividerLeadingPadding: CGFloat

        // MARK: View

        func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id

            VStack(spacing: 0) {
                ForEach(children) { child in
                    VStack(alignment: .leading, spacing: 0) {
                        child

                        if child.id != last {
                            Divider()
                                .padding(.leading, dividerLeadingPadding)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(SharedAsset.Colors.backgroundSecondary.swiftUIColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

// MARK: - View + ContentBlock

public extension View {
    /// Wraps the view within a `ContentBlock`.
    ///
    func contentBlock() -> some View {
        ContentBlock {
            self
        }
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    ContentBlock {
        Text("Apple 🍎").padding()
        Text("Banana 🍌").padding()
        Text("Grapes 🍇").padding()
    }
    .padding()
    .background(SharedAsset.Colors.backgroundPrimary.swiftUIColor)
}
#endif
