import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - CustomizeView

/// The Customize screen ("Anpassen"): the device's layout preferences of the vault home (card colours; every type and
/// folder as a card or a folder row, the order of the cards; sections: show, order, collapsed when opened), the list
/// rows (user names, icons, website icons, badges) and the verification codes (digit grouping), with a live preview at
/// the top and "Reset to defaults" at the end. A plain grouped list of system controls; it edits `PassYLayoutStore`
/// directly (local preferences only, no processor). Reached from Settings and from the long-press menus of the home.
///
struct CustomizeView: View {
    // MARK: Properties

    /// The preferences being edited.
    let layout: PassYLayoutStore

    /// The existing "Show website icons" setting (reused, not duplicated).
    let webIcons: PassYWebIconsSetting

    /// The folders of the vault (in memory while the screen is shown).
    var folders = PassYCustomizeFolders()

    /// Reordering of elements and sections (drag handles).
    @SwiftUI.State private var editMode: EditMode = .inactive

    // MARK: View

    var body: some View {
        List {
            previewSection
            cardColorsSection
            elementsSection
            sectionsSection
            collapsedSection
            rowsSection
            codesSection
            resetSection
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .navigationTitle(Localizations.customize)
        .navigationBarTitleDisplayMode(.inline)
        .task { await webIcons.load() }
        .task { await folders.load() }
    }

    // MARK: Sections

    /// The live miniature of the home and a sample row with the current choices.
    private var previewSection: some View {
        Section {
            CustomizeHomePreview(layout: layout, folders: folders.elements)
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        } header: {
            Text(Localizations.layoutPreview)
        } footer: {
            Text(Localizations.customizeDescription)
        }
    }

    /// The card colours.
    private var cardColorsSection: some View {
        Section {
            Picker(Localizations.tileColors, selection: binding(\.home.cardColors)) {
                Text(Localizations.tileColorsColorful).tag(PassYLayoutPreferences.CardColors.colorful)
                Text(Localizations.tileColorsFilled).tag(PassYLayoutPreferences.CardColors.filled)
            }
            .accessibilityIdentifier("CustomizeCardColorsPicker")
        } header: {
            Text(Localizations.homeScreen)
        } footer: {
            Text(Localizations.tileColorsFooter)
        }
    }

    /// Every type and folder: card or folder row, and the order of the cards.
    private var elementsSection: some View {
        Section {
            ForEach(layout.preferences.orderedElements(folders: folders.ids), id: \.self) { id in
                Toggle(isOn: cardBinding(id)) {
                    elementLabel(id)
                }
                .accessibilityIdentifier("CustomizeTileToggle_\(id)")
            }
            .onMove { source, destination in
                layout.preferences.moveElements(folders: folders.ids, fromOffsets: source, toOffset: destination)
            }
        } header: {
            reorderHeader(Localizations.showAsCards)
        } footer: {
            Text(Localizations.tilesFooter)
        }
    }

    /// The name and icon of a home element.
    @ViewBuilder
    private func elementLabel(_ id: String) -> some View {
        if let group = VaultListGroup(passYTileIdentifier: id) {
            Label {
                Text(group.name)
            } icon: {
                PassYIconTile(systemImage: group.tileSymbol, tint: group.tileColor, size: PassYDesign.IconSize.small)
            }
        } else {
            Label {
                Text(folders.name(of: id) ?? id)
            } icon: {
                PassYIconTile(systemImage: "folder.fill", tint: .blue, size: PassYDesign.IconSize.small)
            }
        }
    }

    /// Show / hide and order of the home sections.
    private var sectionsSection: some View {
        Section {
            ForEach(layout.preferences.orderedSections, id: \.self) { id in
                Toggle(Self.sectionName(id), isOn: sectionBinding(id))
                    .accessibilityIdentifier("CustomizeSectionToggle_\(id)")
            }
            .onMove { source, destination in
                layout.preferences.moveSections(fromOffsets: source, toOffset: destination)
            }
        } header: {
            Text(Localizations.homeSections)
        } footer: {
            Text(Localizations.homeSectionsFooter)
        }
    }

    /// The sections collapsed whenever the vault opens.
    private var collapsedSection: some View {
        Section {
            ForEach(layout.preferences.orderedSections, id: \.self) { id in
                Toggle(Self.sectionName(id), isOn: collapsedBinding(id))
                    .accessibilityIdentifier("CustomizeSectionCollapsed_\(id)")
            }
        } header: {
            Text(Localizations.collapsedWhenOpened)
        }
    }

    /// The look of list rows.
    private var rowsSection: some View {
        Section {
            Toggle(Localizations.showUserNames, isOn: binding(\.rows.showsSubtitle))
                .accessibilityIdentifier("CustomizeShowSubtitleToggle")
            Toggle(Localizations.showIconTiles, isOn: binding(\.rows.showsIcon))
                .accessibilityIdentifier("CustomizeShowIconToggle")
            Toggle(Localizations.showWebsiteIcons, isOn: Binding(
                get: { webIcons.isOn },
                set: { webIcons.set($0) },
            ))
            .disabled(!layout.rows.showsIcon)
            .accessibilityIdentifier("CustomizeShowWebIconsToggle")
            Toggle(Localizations.showFavoriteStar, isOn: binding(\.rows.showsFavoriteBadge))
                .accessibilityIdentifier("CustomizeFavoriteBadgeToggle")
            Toggle(Localizations.showSharedMark, isOn: binding(\.rows.showsSharedBadge))
                .accessibilityIdentifier("CustomizeSharedBadgeToggle")
            Toggle(Localizations.showAttachmentMark, isOn: binding(\.rows.showsAttachmentBadge))
                .accessibilityIdentifier("CustomizeAttachmentBadgeToggle")
        } header: {
            Text(Localizations.listsAndRows)
        } footer: {
            Text(Localizations.listsAndRowsFooter)
        }
    }

    /// The verification codes.
    private var codesSection: some View {
        Section {
            Toggle(Localizations.groupDigits, isOn: binding(\.codes.groupsDigits))
                .accessibilityIdentifier("CustomizeGroupDigitsToggle")
        } header: {
            Text(Localizations.verificationCodes)
        } footer: {
            Text(Localizations.groupDigitsFooter)
        }
    }

    /// Reset to defaults.
    private var resetSection: some View {
        Section {
            Button(Localizations.resetToDefaults, role: .destructive) {
                editMode = .inactive
                withAnimation { layout.reset() }
            }
            .disabled(layout.isDefault)
            .accessibilityIdentifier("CustomizeResetButton")
        }
    }

    /// A section title with the Reorder / Done button that turns the drag handles on and off.
    private func reorderHeader(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(editMode.isEditing ? Localizations.done : Localizations.reorder) {
                withAnimation { editMode = editMode.isEditing ? .inactive : .active }
            }
            .font(.subheadline.weight(.semibold))
            .textCase(nil)
            .accessibilityIdentifier("CustomizeReorderButton")
        }
    }

