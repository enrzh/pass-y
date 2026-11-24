import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - CategoryTilesView

/// A two-column grid of category tiles (logins, cards, codes, trash, ...) shown at the top of the vault,
/// built only from system fonts, SF Symbols and system colors.
///
struct CategoryTilesView: View {
    // MARK: Properties

    /// The group items to show as tiles.
    let items: [VaultListItem]

    /// Forces a single column (used when the tiles are shown as a sidebar).
    var singleColumn = false

    /// Called when a tile is tapped.
    let onSelect: (VaultListItem) -> Void

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
                    Button {
                        #if DEBUG
                        PassYPerf.beginTap("tile")
                        #endif
                        CategoryTileHaptics.tapped()
                        onSelect(item)
                    } label: {
                        CategoryTile(group: group, count: count)
                    }
                    .buttonStyle(CategoryTileButtonStyle())
                    .hoverEffect(.highlight)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(group.name)
                    .accessibilityValue("\(count)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("CategoryTile_\(group.tileIdentifier)")
                }
            }
        }
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

/// One tile: a tinted symbol tile, the count and the title.
private struct CategoryTile: View {
    let group: VaultListGroup
    let count: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // A rounded-square symbol tile with a soft tint of the category color (the shape of the item icons
                // in the lists), instead of a saturated badge.
                Image(systemName: group.tileSymbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(group.tileSymbolColor(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        group.tileColor.opacity(colorScheme == .dark ? 0.24 : 0.14),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                    )
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                Text(count, format: .number)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    // Empty categories step back, but not below 0.7 (a little darker than `.secondary`): the count
                    // must pass the contrast audit on the white tile.
                    .foregroundStyle(Color.primary.opacity(count == 0 ? 0.7 : 0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Text(group.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.leading)
                // One line, always: long names ("Verification codes") shrink instead of wrapping, so tiles in the
                // same row keep the same height. Accessibility sizes use a single column (see `columns`).
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        // Same height for every tile of a row (the shrinking long names measure a fraction of a point differently).
        .frame(minHeight: 96, alignment: .topLeading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: categoryTileCornerRadius, style: .continuous),
        )
        .contentShape(RoundedRectangle(cornerRadius: categoryTileCornerRadius, style: .continuous))
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
