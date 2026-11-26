import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - CustomizeHomePreview

/// The live preview at the top of Customize: a miniature of the home cards in the chosen order and colours, the
/// first folder rows (sample counts, never vault data; folder names are the vault's own, on this device only), a
/// sample item row and a sample code row drawn by the real row components with the chosen options. Decorative: hidden
/// from VoiceOver and UI test queries (the controls below describe everything).
struct CustomizeHomePreview: View {
    /// The preferences shown.
    let layout: PassYLayoutStore

    /// The top-level folders of the vault.
    var folders: [PassYCustomizeFolders.Element] = []

    /// At most this many cards are drawn.
    private static let maxCards = 6

    /// At most this many folder rows are drawn.
    private static let maxRows = 2

    var body: some View {
        let preferences = layout.preferences
        let elements = PassYLayoutPreferences.knownTiles + folders.map(\.id)
        let split = preferences.partitionCards(elements, id: { $0 })
        VStack(alignment: .leading, spacing: PassYDesign.Spacing.medium) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(split.cards.prefix(Self.maxCards)), id: \.self) { id in
                    miniCard(id)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(split.rows.prefix(Self.maxRows)), id: \.self) { id in
                    let group = group(for: id)
                    PassYRow(title: .init(text: group.name), showsDisclosure: true) {
                        PassYIconTile(systemImage: group.tileSymbol, tint: group.tileColor)
                    } trailing: {
                        Text(Self.sampleCount(group), format: .number)
                            .passYFont(.rowValue)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
                PassYRow(
                    title: "GitHub",
                    subtitles: ["octo@example.test"],
                    showsDisclosure: true,
                ) {
                    PassYIconTile(letter: "GitHub")
                } titleAccessory: {
                    PreviewBadges()
                }
                Divider()
                PassYCodeRow(name: "GitHub", account: "octo@example.test", code: "123456", period: 30) {
                    PassYIconTile(letter: "GitHub")
                }
            }
            .padding(.horizontal, PassYDesign.Spacing.medium)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: PassYDesign.Radius.large, style: .continuous),
            )
        }
        .padding(PassYDesign.Spacing.small)
        .background(
            Color(.systemGroupedBackground),
            in: RoundedRectangle(cornerRadius: PassYDesign.Radius.large, style: .continuous),
        )
        // Same environment as the vault pages, from the same store: the preview follows every change at once.
        .passYLayoutEnvironment(layout)
        .animation(.snappy, value: preferences)
        .allowsHitTesting(false)
        // One ignored element, then hidden: inside a list cell a plain `accessibilityHidden` left the children exposed.
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }

    /// The group drawn for an element (a folder for folder elements).
    private func group(for id: String) -> VaultListGroup {
        VaultListGroup(passYTileIdentifier: id)
            ?? .folder(id: id, name: folders.first { $0.id == id }?.name ?? Localizations.folder)
    }

    /// A small card.
    private func miniCard(_ id: String) -> some View {
        let group = group(for: id)
        return CategoryTile(group: group, count: Self.sampleCount(group), colors: layout.home.cardColors)
            .dynamicTypeSize(...DynamicTypeSize.large)
    }

    /// A fixed sample count per tile (never vault data).
    private static func sampleCount(_ group: VaultListGroup) -> Int {
        switch group {
        case .login: 42
        case .totp: 6
        case .card: 3
        case .identity: 2
        case .secureNote: 5
        case .trash: 1
        case .folder: 4
        default: 0
        }
    }
}

/// The sample badges of the preview row (favourite and attachments), filtered like the vault rows.
private struct PreviewBadges: View {
    @Environment(\.passYBadgeOptions) private var options

    var body: some View {
        if options.favorite {
            PassYBadge(systemImage: "star.fill", tint: .yellow, label: Localizations.favorite)
        }
        if options.shared {
            PassYBadge(systemImage: "person.2.fill", label: Localizations.shared)
        }
        if options.attachments {
            PassYBadge(systemImage: "paperclip", label: Localizations.attachments)
        }
    }
}
