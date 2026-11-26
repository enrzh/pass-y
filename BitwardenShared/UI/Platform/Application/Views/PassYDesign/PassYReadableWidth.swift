import SwiftUI

// MARK: - View + readable width

extension View {
    /// Keeps the rows of a form or list at a readable width on wide screens (iPad full screen, landscape): when the
    /// page is wider than `maxWidth` plus the normal margins, the scroll content gets equal side margins so the cards
    /// stay `maxWidth` wide and centred; narrower pages keep the system margins. The scroll indicator stays at the
    /// edge of the page.
    ///
    /// - Parameter maxWidth: The widest the cards get (default 680 pt, about 70 characters of body text).
    ///
    func passYReadableWidth(_ maxWidth: CGFloat = 680) -> some View {
        modifier(PassYReadableWidthModifier(maxWidth: maxWidth))
    }
}

/// The side margins of `passYReadableWidth`.
struct PassYReadableWidthModifier: ViewModifier {
    /// The widest the cards get.
    let maxWidth: CGFloat

    @SwiftUI.State private var width: CGFloat = 0

    /// The side margin for a page of `width`, `nil` when the system margins already fit.
    static func margin(forWidth width: CGFloat, maxWidth: CGFloat) -> CGFloat? {
        let margin = ((width - maxWidth) / 2).rounded(.down)
        return margin > 40 ? margin : nil
    }

    func body(content: Content) -> some View {
        content
            // Safe-area padding, not content margins: a zero padding leaves the system margins untouched, so the
            // modifier never changes the look of a narrow page (and never swaps the view's identity).
            .safeAreaPadding(.horizontal, Self.margin(forWidth: width, maxWidth: maxWidth) ?? 0)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
    }
}
