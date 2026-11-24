import SwiftUI

extension View {
    /// Gives a native `Form` or inset-grouped `List` the grouped app background so its cards stay visible (also inside
    /// sheets). Lists need it too: an empty grouped list drew a lighter (almost white) background than the grouped
    /// page colour, so an empty folder page showed a light band above the bottom bar.
    func passYNativeFormBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
    }
}
