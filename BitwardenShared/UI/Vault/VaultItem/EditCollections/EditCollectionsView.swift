import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - EditCollectionsView

/// A view that allows the user to move a cipher between collections.
///
struct EditCollectionsView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<EditCollectionsState, EditCollectionsAction, EditCollectionsEffect>

    // MARK: View

    var body: some View {
        content
            .navigationTitle(Localizations.sharedFolders)
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.perform(.fetchCipherOptions) }
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismissPressed)
                }

                saveToolbarItem {
                    await store.perform(.save)
                }
            }
    }

    // MARK: Private Views

    /// The collections as switches in one card, or an empty state.
    @ViewBuilder private var content: some View {
        if store.state.collections.isEmpty {
            PassYEmptyState(Localizations.thereAreNoSharedFoldersToList, systemImage: "square.stack")
                .passYEmptyListState()
        } else {
            Form {
                Section {
                    ForEach(store.state.collections, id: \.id) { collection in
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
                }
            }
            .passYReadableWidth()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Collections") {
    NavigationView {
        EditCollectionsView(
            store: Store(
                processor: StateProcessor(
                    state: EditCollectionsState(
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
                    ),
                ),
            ),
        )
    }
}
#endif
