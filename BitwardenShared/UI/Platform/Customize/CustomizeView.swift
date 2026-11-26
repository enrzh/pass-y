import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - CustomizeView

/// The Customize screen ("Anpassen"): the device's layout preferences of the vault home (tiles: show, order, layout;
/// sections: show, order, collapsed when opened), the list rows (density, user names, icons, website icons, badges,
/// tile colours) and the verification codes (digit grouping, countdown), with a live preview at the top and "Reset to
/// defaults" at the end. A plain grouped list of system controls; it edits `PassYLayoutStore` directly (local
/// preferences only, no processor). Reached from Settings and from the avatar menu ("Customize home…").
///
struct CustomizeView: View {
    // MARK: Properties

    /// The preferences being edited.
    let layout: PassYLayoutStore

    /// The existing "Show website icons" setting (reused, not duplicated).
    let webIcons: PassYWebIconsSetting

    /// Reordering of tiles and sections (drag handles).
    @SwiftUI.State private var editMode: EditMode = .inactive

    // MARK: View

    var body: some View {
        List {
            previewSection
            homeLayoutSection
            tilesSection
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
    }

    // MARK: Sections

    /// The live miniature of the home and a sample row with the current choices.
    private var previewSection: some View {
        Section {
            CustomizeHomePreview(layout: layout)
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        } header: {
            Text(Localizations.layoutPreview)
        } footer: {
            Text(Localizations.customizeDescription)
        }
    }

    /// The tile layout.
    private var homeLayoutSection: some View {
        Section {
            Picker(Localizations.tileLayout, selection: binding(\.home.tileLayout)) {
                Text(Localizations.tileLayoutCards).tag(PassYLayoutPreferences.TileLayout.grid)
                Text(Localizations.tileLayoutWideCards).tag(PassYLayoutPreferences.TileLayout.wide)
                Text(Localizations.tileLayoutList).tag(PassYLayoutPreferences.TileLayout.list)
            }
            .accessibilityIdentifier("CustomizeTileLayoutPicker")
        } header: {
            Text(Localizations.homeScreen)
        }
    }

    /// Show / hide and order of the tiles.
    private var tilesSection: some View {
        Section {
            ForEach(layout.preferences.orderedTiles, id: \.self) { id in
                let group = VaultListGroup(passYTileIdentifier: id)
                Toggle(isOn: tileBinding(id)) {
                    Label {
                        Text(group?.name ?? id)
                    } icon: {
                        PassYIconTile(
                            systemImage: group?.tileSymbol ?? "square",
                            tint: group?.tileColor ?? .gray,
                            size: PassYDesign.IconSize.small,
                        )
                    }
                }
                .accessibilityIdentifier("CustomizeTileToggle_\(id)")
            }
            .onMove { source, destination in
                layout.preferences.moveTiles(fromOffsets: source, toOffset: destination)
            }
        } header: {
            reorderHeader(Localizations.tiles)
        } footer: {
            Text(Localizations.tilesFooter)
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
            Picker(Localizations.rowDensity, selection: binding(\.rows.density)) {
                Text(Localizations.densityComfortable).tag(PassYLayoutPreferences.Density.comfortable)
                Text(Localizations.densityCompact).tag(PassYLayoutPreferences.Density.compact)
            }
            .accessibilityIdentifier("CustomizeDensityPicker")
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
            Picker(Localizations.tileColors, selection: binding(\.rows.tileColors)) {
                Text(Localizations.tileColorsColorful).tag(PassYLayoutPreferences.TileColors.colorful)
                Text(Localizations.tileColorsMonochrome).tag(PassYLayoutPreferences.TileColors.monochrome)
            }
            .accessibilityIdentifier("CustomizeTileColorsPicker")
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
            Toggle(Localizations.countdownRing, isOn: binding(\.codes.showsCountdownRing))
                .accessibilityIdentifier("CustomizeCountdownRingToggle")
            Toggle(Localizations.countdownSeconds, isOn: binding(\.codes.showsCountdownSeconds))
                .accessibilityIdentifier("CustomizeCountdownSecondsToggle")
        } header: {
            Text(Localizations.verificationCodes)
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

    /// Whether a tile is shown on the home.
    private func tileBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { layout.preferences.isTileVisible(id) },
            set: { layout.preferences.setTile(id, visible: $0) },
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
        case "Favorites": Localizations.favorites
        case "Folders": Localizations.myFolders
        case "NoFolder": Localizations.folderNone
        case "Collections": Localizations.sharedFolders
        default: id
        }
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
