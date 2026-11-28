import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - SearchVaultFilterRowView

/// The vault filter row of the vault pages and their search ("Vault  All vaults ⌃⌄"): a menu choice row
/// (`PassYPickerRow`) for the members of an organization. In a list it is a plain row; `isCard` draws it as a card of
/// its own for pages without a list (no search results).
struct SearchVaultFilterRowView: View {
    // MARK: Properties

    /// Whether the row should have a bottom divider.
    let hasDivider: Bool

    /// The accessibility ID for the row.
    let accessibilityID: String?

    /// Whether the row draws its own card (outside a list).
    let isCard: Bool

    /// The `Store` for this view.
    @ObservedObject var store: Store<SearchVaultFilterRowState, SearchVaultFilterRowAction, Void>

    var body: some View {
        if !store.state.vaultFilterOptions.isEmpty {
            if isCard {
                row
                    .padding(.horizontal, PassYDesign.Spacing.large)
                    .padding(.vertical, PassYDesign.Spacing.xSmall)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: PassYDesign.Radius.large, style: .continuous),
                    )
                    .padding(PassYDesign.Spacing.large)
            } else {
                row
            }
        }
    }

    /// The choice row.
    private var row: some View {
        PassYPickerRow(
            Localizations.vault,
            options: store.state.vaultFilterOptions,
            selection: store.binding(
                get: \.searchVaultFilterType,
                send: SearchVaultFilterRowAction.searchVaultFilterChanged,
            ),
            identifier: accessibilityID ?? "ActiveFilterRow",
            optionTitle: \.title,
        )
        .accessibilityLabel(Localizations.filterByVault)
    }

    // MARK: Initialization

    /// Initialize a `SearchVaultFilterRowView`.
    ///
    /// - Parameters:
    ///   - hasDivider: Whether the row has a divider.
    ///   - accessibilityID: The accessibility ID for the row.
    ///   - isCard: Whether the row draws its own card (outside a list).
    ///   - store: The store used to render the view.
    ///
    init(
        hasDivider: Bool,
        accessibilityID: String? = nil,
        isCard: Bool = false,
        store: Store<SearchVaultFilterRowState, SearchVaultFilterRowAction, Void>,
    ) {
        self.hasDivider = hasDivider
        self.accessibilityID = accessibilityID
        self.isCard = isCard
        self.store = store
    }
}
