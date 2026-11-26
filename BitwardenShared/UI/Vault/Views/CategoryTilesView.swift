import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - CategoryTilesView

/// The cards at the top of the vault home (logins, cards, codes, trash, ... and the folders switched to cards), built
/// only from system fonts, SF Symbols and system colors, in adaptive columns (two on an iPhone, one at accessibility
/// sizes). A long press opens the card's menu (`menu`) from the card.
///
struct CategoryTilesView<MenuItems: View>: View {
    // MARK: Properties

    /// The group items to show as cards (type tiles, folders).
    let items: [VaultListItem]

    /// Forces a single column (used when the tiles are shown as a sidebar).
    var singleColumn = false

    /// The colours of the cards (Customize).
    var colors: PassYLayoutPreferences.CardColors = .colorful

    /// Called when a card is tapped.
    let onSelect: (VaultListItem) -> Void

    /// The long-press menu of a card, `nil` for none.
    var menu: ((VaultListItem) -> MenuItems)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// One column for accessibility text sizes so titles and counts are never truncated or wrapped mid-word.
    private var columns: [GridItem] {
        (dynamicTypeSize.isAccessibilitySize || singleColumn)
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.adaptive(minimum: 160), spacing: 12)]
    }

    // MARK: View

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                if case let .group(group, count) = item.itemType {
                    let open = {
                        #if DEBUG
                        PassYPerf.beginTap("tile")
                        #endif
                        CategoryTileHaptics.tapped()
                        onSelect(item)
                    }
                    Group {
                        if let menu {
                            // A menu button: a tap opens the card (primary action), a long press opens the card's menu
                            // from the card. A `contextMenu` cannot be used here: all cards share one list row, and a
                            // list row has one context menu (the first card's, measured).
                            Menu {
                                menu(item)
                            } label: {
                                CategoryTile(group: group, count: count, colors: colors)
                            } primaryAction: {
                                open()
                            }
                            .menuStyle(.button)
                            .menuOrder(.fixed)
                        } else {
                            Button(action: open) {
                                CategoryTile(group: group, count: count, colors: colors)
                            }
                            .accessibilityElement(children: .ignore)
                        }
                    }
                    .buttonStyle(CategoryTileButtonStyle())
                    .hoverEffect(.highlight)
                    .accessibilityLabel(group.name)
                    .accessibilityValue("\(count)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("CategoryTile_\(item.passYHomeElementId)")
                }
            }
        }
    }
}

extension CategoryTilesView where MenuItems == EmptyView {
    /// Cards without a long-press menu.
    init(
        items: [VaultListItem],
        singleColumn: Bool = false,
        colors: PassYLayoutPreferences.CardColors = .colorful,
        onSelect: @escaping (VaultListItem) -> Void,
    ) {
        self.init(items: items, singleColumn: singleColumn, colors: colors, onSelect: onSelect, menu: nil)
    }
}

// MARK: - CategoryTileHaptics

/// One prepared feedback generator: creating a generator per tap makes the first impact wait for the Taptic Engine.
@MainActor
private enum CategoryTileHaptics {
    private static let generator = UIImpactFeedbackGenerator(style: .light)

    static func tapped() {
        generator.impactOccurred()
        generator.prepare()
    }
}

// MARK: - CategoryTile

/// The corner radius of a tile (continuous, like the inset-grouped list cards below the tiles).
private let categoryTileCornerRadius: CGFloat = 22

/// One card: a symbol tile, the count and the title. Colourful: a white (dark: grouped) card with a tinted symbol
/// tile. Filled: the whole card in the type colour (`filledCardColor`, white content at 4.5:1 or more).
struct CategoryTile: View {
    let group: VaultListGroup
    let count: Int

    /// The colours of the card.
    var colors: PassYLayoutPreferences.CardColors = .colorful

    @Environment(\.colorScheme) private var colorScheme

