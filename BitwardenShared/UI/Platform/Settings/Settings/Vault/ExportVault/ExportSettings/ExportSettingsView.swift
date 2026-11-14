import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ExportSettingsView

/// A view that allows users to view choose how to export the vault.
///
struct ExportSettingsView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<Void, ExportSettingsAction, Void>

    // MARK: View

    var body: some View {
        Form {
            Section {
                row(Localizations.exportVaultToAFile, symbol: "doc.badge.arrow.up", id: "ExportVaultToAFileLabel") {
                    store.send(.exportToFileTapped)
                }
                row(
                    Localizations.exportVaultToAnotherApp,
                    symbol: "square.and.arrow.up.on.square",
                    id: "ExportVaultToAnotherAppLabel",
                ) {
                    store.send(.exportToAppTapped)
                }
            }
        }
        .passYNativeFormBackground()
        .navigationBar(title: Localizations.exportVault, titleDisplayMode: .inline)
    }

    // MARK: Private views

    /// A navigation-style row with a leading SF Symbol and a gray chevron.
    private func row(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

#Preview {
    ExportSettingsView(store: Store(processor: StateProcessor()))
}