    // MARK: Bindings

    /// A binding to one preference.
    private func binding<Value>(_ keyPath: WritableKeyPath<PassYLayoutPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { layout.preferences[keyPath: keyPath] },
            set: { value in
                var preferences = layout.preferences
                preferences[keyPath: keyPath] = value
                layout.preferences = preferences
            },
        )
    }

    /// Whether a home element is a card (off: a folder row).
    private func cardBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { layout.preferences.isCard(id) },
            set: { layout.preferences.setCard(id, $0) },
        )
    }

    /// Whether a section is shown on the home.
    private func sectionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { layout.preferences.isSectionVisible(id) },
            set: { layout.preferences.setSection(id, visible: $0) },
        )
    }

    /// Whether a section is collapsed when the vault opens.
    private func collapsedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { layout.home.collapsedSections.contains(id) },
            set: { layout.preferences.setSection(id, collapsed: $0) },
        )
    }

    /// The display name of a home section.
    static func sectionName(_ id: String) -> String {
        switch id {
        case PassYLayoutPreferences.typeRowsSectionId: Localizations.types
        case "Favorites": Localizations.favorites
        case "Folders": Localizations.myFolders
        case "NoFolder": Localizations.folderNone
        case "Collections": Localizations.sharedFolders
        default: id
        }
    }
}

