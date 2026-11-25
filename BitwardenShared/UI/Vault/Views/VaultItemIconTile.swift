import BitwardenKit
import BitwardenSdk
import SwiftUI

// MARK: - VaultItemIconTile

/// The `PassYIconTile` of a vault list row: a login shows its website icon on a neutral tile and, until the icon is
/// loaded or without one, the tinted first letter of its name; a passkey, card, identity, note or key shows its type
/// symbol; groups (folders, collections, types, trash ...) and codes show the symbol and colour of their category
/// tile on the home screen.
struct VaultItemIconTile: View {
    // MARK: Properties

    /// The row's item.
    let item: VaultListItem

    /// The base URL of the website icons.
    let iconBaseURL: URL?

    /// Whether website icons are shown.
    let showWebIcons: Bool

    // MARK: View

    var body: some View {
        Group {
            switch item.itemType {
            case let .cipher(cipherItem, fido2):
                cipherTile(cipherItem, hasPasskey: fido2 != nil)
            case let .group(group, _):
                PassYIconTile(systemImage: group.tileSymbol, tint: group.tileColor)
            case let .totp(name, model):
                websiteOrLetterTile(name: name, item: VaultListItem(cipherListView: model.cipherListView))
            }
        }
        // UI tests find the icon kind through this identifier (the tile itself is decorative).
        .accessibilityIdentifier(item.iconAccessibilityId)
    }

    // MARK: Private

    /// The tile of a cipher row.
    @ViewBuilder
    private func cipherTile(_ cipherItem: CipherListView, hasPasskey: Bool) -> some View {
        let type = CipherType(cipherItem.type)
        if cipherItem.isDecryptionFailure {
            PassYIconTile(systemImage: "exclamationmark.triangle.fill", tint: .red)
        } else if type == .login, hasPasskey {
            PassYIconTile(systemImage: "person.badge.key.fill", tint: .blue)
        } else if type == .login {
            websiteOrLetterTile(name: cipherItem.name, item: item)
        } else {
            let group = VaultListGroup(tileFor: type)
            PassYIconTile(systemImage: group.tileSymbol, tint: group.tileColor)
        }
    }

    /// The website icon of a login on a neutral tile, the tinted first letter until it is loaded or without one.
    @ViewBuilder
    private func websiteOrLetterTile(name: String, item: VaultListItem?) -> some View {
        if showWebIcons, let iconBaseURL, let data = item?.cipherDecorativeIconDataView,
           let url = IconImageHelper.getIconImage(for: data, from: iconBaseURL) {
            CipherIconAsyncImage(url: url) { image in
                PassYIconTile {
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(PassYDesign.Spacing.small - 1)
                }
            } placeholder: {
                PassYIconTile(letter: name)
            }
        } else {
            PassYIconTile(letter: name)
        }
    }
}

// MARK: - VaultListGroup + cipher type

extension VaultListGroup {
    /// The category of a cipher type (its symbol and colour are the row tile's).
    init(tileFor type: CipherType) {
        switch type {
        case .login: self = .login
        case .secureNote: self = .secureNote
        case .card: self = .card
        case .identity: self = .identity
        case .sshKey: self = .sshKey
        case .bankAccount: self = .bankAccount
        case .driversLicense: self = .driversLicense
        case .passport: self = .passport
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Item tiles") {
    HStack(spacing: 12) {
        VaultItemIconTile(
            item: VaultListItem(cipherListView: .fixture(id: "1", name: "GitHub"))!,
            iconBaseURL: nil,
            showWebIcons: false,
        )
        VaultItemIconTile(
            item: VaultListItem(id: "2", itemType: .group(.folder(id: "1", name: "Work"), 3)),
            iconBaseURL: nil,
            showWebIcons: false,
        )
        VaultItemIconTile(
            item: VaultListItem(id: "3", itemType: .group(.card, 3)),
            iconBaseURL: nil,
            showWebIcons: false,
        )
    }
    .padding()
}
#endif
