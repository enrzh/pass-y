import SwiftUI

extension View {
    /// Gives a native `Form` the grouped app background so its cards stay visible (also inside sheets).
    /// On iOS 15 the form already draws the grouped background itself.
    @ViewBuilder
    func passYNativeFormBackground() -> some View {
        if #available(iOS 16, *) {
            scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
        } else {
            self
        }
    }
}
