import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - MoveToOrganizationView

/// A view that allows the user to move a cipher to an organization.
///
struct MoveToOrganizationView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<MoveToOrganizationState, MoveToOrganizationAction, MoveToOrganizationEffect>

    // MARK: View

    var body: some View {
        content
            .navigationTitle(Localizations.move)
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.perform(.fetchCipherOptions) }
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismissPressed)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    confirmToolbarButton(accessibilityIdentifier: "MoveButton", label: Localizations.move) {
                        await store.perform(.moveCipher)
                    }
                }
            }
    }

    // MARK: Private Views

    /// The collections of the chosen organization as switches.
    @ViewBuilder private var collectionsSections: some View {
        if !store.state.collectionsForOwner.isEmpty {
            Section {
                ForEach(store.state.collectionsForOwner, id: \.id) { collection in
                    if let collectionId = collection.id {
                        PassYToggleRow(
                            collection.name,
                            isOn: store.binding(
                                get: { _ in store.state.collectionIds.contains(collectionId) },
                                send: { .collectionToggleChanged($0, collectionId: collectionId) },
                            ),
                            identifier: "CollectionItemSwitch",
                        )
                    }
                }
            } header: {
                PassYSectionHeader(Localizations.sharedFolders)
            }
        }
    }

    /// The organization picker and its collections, or an empty state.
    @ViewBuilder private var content: some View {
        if store.state.ownershipOptions.isEmpty {
            PassYEmptyState(Localizations.noVaultsToList, systemImage: "building.2")
                .passYEmptyListState()
        } else {
            Form {
                organizationSection

                collectionsSections
            }
            .passYReadableWidth()
        }
    }

    /// The organization picker with its explanation.
    @ViewBuilder private var organizationSection: some View {
        if let owner = store.state.owner {
            Section {
                PassYPickerRow(
                    Localizations.vault,
                    options: store.state.ownershipOptions,
                    selection: store.binding(
                        get: { _ in owner },
                        send: MoveToOrganizationAction.ownerChanged,
                    ),
                    identifier: "OrganizationListDropdown",
                )
            } footer: {
                PassYSectionFooter(Localizations.chooseAVaultThatYouWishToMoveThisItemToDescriptionLong)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty Organizations") {
    NavigationView {
        MoveToOrganizationView(
            store: Store(
                processor: StateProcessor(
                    state: MoveToOrganizationState(
                        cipher: .fixture(),
                    ),
                ),
            ),
        )
    }
}

#Preview("Organizations") {
    NavigationView {
        MoveToOrganizationView(
            store: Store(
                processor: StateProcessor(
                    state: MoveToOrganizationState(
                        cipher: .fixture(),
                        collections: [
                            .fixture(
                                id: "1",
                                name: "Design",
                                organizationId: "1",
                            ),
                            .fixture(
                                id: "2",
                                name: "Engineering",
                                organizationId: "1",
                            ),
                        ],
                        organizationId: "1",
                        ownershipOptions: [.organization(id: "1", name: "Organization")],
                    ),
                ),
            ),
        )
    }
}
#endif
