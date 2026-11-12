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

    /// Called when a tile is tapped.
    let onSelect: (VaultListItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    // MARK: View

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                if case let .group(group, count) = item.itemType {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelect(item)
                    } label: {
                        CategoryTile(group: group, count: count)
                    }
                    .buttonStyle(.plain)
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

// MARK: - CategoryTile

/// One tile: colored symbol badge, count and title.
private struct CategoryTile: View {
    let group: VaultListGroup
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: group.tileSymbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(group.tileColor, in: Circle())
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            Text(group.name)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    /// The system color of the tile badge.
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
