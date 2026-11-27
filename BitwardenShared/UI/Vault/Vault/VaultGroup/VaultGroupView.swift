import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - VaultGroupView

/// A view that displays the items in a single vault group.
struct VaultGroupView: View {
    // MARK: Properties

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The GroupSearchDelegate used to bridge UIKit to SwiftUI
    var searchHandler: VaultGroupSearchHandler?

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultGroupState, VaultGroupAction, VaultGroupEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    /// Whether the list is in Select mode (Apple Passwords).
    private var isSelecting: Bool { store.state.isSelecting }

    /// Whether the list itself is in edit mode (follows `isSelecting`, delayed when leaving).
    @SwiftUI.State private var listIsEditing = false

    /// The folders and move handlers of the rows' "Move to folder" menus.
    @SwiftUI.State private var folderMove = VaultFolderMove()

    // MARK: View

    var body: some View {
        content
            // Customize: the device's row and code preferences for the group page and its search results.
            .passYLayoutEnvironment()
            .toolbar { selectToolbar }
            .passYSearchTarget(
                id: ObjectIdentifier(store),
                isPushed: true,
                text: store.state.searchText,
                entries: addEntries,
                setText: { store.send(.searchTextChanged($0)) },
                setSearching: { store.send(.searchStateChanged(isSearching: $0)) },
            )
            .navigationTitle(store.state.group.navigationTitle)
            .passYItemCountSubtitle(itemCountSubtitle)
            .navigationBarTitleDisplayMode(.large)
            .vaultFolderMove(
                folderMove,
                folders: store.state.folders,
                move: { [weak store] item, folderId in
                    Task { await store?.perform(.moveItemToFolder(item, folderId: folderId)) }
                },
                moveToNewFolder: { [weak store] item in Task { await store?.perform(.moveItemToNewFolder(item)) } },
            )
            // The page color of the shell (the floating bottom bar area shows it too: a different color here drew a seam).
            .background(SharedAsset.Colors.backgroundPrimary.swiftUIColor.ignoresSafeArea())
            .task {
                await store.perform(.appeared)
            }
            .task {
                await store.perform(.streamOrganizations)
            }
            .task {
                await store.perform(.streamShowWebIcons)
            }
            .task {
                await store.perform(.streamSyncComplete)
            }
            .toast(
                store.binding(
                    get: \.toast,
                    send: VaultGroupAction.toastShown,
                ),
            )
    }

    // MARK: Private

    /// All cipher items currently shown (not searching).
    private var allItems: [VaultListItem] {
        guard case let .data(sections) = store.state.loadingState else { return [] }
        return sections.flatMap(\.items)
    }

    /// "N Items" under the title, like Apple Passwords. While the first stream value is on its way the count of the
    /// row that opened the page stands in, so the title block has its final layout from the first frame.
    private var itemCountSubtitle: String? {
        guard !store.state.isSearching, let count = store.state.displayedItemCount, count > 0 else { return nil }
        return Localizations.xItems(count).replacingOccurrences(of: "item", with: "Item")
    }

    /// The selected items.
    private var selectedItems: [VaultListItem] {
        allItems.filter { store.state.selection.contains($0.id) }
    }

