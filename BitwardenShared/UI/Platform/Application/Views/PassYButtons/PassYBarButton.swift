import BitwardenResources
import SwiftUI

// MARK: - PassYButtonMetrics

/// Shared sizes of the Pass-Y buttons.
enum PassYButtonMetrics {
    /// The smallest touch target of any button (Apple HIG: 44 x 44 pt).
    static let minTarget: CGFloat = 44
}

// MARK: - PassYBarButton

/// A round icon button of the bottom bar (Vault, search cancel): one 44 pt interactive Liquid Glass circle, the whole
/// circle is the touch target, the action runs on touch-up without any hop, and a soft haptic confirms the press.
///
/// Press feedback is the interactive glass itself (it reacts on touch-down, in the same frame) plus the plain style's
/// dimming of the symbol. The caller adds `.reportsBarFrame()` so the bar container keeps the touch.
struct PassYBarButton: View {
    // MARK: Properties

    /// The SF Symbol.
    let systemImage: String

    /// The VoiceOver label.
    let label: String

    /// The accessibility identifier (UI tests).
    let identifier: String

    /// The action, run synchronously on touch-up.
    let action: () -> Void

    /// Counts presses; drives the haptic.
    @SwiftUI.State private var presses = 0

    // MARK: View

    var body: some View {
        Button {
            presses += 1
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: PassYButtonMetrics.minTarget, height: PassYButtonMetrics.minTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(BarBackground(shape: Circle()))
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: presses)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Bar buttons

extension PassYBarButton {
    /// The Vault button left of the search field: returns to the vault home from every other page.
    static func vault(action: @escaping () -> Void) -> PassYBarButton {
        PassYBarButton(
            systemImage: "lock.shield",
            label: Localizations.myVault,
            identifier: "BottomBarVaultButton",
            action: action,
        )
    }

    /// The search cancel button: clears the search and closes the keyboard. A real SwiftUI button because the
    /// `UISearchBar` cancel button did not clear the search after the keyboard had been closed with the Search key.
    static func searchCancel(action: @escaping () -> Void) -> PassYBarButton {
        PassYBarButton(
            systemImage: "xmark",
            label: Localizations.cancel,
            identifier: "VaultSearchCancel",
            action: action,
        )
    }
}