    private var isFilled: Bool { colors == .filled }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                symbol
                Spacer(minLength: 4)
                countText
            }
            name
        }
        .padding(14)
        // Same height for every tile of a row (the shrinking long names measure a fraction of a point differently).
        .frame(minHeight: 96, alignment: .topLeading)
        .background(
            isFilled ? group.filledCardColor : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: categoryTileCornerRadius, style: .continuous),
        )
        .contentShape(RoundedRectangle(cornerRadius: categoryTileCornerRadius, style: .continuous))
    }

    /// A rounded-square symbol tile: a soft tint of the category color (the shape of the item icons in the lists), or
    /// a white symbol on a light veil of the filled card.
    private var symbol: some View {
        Image(systemName: group.tileSymbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(isFilled ? Color.white : group.tileSymbolColor(for: colorScheme))
            .frame(width: 36, height: 36)
            .background(
                isFilled ? Color.white.opacity(0.2) : group.tileColor.opacity(colorScheme == .dark ? 0.24 : 0.14),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous),
            )
            .accessibilityHidden(true)
    }

    /// The item count.
    private var countText: some View {
        Text(count, format: .number)
            .font(.system(.title, design: .rounded).weight(.bold))
            .monospacedDigit()
            // Empty categories step back, but not below 0.7 (a little darker than `.secondary`): the count must pass
            // the contrast audit on the white tile. Filled cards keep pure white (4.5:1 on every fill).
            .foregroundStyle(isFilled ? Color.white : Color.primary.opacity(count == 0 ? 0.7 : 0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    /// The category name.
    private var name: some View {
        Text(group.name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isFilled ? Color.white : Color.primary.opacity(0.7))
            .multilineTextAlignment(.leading)
            // One line, always: long names ("Verification codes") shrink instead of wrapping, so tiles in the same
            // row keep the same height. Accessibility sizes use a single column (see `columns`).
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - CategoryTileButtonStyle

/// The press state of a tile: it dims to the system fill and settles back with a short spring (no scale jump, no
/// shadow), like the cells of Apple's own grouped lists.
private struct CategoryTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: categoryTileCornerRadius, style: .continuous)
                    .fill(Color(.systemFill))
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

// MARK: - VaultListGroup tile style

extension VaultListGroup {
    /// Whether the group is shown as a category tile (as opposed to folders and collections, which are lists).
    var isCategoryTile: Bool {
        switch self {
        case .archive, .bankAccount, .card, .driversLicense, .identity, .login, .passport, .secureNote, .sshKey,
             .totp, .trash:
            true
        case .collection, .folder, .noFolder:
            false
        }
    }

    /// The SF Symbol of the tile.
    var tileSymbol: String {
        switch self {
        case .archive: "archivebox.fill"
        case .bankAccount: "building.columns.fill"
        case .card: "creditcard.fill"
        case .collection: "folder.fill"
        case .driversLicense: "car.fill"
        case .folder, .noFolder: "folder.fill"
        case .identity: "person.crop.rectangle.fill"
        case .login: "key.fill"
        case .passport: "airplane"
        case .secureNote: "note.text"
        case .sshKey: "terminal.fill"
        case .totp: "lock.rotation"
        case .trash: "trash.fill"
        }
    }

    /// The color of the tile symbol: the category color, mixed with black in light mode for the light system colors so
    /// the symbol keeps a 3:1 contrast on its pale tint (ui-r7 contrast audit).
    func tileSymbolColor(for colorScheme: ColorScheme) -> Color {
        guard colorScheme == .light else { return tileColor }
        let darkening: Double = switch self {
        case .secureNote: 0.45
        case .bankAccount, .driversLicense, .passport, .totp: 0.3
        case .archive, .card, .sshKey: 0.15
        default: 0
        }
        return tileColor.mix(with: .black, by: darkening)
    }

    /// The system color of the tile.
    var tileColor: Color {
        switch self {
        case .archive: .brown
        case .bankAccount: .teal
        case .card: .orange
        case .collection, .folder, .noFolder: .blue
        case .driversLicense: .mint
        case .identity: .indigo
        case .login: .blue
        case .passport: .cyan
        case .secureNote: .yellow
        case .sshKey: .gray
        case .totp: .green
        case .trash: .red
        }
    }

    /// The prefix of a folder's home element identifier (`folder:<id>`).
    static let folderElementPrefix = "folder:"

    /// The Customize identifier of a home element: the type tiles' `tileIdentifier`, `folder:<id>` for a folder,
    /// `noFolder`; `nil` for collections (not a home element).
    var passYHomeElementId: String? {
        switch self {
        case .collection: nil
        case let .folder(id, _): Self.folderElementPrefix + id
        case .noFolder: "noFolder"
        default: tileIdentifier
        }
    }

    /// The sRGB fill of a filled ("Vollfarbig") card: a deep shade of the tile colour on which white text and symbols
    /// keep at least 4.5:1 in light and dark mode (`PassYLayoutPreferencesTests`).
    var filledCardRGB: (red: Int, green: Int, blue: Int) {
        switch self {
        case .archive: (0x7A, 0x56, 0x36)
        case .bankAccount: (0x0D, 0x6E, 0x78)
        case .card: (0xB8, 0x4A, 0x00)
        case .collection, .folder, .noFolder: (0x3B, 0x5B, 0x85)
        case .driversLicense: (0x08, 0x72, 0x5F)
        case .identity: (0x4F, 0x46, 0xC8)
        case .login: (0x0B, 0x62, 0xD6)
        case .passport: (0x03, 0x6A, 0x9E)
        case .secureNote: (0x86, 0x63, 0x00)
        case .sshKey: (0x5C, 0x5C, 0x66)
        case .totp: (0x1E, 0x7B, 0x3B)
        case .trash: (0xC6, 0x2B, 0x1E)
        }
    }

    /// The fill of a filled card (the same in light and dark mode).
    var filledCardColor: Color {
        let rgb = filledCardRGB
        return Color(.sRGB, red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255)
    }

    /// A stable identifier for UI tests.
    var tileIdentifier: String {
        switch self {
        case .archive: "archive"
        case .bankAccount: "bankAccount"
        case .card: "card"
        case .collection: "collection"
        case .driversLicense: "driversLicense"
        case .folder: "folder"
        case .identity: "identity"
        case .login: "login"
        case .noFolder: "noFolder"
        case .passport: "passport"
        case .secureNote: "secureNote"
        case .sshKey: "sshKey"
        case .totp: "totp"
        case .trash: "trash"
        }
    }
}

// MARK: - Readable width

extension View {
    /// Limits the content to a comfortable reading width and centers it. On iPhone widths this is a no-op;
    /// on iPad, iPhone Duo (inner display) and wide windows it keeps lists and tiles from stretching edge to edge.
    /// It only depends on the container size, never on the device idiom or `UIScreen`.
    func readableContentWidth(_ maxWidth: CGFloat = 720) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
