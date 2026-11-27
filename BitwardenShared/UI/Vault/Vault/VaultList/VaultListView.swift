// swiftlint:disable file_length

import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - SearchableVaultListView

/// The main view of the vault.
private struct SearchableVaultListView: View {
    // MARK: Properties

    /// A flag indicating if the search bar is focused.
    var isSearching: Bool

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The memoized tile/section split of the vault data.
    @SwiftUI.State private var splitCache = TileSplitCache()

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultListState, VaultListAction, VaultListEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    /// Whether the search results list is in edit mode (follows `isSelecting`, delayed when leaving).
    @SwiftUI.State private var listIsEditing = false

    /// The folders and move handlers of the rows' "Move to folder" menus.
    @SwiftUI.State private var folderMove = VaultFolderMove()

    /// The layout preferences (Customize). Applied inside the equatable boundaries (home list, search list), so a
    /// change of unrelated state never re-applies them; the home slice is part of the home list key.
    let layoutStore: PassYLayoutStore

    /// The home slice of the Customize preferences (cards, rows, sections, card colours).
    private var homeLayout: PassYLayoutPreferences.Home { layoutStore.home }

    var body: some View {
        // A ZStack with hidden children is used here so that opening and closing the
        // search interface does not reset the scroll position for the main vault
        // view, as would happen if we used an `if else` block here.
        //
        // Additionally, we cannot use an `.overlay()` on the main vault view to contain
        // the search interface since VoiceOver still reads the elements below the overlay,
        // which is not ideal.

        ZStack {
            let isSearching = isSearching
                || !store.state.searchText.isEmpty
                || !store.state.searchResults.isEmpty

            vault
                .hidden(isSearching)

            // ui-r8: the search list only exists while searching. Two scroll views in one screen confuse UIKit's
            // choice of the content scroll view for the large title, and the hidden one still diffed every change.
            if isSearching {
                search
                    .passYLayoutEnvironment(layoutStore)
            }
        }
        .animation(.easeInOut, value: store.state.organizationUserNotificationBannerData)
        .vaultFolderMove(
            folderMove,
            folders: store.state.folders,
            move: { [weak store] item, folderId in
                Task { await store?.perform(.moveItemToFolder(item, folderId: folderId)) }
            },
            moveToNewFolder: { [weak store] item in Task { await store?.perform(.moveItemToNewFolder(item)) } },
        )
        .background(SharedAsset.Colors.backgroundPrimary.swiftUIColor.ignoresSafeArea())
        .toast(
            store.binding(
                get: \.toast,
                send: VaultListAction.toastShown,
            ),
        )
        .flightRecorderToastBanner(
            activeLog: store.state.flightRecorderToastBanner.activeLog,
            additionalBottomPadding: FloatingActionButton.bottomOffsetPadding,
            isVisible: store.bindingAsync(
                get: \.flightRecorderToastBanner.isToastBannerVisible,
                perform: { _ in .dismissFlightRecorderToastBanner },
            ),
            goToSettingsAction: {
                store.send(.navigateToFlightRecorderSettings)
            },
        )
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearURL)
        }
        .animation(.default, value: isSearching)
    }

    // MARK: Private Properties

    /// A view that displays the empty vault interface: a list with the action card and the vault filter (if any), the
    /// empty state below them on the page background.
    @ViewBuilder private var emptyVault: some View {
        List {
            actionCardSection

            if !store.state.vaultFilterState.vaultFilterOptions.isEmpty {
                Section {
                    vaultFilterRow
                }
            }

            Section {
                PassYEmptyState(
                    Localizations.saveAndProtectYourData,
                    systemImage: "lock.shield",
                    message: Localizations
                        .theVaultProtectsMoreThanJustPasswordsStoreSecureLoginsIdsCardsAndNotesSecurelyHere,
                ) {
                    Button(Localizations.addLogin, systemImage: "plus") {
                        store.send(.addItemPressed(.login))
                    }
                    .passYButtonStyle(.primary)
                }
                .padding(.top, PassYDesign.Spacing.xLarge)
                .passYPlainListRow()
            }
        }
        .passYCardList()
        .animation(.easeInOut, value: store.state.importLoginsSetupProgress == .setUpLater)
        .animation(.easeInOut, value: store.state.importLoginsSetupProgress == .complete)
    }

    /// A view that displays the search interface, including search results, an empty search
    /// interface, and a message indicating that no results were found.
    @ViewBuilder private var search: some View {
        if store.state.searchText.isEmpty || !store.state.searchResults.isEmpty {
            List(selection: store.binding(get: \.selection, send: VaultListAction.selectionChanged)) {
                // No section without a filter (members of no organization): an empty section drew an empty card.
                if !store.state.searchVaultFilterState.vaultFilterOptions.isEmpty {
                    Section {
                        searchVaultFilterRow
                    }
                }

                Section {
                    ForEach(store.state.searchResults) { item in
                        swipeableRow(for: item)
                            .tag(item.id)
                    }
                }
            }
            // The list is rebuilt when the set of result rows changes (a delete removes rows while Select mode is on):
            // SwiftUI's incremental list diff crashed there ("Invalid number of items in section", reproducible).
            .id(store.state.searchResults.map(\.id))
            .passYSelectEditMode(isSelecting: store.state.isSelecting, listIsEditing: $listIsEditing)
            .passYCardList()
            // Code rows among the results count down from one clock (only while the search list exists).
            .passYCountdownClock(timeProvider: timeProvider)
        } else {
            SearchNoResultsView {
                searchVaultFilterRow(isCard: true)
            }
        }
    }

    /// Displays the vault filter for search row if the user is a member of any org.
    private var searchVaultFilterRow: some View {
        searchVaultFilterRow(isCard: false)
    }

    /// Displays the vault filter for search row if the user is a member of any org.
    ///
    /// - Parameter isCard: Whether the row draws its own card (outside a list).
    ///
    private func searchVaultFilterRow(isCard: Bool) -> some View {
        SearchVaultFilterRowView(
            hasDivider: false, isCard: isCard, store: store.child(
                state: \.searchVaultFilterState,
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

    /// A view that displays either the my vault or empty vault interface.
    ///
    /// ui-r8: wrapped in an `Equatable` boundary. Changes that do not touch what the vault list shows (toast, search
    /// text and results, bottom bar, profile menu, selection) no longer re-evaluate the list and its rows.
    @ViewBuilder private var vault: some View {
        EquatableContent(key: HomeContentKey(state: store.state.homeListKey, layout: homeLayout)) {
            LoadingView(state: store.state.loadingState) { sections in
                if sections.isEmpty {
                    emptyVault
                } else {
                    vaultContents(with: sections)
                        .readableContentWidth(760)
                        .passYLayoutEnvironment(layoutStore)
                }
            } errorView: { errorMessage in
                errorViewWithRetry(errorMessage: errorMessage)
            }
        }
        .equatable()
    }

    /// Displays the vault filter row if the user is a member of any.
    private var vaultFilterRow: some View {
        SearchVaultFilterRowView(
            hasDivider: false,
            store: store.child(
                state: \.vaultFilterState,
                mapAction: { action in
                    switch action {
                    case let .searchVaultFilterChanged(type):
                        .vaultFilterChanged(type)
                    }
                },
                mapEffect: nil,
            ),
        )
    }

    // MARK: Private Methods

    /// A view that displays an error message and a retry button.
    ///
    /// - Parameter errorMessage: The error message to display.
    ///
    @ViewBuilder
    private func errorViewWithRetry(errorMessage: String) -> some View {
        PassYEmptyState(errorMessage, systemImage: "exclamationmark.triangle") {
            AsyncButton {
                await store.perform(.tryAgainTapped)
            } label: {
                Text(Localizations.tryAgain)
            }
            .passYButtonStyle(.primary)
        }
        .passYEmptyListState()
    }

    /// The vault as a native inset-grouped `List`: action card, vault filter, category tiles and one collapsible section per
    /// group of items. Rows get a "More" swipe action and pointer hover. The tiles and the item sections are
    /// `Equatable` subviews: a change that does not touch the vault data (toast, search text, bar) does not diff
    /// the (up to thousands of) rows again.
    ///
    /// - Parameter sections: The sections of the vault list to display.
    ///
    @ViewBuilder
    private func vaultContents(with sections: [VaultListSection]) -> some View {
        let (tileItems, listSections) = splitCache.split(sections)
        let home = PassYHomeArrangement(tiles: tileItems, sections: listSections, layout: homeLayout)
        List {
            actionCardSection

            if !store.state.vaultFilterState.vaultFilterOptions.isEmpty {
                Section {
                    vaultFilterRow
                }
            }

            if !home.cards.isEmpty {
                Section {
                    CategoryTilesView(
                        items: home.cards,
                        colors: homeLayout.cardColors,
                        onSelect: { item in Task { await store.perform(.itemPressed(item)) } },
                        menu: { item in cardMenu(for: item, cards: home.cardIds) },
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(home.sections) { section in
                collapsibleSection(section)
            }

            // Customize: the rows of hidden sections stay one tap away (never a dead end).
            if let more = home.more {
                collapsibleSection(more)
            }
        }
        .passYCardList()
    }

    /// A home section with the collapse chevron of its header (the collapsed state persists per account).
    @ViewBuilder
    private func collapsibleSection(_ section: VaultListSection) -> some View {
        let isExpanded = !store.state.collapsedSectionIds.contains(section.id)
        Section {
            if isExpanded {
                ForEach(section.items) { item in
                    homeRow(for: item)
                }
            }
        } header: {
            PassYSectionHeader(
                section.name,
                count: section.items.count,
                countLabel: Localizations.xItems(section.items.count),
                isExpanded: isExpanded,
                identifier: "SectionExpandButton_\(section.id)",
            ) {
                store.send(.sectionExpandToggled(sectionId: section.id, isExpanded: !isExpanded))
            }
        }
    }

    /// A row of the home: home elements (type rows, folders) get the long-press menu of the home (show as card,
    /// Customize…); other rows are the plain list row.
    @ViewBuilder
    private func homeRow(for item: VaultListItem) -> some View {
        if item.isPassYHomeElement {
            swipeableRow(for: item)
                .contextMenu { rowMenu(for: item) }
        } else {
            swipeableRow(for: item)
        }
    }

    /// The long-press menu of a card: move it among the cards, show it as a folder row, open Customize.
    @ViewBuilder
    private func cardMenu(for item: VaultListItem, cards: [String]) -> some View {
        let id = item.passYHomeElementId
        Section {
            ForEach(PassYLayoutPreferences.CardMove.allCases, id: \.self) { move in
                if PassYLayoutPreferences.canMove(id, move, among: cards) {
                    Button {
                        withAnimation(.snappy) { layoutStore.preferences.moveCard(id, move, among: cards) }
                    } label: {
                        Label(move.passYTitle, systemImage: move.passYSymbol)
                    }
                    .accessibilityIdentifier("HomeCardMove_\(move)")
                }
            }
        }
        Section {
            Button {
                withAnimation(.snappy) { layoutStore.preferences.setCard(id, false) }
            } label: {
                Label(Localizations.showAsFolderRow, systemImage: "list.bullet")
            }
            .accessibilityIdentifier("HomeShowAsRowButton")
        }
        customizeMenuSection
    }

    /// The long-press menu of a type or folder row: show it as a card, open Customize.
    @ViewBuilder
    private func rowMenu(for item: VaultListItem) -> some View {
        let id = item.passYHomeElementId
        Section {
            Button {
                withAnimation(.snappy) { layoutStore.preferences.setCard(id, true) }
            } label: {
                Label(Localizations.showAsCard, systemImage: "square.grid.2x2")
            }
            .accessibilityIdentifier("HomeShowAsCardButton")
        }
        customizeMenuSection
    }

    /// The separated "Customize…" entry of the home menus.
    private var customizeMenuSection: some View {
        Section {
            Button {
                store.send(.customizePressed)
            } label: {
                Label(Localizations.customizeEllipsis, systemImage: "slider.horizontal.3")
            }
            .accessibilityIdentifier("HomeCustomizeButton")
        }
    }

    /// A list row for the item with its swipe actions (Delete, More menu).
    ///
    /// - Parameter item: The `VaultListItem` to show.
    ///
    private func swipeableRow(for item: VaultListItem) -> some View {
        vaultItemRow(for: item)
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
    @ViewBuilder
    private func vaultItemRow(for item: VaultListItem) -> some View {
        VaultListRowCell.make(
            for: item,
            isSelecting: listIsEditing,
            store: store,
            timeProvider: timeProvider,
        )
        .equatable()
    }
}

// MARK: - VaultListRowCell + factory

extension VaultListRowCell {
    /// Creates a row of the vault, group or search list. No child `Store` is created: the row gets plain state and
    /// closures (ui-r8), so its body is skipped when nothing it shows changed.
    ///
    /// - Parameters:
    ///   - item: The row's item.
    ///   - isSelecting: Whether the list is in Select mode.
    ///   - iconBaseURL: The base URL of the web icons.
    ///   - hasPremium: Whether the account has Premium.
    ///   - showWebIcons: Whether web icons are shown.
    ///   - timeProvider: The `TimeProvider` used to calculate TOTP expiration.
    ///   - itemPressed: Opens the item.
    ///   - moreOptions: Performs one of the item's more-options actions.
    ///   - copyTOTPCode: Copies a TOTP code.
    ///   - deleteItem: Starts the (confirmed) delete of the item (offered for cipher rows only).
    ///
    @MainActor
    static func make( // swiftlint:disable:this function_parameter_count
        for item: VaultListItem,
        isSelecting: Bool,
        iconBaseURL: URL?,
        hasPremium: Bool,
        showWebIcons: Bool,
        timeProvider: any TimeProvider,
        itemPressed: @escaping (VaultListItem) async -> Void,
        moreOptions: @escaping (VaultListItem, MoreOptionsActionKind) async -> Void,
        copyTOTPCode: @escaping (String) -> Void,
        deleteItem: @escaping (VaultListItem) -> Void,
    ) -> VaultListRowCell {
        #if DEBUG
        PassYPerf.rowBuildCount += 1
        #endif
        return VaultListRowCell(
            state: VaultListItemRowState(
                iconBaseURL: iconBaseURL,
                hasPremium: hasPremium,
                isFromExtension: false,
                isSelecting: isSelecting,
                item: item,
                // Lists use the system row separators (aligned to the name by the row).
                hasDivider: false,
                showWebIcons: showWebIcons,
            ),
            perform: { effect in
                switch effect {
                case let .accessibilityMoreOptionsActionPressed(kind):
                    // A code row's options (Edit) act on its cipher.
                    await moreOptions(item.totpCipherItem ?? item, kind)
                case .pressed:
                    await itemPressed(item)
                }
            },
            send: { action in
                switch action {
                case let .copyTOTPCode(code):
                    copyTOTPCode(code)
                }
            },
            timeProvider: timeProvider,
            onDelete: item.isCipherItem ? { deleteItem(item) } : nil,
        )
    }

    /// Creates a row of the vault home or its search results.
    @MainActor
    static func make(
        for item: VaultListItem,
        isSelecting: Bool = false,
        store: Store<VaultListState, VaultListAction, VaultListEffect>,
        timeProvider: any TimeProvider,
    ) -> VaultListRowCell {
        let state = store.state
        return make(
            for: item,
            isSelecting: isSelecting,
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
    }
}

// MARK: - EquatableContent

/// A view whose body is only evaluated again when `key` changes (the closure is ignored by `==`).
struct EquatableContent<Key: Equatable, Content: View>: View, Equatable {
    /// What the content depends on.
    let key: Key

    /// The content.
    @ViewBuilder let content: () -> Content

    static func == (lhs: EquatableContent, rhs: EquatableContent) -> Bool { lhs.key == rhs.key }

    var body: some View { content() }
}

// MARK: - VaultListState + home list key

extension VaultListState {
    /// The state without everything the vault home list does not show. Two equal keys mean the same list.
    var homeListKey: VaultListState {
        var key = self
        key.flightRecorderToastBanner = FlightRecorderToastBannerState()
        key.folders = []
        key.isEligibleForAppReview = false
        key.isSelecting = false
        key.itemTypesUserCanCreate = []
        key.profileSwitcherState = .empty()
        key.searchResults = []
        key.searchText = ""
        key.searchVaultFilterType = .allVaults
        key.selection = []
        key.toast = nil
        key.url = nil
        return key
    }
}

// MARK: - HomeContentKey

/// What the vault home list depends on: the list state and the home slice of the Customize preferences.
struct HomeContentKey: Equatable {
    let state: VaultListState
    let layout: PassYLayoutPreferences.Home
}

// MARK: - PassYHomeArrangement

/// The vault home after the Customize preferences: the cards (type tiles and the folders switched to cards) in the
/// user's order, the list sections in the user's order with the type tiles switched to folder rows in their own
/// section ("Types") and without the folders shown as cards, and the "More" section with the rows of hidden Types /
/// Folders / Shared folders sections. Nothing disappears: every element is a card or a row. Folder identifiers the
/// vault does not have (deleted, another account) are ignored. Default preferences give the tiles and sections
/// unchanged and no "More" section.
struct PassYHomeArrangement {
    /// The id of the "More" section (its collapsed state persists like the other sections').
    static let moreSectionId = "PassYMore"

    /// The id of the folders section of the vault list.
    static let foldersSectionId = "Folders"

    /// The sections whose rows (types, folders, collections) move to "More" when the section is hidden.
    static let sectionsKeptInMore: Set<String> = [
        PassYLayoutPreferences.typeRowsSectionId, foldersSectionId, "Collections",
    ]

    /// The cards shown on the home.
    let cards: [VaultListItem]

    /// The list sections shown on the home.
    let sections: [VaultListSection]

    /// The "More" section, `nil` when nothing is hidden.
    let more: VaultListSection?

    /// The element identifiers of the cards, in home order.
    var cardIds: [String] { cards.map(\.passYHomeElementId) }

    init(tiles: [VaultListItem], sections: [VaultListSection], layout: PassYLayoutPreferences.Home) {
        let preferences = PassYLayoutPreferences(home: layout)
        var listSections = sections
        var folderCards: [VaultListItem] = []
        if !layout.folderCards.isEmpty,
           let index = listSections.firstIndex(where: { $0.id == Self.foldersSectionId }) {
            let folders = listSections[index]
            folderCards = folders.items.filter { $0.isPassYHomeElement && preferences.isCard($0.passYHomeElementId) }
            if !folderCards.isEmpty {
                let cardIds = Set(folderCards.map(\.id))
                let rest = folders.items.filter { !cardIds.contains($0.id) }
                if rest.isEmpty {
                    listSections.remove(at: index)
                } else {
                    listSections[index] = VaultListSection(id: folders.id, items: rest, name: folders.name)
                }
            }
        }
        let split = preferences.partitionCards(tiles + folderCards, id: \.passYHomeElementId)
        cards = split.cards
        if !split.rows.isEmpty {
            listSections.insert(
                VaultListSection(id: PassYLayoutPreferences.typeRowsSectionId, items: split.rows, name: Localizations.types),
                at: 0,
            )
        }
        let sectionSplit = preferences.partitionSections(listSections, id: \.id)
        self.sections = sectionSplit.visible
        let moreItems = sectionSplit.hidden.filter { Self.sectionsKeptInMore.contains($0.id) }.flatMap(\.items)
        more = moreItems.isEmpty
            ? nil
            : VaultListSection(id: Self.moreSectionId, items: moreItems, name: Localizations.passYMore)
    }
}

extension VaultListItem {
    /// The Customize identifier of a home element (`VaultListGroup.passYHomeElementId`), the item id for other rows.
    var passYHomeElementId: String {
        if case let .group(group, _) = itemType, let id = group.passYHomeElementId { return id }
        return id
    }

    /// Whether the item is a home element (a type tile, a folder or "No folder"): a card or a folder row.
    var isPassYHomeElement: Bool {
        guard case let .group(group, _) = itemType else { return false }
        return group.passYHomeElementId != nil
    }
}

// MARK: - PassYLayoutPreferences.CardMove + menu

extension PassYLayoutPreferences.CardMove {
    /// The title of the move in the card menu.
    var passYTitle: String {
        switch self {
        case .toFront: Localizations.moveToFront
        case .earlier: Localizations.moveEarlier
        case .later: Localizations.moveLater
        case .toEnd: Localizations.moveToEnd
        }
    }

    /// The SF Symbol of the move.
    var passYSymbol: String {
        switch self {
        case .toFront: "arrow.up.to.line"
        case .earlier: "arrow.up"
        case .later: "arrow.down"
        case .toEnd: "arrow.down.to.line"
        }
    }
}

// MARK: - TileSplitCache

/// Splits the vault sections into category tile items and list sections once per data change. `Array` equality
/// short-circuits when both arrays share their storage, so an unchanged vault costs O(1) per body pass.
final class TileSplitCache {
    private var sections: [VaultListSection]?
    private var result: ([VaultListItem], [VaultListSection]) = ([], [])

    func split(_ new: [VaultListSection]) -> ([VaultListItem], [VaultListSection]) {
        if let sections, sections == new { return result }
        var tileItems: [VaultListItem] = []
        var listSections: [VaultListSection] = []
        for section in new {
            var rest: [VaultListItem] = []
            rest.reserveCapacity(section.items.count)
            for item in section.items {
                if case let .group(group, _) = item.itemType, group.isCategoryTile {
                    tileItems.append(item)
                } else {
                    rest.append(item)
                }
            }
            if rest.count == section.items.count {
                listSections.append(section)
            } else if !rest.isEmpty {
                listSections.append(VaultListSection(id: section.id, items: rest, name: section.name))
            }
        }
        sections = new
        result = (tileItems, listSections)
        return result
    }
}

// MARK: - Action Cards

extension SearchableVaultListView {
    /// The active action card as a list section, rendered based on priority. Only one card is shown at a time. The
    /// reachable cards are `PassYSetupSection`s; the Premium cards (unreachable in Pass-Y: the upgrade path is off)
    /// keep the legacy card.
    @ViewBuilder private var actionCardSection: some View {
        switch store.state.activeActionCard {
        case .importItems:
            PassYSetupSection(
                title: Localizations.importSavedLogins,
                message: Localizations.importSavedLoginsDescriptionLong,
                systemImage: "square.and.arrow.down.fill",
                tint: .blue,
                action: .init(title: Localizations.getStarted) {
                    store.send(.showImportLogins)
                },
                dismiss: .init(title: Localizations.dismiss) {
                    await store.perform(.dismissImportLoginsActionCard)
                },
            )
        case .introducingArchive:
            // Pass-Y does not show feature promotions.
            EmptyView()
        case let .organizationBanner(data):
            PassYSetupSection(
                title: data.headerText ?? data.description,
                message: data.headerText == nil ? nil : data.description,
                systemImage: "building.2.fill",
                tint: .indigo,
                action: data.buttonText.map { text in
                    PassYSetupSection.Row(title: text) {
                        await store.perform(.dismissOrganizationBanner(fromActionButton: true))
                    }
                },
                dismiss: data.buttonText == nil
                    ? PassYSetupSection.Row(title: Localizations.dismiss) {
                        await store.perform(.dismissOrganizationBanner(fromActionButton: false))
                    }
                    : nil,
            )
        case .subscriptionNeedsAttention, .upgradedToPremium, .upgradeNeeded:
            Section {
                legacyPremiumCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        case nil:
            EmptyView()
        }
    }

    /// The Premium cards (unreachable in Pass-Y, see `actionCardSection`).
    @ViewBuilder private var legacyPremiumCard: some View {
        switch store.state.activeActionCard {
        case .subscriptionNeedsAttention:
            ActionCard(
                title: Localizations.subscriptionNeedsAttention,
                message: Localizations.checkYourPlanForDetails,
                actionButtonState: ActionCard.ButtonState(title: Localizations.viewPlan) {
                    store.send(.viewPlan)
                },
            )
        case .upgradedToPremium:
            UpgradedToPremiumActionCardView(
                onDismiss: { await store.perform(.dismissUpgradedToPremiumActionCard) },
                onLearnMore: { store.send(.learnMoreAboutPremium) },
            )
        case .upgradeNeeded:
            ActionCard(
                title: Localizations.unlockAdvancedSecurityFeatures,
                message: Localizations.aPremiumPlanGivesYouMoreToolsDescriptionLong,
                actionButtonState: ActionCard.ButtonState(title: Localizations.learnMore) {
                    await store.perform(.upgradeToPremium)
                },
                dismissButtonState: ActionCard.ButtonState(title: Localizations.dismiss) {
                    await store.perform(.dismissPremiumUpgradeActionCard)
                },
            )
        default:
            EmptyView()
        }
    }
}

// MARK: - VaultListView

/// A view that allows the user to view a list of the items in their vault.
///
struct VaultListView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultListState, VaultListAction, VaultListEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    /// The window scene for requesting a review.
    var windowScene: UIWindowScene?

    /// The layout preferences (Customize) applied to the page.
    var layoutStore: PassYLayoutStore = .shared

    /// Task running the vault list stream, managed manually so it is cancelled and restarted when
    /// the vault filter type changes.
    @SwiftUI.State private var vaultListTask: Task<Void, Never>?

    /// The shell model that owns the persistent bottom search field.
    @ObservedObject private var shell = PassYShellModel.shared

    var body: some View {
        ZStack {
            SearchableVaultListView(
                isSearching: shell.isEditing || !store.state.searchText.isEmpty,
                store: store,
                timeProvider: timeProvider,
                layoutStore: layoutStore,
            )
            .passYSearchTarget(
                id: ObjectIdentifier(store),
                isPushed: false,
                text: store.state.searchText,
                entries: addEntries,
                setText: { store.send(.searchTextChanged($0)) },
                setSearching: { store.send(.searchStateChanged(isSearching: $0)) },
            )
            .autocorrectionDisabled(true)
            .searchDebouncedTask(id: store.state.searchText) {
                await store.perform(.search(store.state.searchText))
            }
            .task {
                await store.perform(.search(store.state.searchText))
            }
            .onChange(of: store.state.searchVaultFilterType) { _ in
                Task { await store.perform(.search(store.state.searchText)) }
            }
            // ui-r9-fix: no pull-to-refresh on the vault home. The system refresh control (a replicator layer in the
            // navigation bar) started on its own after unlocking and kept spinning for as long as the sync took (proved
            // with the animation dump: `_UIRefreshControlModernReplicatorView`, minutes under load); XCUITest then never
            // saw the app idle ("App animations complete notification not received"). Syncing stays available as
            // "Sync now" in the avatar menu (and happens on appearing, as before). Apple Passwords has no pull either.
        }
        .navigationBar(title: store.state.navigationTitle, titleDisplayMode: .large)
        .toolbar {
            searchSelectToolbar
            PassYAvatarToolbarItem()
        }
        .task {
            await store.perform(.refreshAccountProfiles)
        }
        .onAppear { publishProfileMenu() }
        .onChange(of: store.state.profileSwitcherState) { _ in publishProfileMenu() }
        .onChange(of: store.state.serverURL) { _ in publishProfileMenu() }
        .task {
            await store.perform(.appeared)
        }
        .task {
            await store.perform(.streamAccountSetupProgress)
        }
        .task {
            await store.perform(.streamFlightRecorderLog)
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
        .onAppear { restartVaultListStream() }
        .onChange(of: store.state.vaultFilterType) { _ in restartVaultListStream() }
        .onDisappear {
            vaultListTask?.cancel()
            vaultListTask = nil
            // Opening a result ends editing in the bottom search bar; the search text is kept and the bar
            // shows its cancel button.
            shell.isEditing = false
            NotificationCenter.default.post(name: .vaultSearchResign, object: nil)
        }
        .onAppear {
            Task {
                await store.perform(.checkAppReviewEligibility)
            }
        }
        .onDisappear {
            store.send(.disappeared)
        }
        .requestReview(isEligible: store.state.isEligibleForAppReview, windowScene: windowScene) {
            store.send(.appReviewPromptShown)
        }
    }

    // MARK: Private methods

    /// The search results that are selected in Select mode.
    private var selectedSearchItems: [VaultListItem] {
        store.state.searchResults.filter { store.state.selection.contains($0.id) }
    }

    /// Select / Done for the search results and, in Select mode, Move and Delete (like the group lists).
    @ToolbarContentBuilder private var searchSelectToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            if shell.isEditing || !store.state.searchText.isEmpty,
               store.state.searchResults.contains(where: \.isCipherItem) {
                PassYSelectModeButtons(
                    isSelecting: store.state.isSelecting,
                    selectionIsEmpty: store.state.selection.isEmpty,
                    folders: store.state.folders,
                    move: { folderId in
                        let items = selectedSearchItems
                        Task { await store.perform(.moveItems(items, folderId: folderId)) }
                    },
                    delete: {
                        let items = selectedSearchItems
                        Task { await store.perform(.deleteItems(items)) }
                    },
                    toggle: { store.send(.setSelecting(!store.state.isSelecting)) },
                )
            }
        }
    }

    /// The "+" menu of the persistent bottom bar: the item types and a folder.
    private var addEntries: [PassYAddEntry] {
        var entries = store.state.itemTypesUserCanCreate.passYAddMenuOrdered.map { type in
            PassYAddEntry(
                id: "type-\(type.hashValue)",
                action: { store.send(.addItemPressed(type)) },
                symbol: type.passYAddMenuSymbol,
                title: type.localizedName,
            )
        }
        entries.append(PassYAddEntry(
            id: "folder",
            action: { store.send(.addFolder) },
            dividerBefore: true,
            symbol: "folder",
            title: Localizations.folder,
        ))
        return entries
    }

    /// Publishes the accounts and actions for the avatar menu that every top-level screen shows.
    private func publishProfileMenu() {
        let state = store.state.profileSwitcherState
        shell.profileMenu = PassYProfileMenuSource(
            activeProfile: state.activeAccountProfile,
            canLock: state.allowLockAndLogout && state.activeAccountProfile?.canBeLocked == true,
            lock: { account in Task { await store.perform(.profileSwitcher(.accessibility(.lock(account)))) } },
            pendingRequests: { store.send(.pendingLoginRequestsTapped) },
            serverURL: store.state.serverURL,
            showsPlaceholder: state.showPlaceholderToolbarIcon,
            sync: { Task { await store.perform(.refreshVault) } },
        )
    }

    // MARK: Private Methods

    /// Cancels the current vault list stream task and starts a new one for the active vault filter.
    private func restartVaultListStream() {
        vaultListTask?.cancel()
        vaultListTask = Task { await store.perform(.streamVaultList) }
    }
}

// MARK: Previews

#if DEBUG

#Preview("Loading") {
    NavigationView {
        VaultListView(
            store: Store(processor: StateProcessor(state: VaultListState())),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Error") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .error(
                            errorMessage: Localizations.weCouldntSyncYourVaultWithTheServerDescriptionLong,
                        ),
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Empty") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(loadingState: .data([])),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Empty - Import Logins") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        importLoginsSetupProgress: .incomplete,
                        loadingState: .data([]),
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Empty - Subscription Attention") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([]),
                        shouldShowSubscriptionAttentionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        name: "Example 2",
                                        type: .secureNote,
                                    ))!,
                                ],
                                name: "Favorites",
                            ),
                            VaultListSection(
                                id: "2",
                                items: [
                                    VaultListItem(id: "21", itemType: .group(.login, 123)),
                                    VaultListItem(id: "22", itemType: .group(.card, 25)),
                                    VaultListItem(id: "23", itemType: .group(.identity, 1)),
                                    VaultListItem(id: "24", itemType: .group(.secureNote, 0)),
                                    VaultListItem(id: "25", itemType: .group(.sshKey, 4)),
                                ],
                                name: "Types",
                            ),
                        ]),
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Upgraded to Premium") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    VaultListItem(id: "11", itemType: .group(.login, 42)),
                                    VaultListItem(id: "12", itemType: .group(.card, 5)),
                                ],
                                name: "Types",
                            ),
                        ]),
                        shouldShowUpgradedToPremiumActionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Upgrade to Premium") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    VaultListItem(id: "11", itemType: .group(.login, 42)),
                                    VaultListItem(id: "12", itemType: .group(.card, 5)),
                                ],
                                name: "Types",
                            ),
                        ]),
                        shouldShowPremiumUpgradeActionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Introducing Archive") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    VaultListItem(id: "11", itemType: .group(.login, 42)),
                                    VaultListItem(id: "12", itemType: .group(.card, 5)),
                                ],
                                name: "Types",
                            ),
                        ]),
                        shouldShowArchiveOnboardingActionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Subscription Attention") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    VaultListItem(id: "11", itemType: .group(.login, 42)),
                                    VaultListItem(id: "12", itemType: .group(.card, 5)),
                                ],
                                name: "Types",
                            ),
                        ]),
                        shouldShowArchiveOnboardingActionCard: true,
                        shouldShowSubscriptionAttentionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Collections") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "Collections",
                                items: [
                                    VaultListItem(
                                        id: "31",
                                        itemType: .group(
                                            .collection(id: "", name: "Design", organizationId: "1"),
                                            0,
                                        ),
                                    ),
                                    VaultListItem(
                                        id: "32",
                                        itemType: .group(
                                            .collection(id: "", name: "Engineering", organizationId: "1"),
                                            2,
                                        ),
                                    ),
                                ],
                                name: "Collections",
                            ),
                            VaultListSection(
                                id: "CollectionItems",
                                items: [
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                ],
                                name: "Items",
                            ),
                        ]),
                        organizations: [
                            Organization(
                                enabled: true,
                                id: "",
                                isProviderUser: false,
                                key: nil,
                                keyConnectorEnabled: false,
                                keyConnectorUrl: nil,
                                name: "Org",
                                permissions: Permissions(),
                                status: .confirmed,
                                type: .user,
                                useEvents: false,
                                usePolicies: true,
                                userIsManagedByOrganization: false,
                                usersGetPremium: false,
                            ),
                        ],
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("1 Search Result") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        profileSwitcherState: ProfileSwitcherState(
                            accounts: [],
                            activeAccountId: nil,
                            allowLockAndLogout: true,
                            isVisible: false,
                        ),
                        searchResults: [
                            .init(cipherListView: .fixture(
                                id: UUID().uuidString,
                                login: .fixture(username: "email@example.com"),
                                name: "Example",
                                subtitle: "email@example.com",
                            ))!,
                        ],
                        searchText: "Exam",
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("3 Search Results") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        searchResults: [
                            .init(cipherListView: .fixture(
                                id: UUID().uuidString,
                                login: .fixture(username: "email@example.com"),
                                name: "Example",
                                subtitle: "email@example.com",
                            ))!,
                            .init(cipherListView: .fixture(
                                id: UUID().uuidString,
                                login: .fixture(username: "email2@example.com"),
                                name: "Example 2",
                                subtitle: "email2@example.com",
                            ))!,
                            .init(cipherListView: .fixture(
                                id: UUID().uuidString,
                                login: .fixture(username: "email3@example.com"),
                                name: "Example 3",
                                subtitle: "email3@example.com",
                            ))!,
                        ],
                        searchText: "Exam",
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("No Search Results") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        searchResults: [],
                        searchText: "Exam",
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Profile Switcher Visible: Single Account") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([]),
                        profileSwitcherState: .singleAccount,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Profile Switcher Visible: Multi Account") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([]),
                        profileSwitcherState: .dualAccounts,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}
#endif