    /// Select / Done and, in Select mode, Move and Delete.
    @ToolbarContentBuilder private var selectToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            selectBarContent
        }
    }

    @ViewBuilder private var selectBarContent: some View {
        if !store.state.isSearching, (store.state.displayedItemCount ?? 0) > 0, !isCipherlessGroup {
            PassYSelectModeButtons(
                isSelecting: isSelecting,
                selectionIsEmpty: store.state.selection.isEmpty,
                moveIsDisabled: store.state.group == .trash,
                folders: store.state.folders,
                move: { folderId in
                    let items = selectedItems
                    Task { await store.perform(.moveItems(items, folderId: folderId)) }
                },
                delete: {
                    let items = selectedItems
                    // Select mode stays: the processor ends it after a complete delete, keeps failed items
                    // selected, and a cancelled confirmation changes nothing.
                    Task { await store.perform(.deleteItems(items)) }
                },
                toggle: { store.send(.setSelecting(!isSelecting)) },
            )
        }
    }

    /// Groups made only of non-cipher rows (e.g. verification codes) have no Select mode.
    private var isCipherlessGroup: Bool {
        guard case .data = store.state.loadingState else { return store.state.group == .totp }
        return !allItems.contains { if case .cipher = $0.itemType { true } else { false } }
    }

    /// The "+" menu of the persistent bottom bar for this group.
    private var addEntries: [PassYAddEntry] {
        guard let type = store.state.newItemButtonType else { return [] }
        switch type {
        case .button:
            return [PassYAddEntry(
                id: "group-add",
                action: { store.send(.addItemPressed(nil)) },
                symbol: "plus",
                title: store.state.addItemButtonTitle,
            )]
        case .menu:
            return store.state.itemTypesUserCanCreate.passYAddMenuOrdered.map { type in
                PassYAddEntry(
                    id: "type-\(type.hashValue)",
                    action: { store.send(.addItemPressed(type)) },
                    symbol: type.passYAddMenuSymbol,
                    title: type.localizedName,
                )
            }
        }
    }

    /// The action card for Premium subscription ended for archive.
    @ViewBuilder private var archivePremiumSubscriptionEndedCard: some View {
        if store.state.showArchivePremiumSubscriptionEndedCard {
            ActionCard(
                title: Localizations.yourPremiumSubscriptionEnded,
                message: Localizations.yourPremiumSubscriptionEndedArchiveDescriptionLong,
                actionButtonState: ActionCard.ButtonState(title: Localizations.restartPremium) {
                    store.send(.restartPremiumSubscription)
                },
            )
        }
    }

    /// The group list stays alive from the first frame (no spinner, no swap of scroll views: the large title stays
    /// bound to the same list); the search list only exists while searching, on top of the hidden group list.
    @ViewBuilder private var content: some View {
        ZStack {
            groupList
                .opacity(store.state.isSearching ? 0 : 1)
                .allowsHitTesting(!store.state.isSearching)
                .accessibilityHidden(store.state.isSearching)

            if store.state.isSearching {
                searchContent
            }
        }
            .readableContentWidth(760)
            // The verification codes page has one shared countdown ring (rows with its period show none).
            .environment(\.passYSharedCountdownPeriod, sharedCodePeriod)
            // One countdown clock for all code rows of the page (verification codes and their search results).
            .passYCountdownClock(timeProvider: timeProvider, isActive: store.state.group == .totp)
            .onChange(of: store.state.url) { newValue in
                guard let url = newValue else { return }
                openURL(url)
                store.send(.clearURL)
            }
            .searchDebouncedTask(id: store.state.searchText) {
                await store.perform(.search(store.state.searchText))
            }
            .task {
                await store.perform(.search(store.state.searchText))
            }
            .onChange(of: store.state.searchVaultFilterType) { _ in
                Task { await store.perform(.search(store.state.searchText)) }
            }
            .animation(.default, value: store.state.isSearching)
    }

    /// A view that displays an empty state for this vault group.
    @ViewBuilder private var emptyView: some View {
        let group = store.state.group
        let title = store.state.noItemsTitle ?? (group == .totp ? "No \(Localizations.verificationCodes.lowercased())" : group.name)
        PassYEmptyState(
            title,
            systemImage: group.tileSymbol,
            message: store.state.noItemsString,
            identifier: "EmptyGroupTitle",
        ) {
            if let newItemButtonType = store.state.newItemButtonType {
                let newItemLabel = Label(store.state.addItemButtonTitle, systemImage: "plus")
                Group {
                    switch newItemButtonType {
                    case .button:
                        Button {
                            store.send(.addItemPressed(nil))
                        } label: {
                            newItemLabel
                        }
                    case .menu:
                        Menu {
                            ForEach(store.state.itemTypesUserCanCreate, id: \.hashValue) { type in
                                Button(type.localizedName, systemImage: type.passYAddMenuSymbol) {
                                    store.send(.addItemPressed(type))
                                }
                            }
                        } label: {
                            newItemLabel
                        }
                    }
                }
                .passYButtonStyle(.primary)
                .accessibilityIdentifier("AddItemButton")
            }
        }
    }

    /// A view that displays the search interface, including search results, an empty search
    /// interface, and a message indicating that no results were found.
    ///
    @ViewBuilder private var searchContent: some View {
        if store.state.searchText.isEmpty || !store.state.searchResults.isEmpty {
            List {
                // No section without a filter (members of no organization): an empty section drew an empty card.
                if !store.state.vaultFilterState.vaultFilterOptions.isEmpty {
                    Section {
                        searchVaultFilterRow
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section {
                    ForEach(store.state.searchResults) { item in
                        swipeableRow(for: item)
                    }
                }
            }
            // Rebuilt when the set of result rows changes (see the home search results: the incremental diff crashed).
            .id(store.state.searchResults.map(\.id))
            .passYCardList()
        } else {
            SearchNoResultsView {
                searchVaultFilterRow
            }
        }
    }

    /// Displays the vault filter for search row if the user is a member of any org.
    ///
    private var searchVaultFilterRow: some View {
        SearchVaultFilterRowView(
            hasDivider: false, store: store.child(
                state: \.vaultFilterState,
                mapAction: { action in
                    switch action {
                    case let .searchVaultFilterChanged(type):
                        .searchVaultFilterChanged(type)
                    }
                },
                mapEffect: nil,
            ),
        )
    }

    // MARK: Private Methods

    /// The list of the sections within this vault group: a native inset-grouped list like the vault home (each section
    /// a rounded card on the grouped background) with system row separators aligned to the item name. It exists from
    /// the first frame; until the first stream value arrives it is empty (no spinner), and an empty group shows its
    /// message on top of it.
    private var groupList: some View {
        List(selection: store.binding(get: \.selection, send: VaultGroupAction.selectionChanged)) {
            if store.state.showArchivePremiumSubscriptionEndedCard {
                archivePremiumSubscriptionEndedCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if case let .data(sections) = store.state.loadingState {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            swipeableRow(for: item)
                        }
                    } header: {
                        if itemCountSubtitle == nil, !section.name.isEmpty {
                            PassYSectionHeader(section.name)
                        }
                    }
                }
            }
        }
        .passYCardList()
        .overlay {
            if case .data([]) = store.state.loadingState {
                emptyView
                    .passYEmptyListState()
            }
        }
        .passYSelectEditMode(isSelecting: isSelecting, listIsEditing: $listIsEditing)
        .passYSharedCountdown(
            period: sharedCodePeriod,
            subtitle: itemCountSubtitle,
            isCompact: store.state.isSearching,
        )
    }

    /// The period of the verification codes page's shared countdown ring: the one most codes use (30 s until the
    /// codes are loaded), `nil` on other pages and on an empty codes page.
    private var sharedCodePeriod: Int? {
        guard store.state.group == .totp else { return nil }
        if case .data([]) = store.state.loadingState { return nil }
        let periods = allItems.compactMap { item -> Int? in
            guard case let .totp(_, model) = item.itemType else { return nil }
            return Int(model.totpCode.period)
        }
        return PassYSharedCountdown.dominantPeriod(periods)
    }

    /// A list row for the item with its selection tag and swipe actions (Delete, More menu).
    ///
    /// - Parameter item: The `VaultListItem` to show.
    ///
    private func swipeableRow(for item: VaultListItem) -> some View {
        vaultItemRow(for: item)
            .tag(item.id)
            .passYVaultRow(
                item,
                hasPremium: store.state.hasPremium,
                delete: { Task { await store.perform(.deleteItems([item])) } },
                perform: { kind in Task { await store.perform(.accessibilityMoreOptionsActionPressed(item, kind)) } },
            )
    }

    /// Creates a row in the list for the provided item.
    ///
    /// - Parameters:
    ///   - item: The `VaultListItem` to use when creating the view.
    ///
    private func vaultItemRow(for item: VaultListItem) -> some View {
        let state = store.state
        return VaultListRowCell.make(
            for: item,
            isSelecting: listIsEditing,
            iconBaseURL: state.iconBaseURL,
            hasPremium: state.hasPremium,
            showWebIcons: state.showWebIcons,
            timeProvider: timeProvider,
            itemPressed: { [weak store] item in await store?.perform(.itemPressed(item)) },
            moreOptions: { [weak store] item, kind in
                await store?.perform(.accessibilityMoreOptionsActionPressed(item, kind))
            },
            copyTOTPCode: { [weak store] code in store?.send(.copyTOTPCode(code)) },
            deleteItem: { [weak store] item in Task { await store?.perform(.deleteItems([item])) } },
        )
        .equatable()
    }
}