// MARK: - PassYCustomizeFolders

/// The top-level folders of the vault for Customize (identifier `folder:<id>` and name), read when the screen
/// appears and kept in memory only while it is shown. Nested folders are opened from their parent, so only top-level
/// folders can be cards (like the folder rows of the home).
@MainActor
@Observable
final class PassYCustomizeFolders {
    /// One folder.
    struct Element: Equatable, Sendable {
        let id: String
        let name: String
    }

    /// The folders, by name.
    private(set) var elements: [Element] = []

    /// The element identifiers of the folders.
    var ids: [String] { elements.map(\.id) }

    @ObservationIgnored private let read: () async -> [Element]

    /// Creates the folders of the app's vault repository.
    convenience init(vaultRepository: VaultRepository) {
        self.init {
            let folders = (try? await vaultRepository.fetchFolders()) ?? []
            return folders.asNestedNodes().rootNodes.compactMap { node in
                node.node.id.map { Element(id: VaultListGroup.folderElementPrefix + $0, name: node.name) }
            }
        }
    }

    /// Creates folders from a reader (previews and tests; default: none).
    init(elements: [Element] = [], read: @escaping () async -> [Element] = { [] }) {
        self.elements = elements
        self.read = read
    }

    /// Reads the folders.
    func load() async {
        let loaded = await read()
        if !loaded.isEmpty || elements.isEmpty { elements = loaded }
    }

    /// The name of a folder element.
    func name(of id: String) -> String? {
        elements.first { $0.id == id }?.name
    }
}

// MARK: - PassYWebIconsSetting

/// The existing app-wide "Show website icons" setting (`StateService`), so Customize shows the same switch value as
/// Settings › Appearance instead of a second preference.
@MainActor
@Observable
final class PassYWebIconsSetting {
    /// Whether website icons are shown.
    private(set) var isOn = true

    @ObservationIgnored private let read: () async -> Bool
    @ObservationIgnored private let write: (Bool) async -> Void

    /// Creates the setting on the app's state service.
    convenience init(stateService: StateService) {
        self.init(
            read: { await stateService.getShowWebIcons() },
            write: { await stateService.setShowWebIcons($0) },
        )
    }

    /// Creates the setting from a reader and a writer (previews and tests).
    init(isOn: Bool = true, read: @escaping () async -> Bool, write: @escaping (Bool) async -> Void) {
        self.isOn = isOn
        self.read = read
        self.write = write
    }

    /// Reads the stored value.
    func load() async {
        isOn = await read()
    }

    /// Changes the value and stores it.
    func set(_ value: Bool) {
        isOn = value
        Task { await write(value) }
    }
}

// MARK: - VaultListGroup + tile identifier

extension VaultListGroup {
    /// The home tile of a Customize tile identifier (`tileIdentifier`), `nil` for an unknown one.
    init?(passYTileIdentifier id: String) {
        switch id {
        case "archive": self = .archive
        case "bankAccount": self = .bankAccount
        case "card": self = .card
        case "driversLicense": self = .driversLicense
        case "identity": self = .identity
        case "login": self = .login
        case "passport": self = .passport
        case "secureNote": self = .secureNote
        case "sshKey": self = .sshKey
        case "totp": self = .totp
        case "trash": self = .trash
        default: return nil
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Customize") {
    NavigationStack {
        CustomizeView(
            layout: PassYLayoutStore(appSettingsStore: nil),
            webIcons: PassYWebIconsSetting(read: { true }, write: { _ in }),
        )
    }
}
#endif