// MARK: - Item count subtitle

extension View {
    /// Shows "N Items" under the navigation title (`navigationSubtitle`, like Apple Passwords).
    func passYItemCountSubtitle(_ text: String?) -> some View {
        navigationSubtitle(text ?? "")
    }
}

extension VaultListItem {
    /// Whether this row is a cipher (rather than a group or TOTP row).
    var isCipherItem: Bool {
        if case .cipher = itemType { return true }
        return false
    }
}

// MARK: Previews

#if DEBUG
#Preview("Loading") {
    NavigationView {
        VaultGroupView(
            store: Store(
                processor: StateProcessor(
                    state: VaultGroupState(
                        loadingState: .loading(nil),
                        searchVaultFilterType: .allVaults,
                        vaultFilterType: .allVaults,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Empty") {
    NavigationView {
        VaultGroupView(
            store: Store(
                processor: StateProcessor(
                    state: VaultGroupState(
                        loadingState: .data([]),
                        searchVaultFilterType: .allVaults,
                        vaultFilterType: .allVaults,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Logins") {
    NavigationView {
        VaultGroupView(
            store: Store(
                processor: StateProcessor(
                    state: VaultGroupState(
                        group: .login,
                        loadingState: .data(
                            [
                                .init(
                                    id: "Items",
                                    items: [
                                        .init(cipherListView: .fixture(
                                            id: "1",
                                            login: .fixture(
                                                username: "email@example.com",
                                            ),
                                            name: "Example",
                                        ))!,
                                        .init(cipherListView: .fixture(
                                            id: "2",
                                            login: .fixture(
                                                username: "email2@example.com",
                                            ),
                                            name: "Example 2",
                                        ))!,
                                    ],
                                    name: "Items",
                                ),
                            ],
                        ),
                        searchVaultFilterType: .allVaults,
                        vaultFilterType: .allVaults,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Trash") {
    NavigationView {
        VaultGroupView(
            store: Store(
                processor: StateProcessor(
                    state: VaultGroupState(
                        group: .trash,
                        loadingState: .data([]),
                        searchVaultFilterType: .allVaults,
                        vaultFilterType: .allVaults,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}
#endif
