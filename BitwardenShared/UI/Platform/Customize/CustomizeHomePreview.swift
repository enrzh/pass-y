import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - CustomizeHomePreview

/// The live preview at the top of Customize: a miniature of the home tiles in the chosen order and layout (sample
/// counts, never vault data), a sample item row and a sample code row drawn by the real row components with the
/// chosen options. Decorative: hidden from VoiceOver and UI test queries (the controls below describe everything).
struct CustomizeHomePreview: View {
    /// The preferences shown.
    let layout: PassYLayoutStore

    /// At most this many tiles are drawn.
    private static let maxTiles = 6

    var body: some View {
        let preferences = layout.preferences
        let tiles = preferences.partitionTiles(PassYLayoutPreferences.knownTiles, id: { $0 }).visible
            .compactMap(VaultListGroup.init(passYTileIdentifier:))
            .prefix(Self.maxTiles)
        VStack(alignment: .leading, spacing: PassYDesign.Spacing.medium) {
            switch preferences.home.tileLayout {
            case .grid:
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(Array(tiles), id: \.tileIdentifier) { group in
                        miniCard(group, isWide: false)
                    }
                }
            case .wide:
                VStack(spacing: 6) {
                    ForEach(Array(tiles), id: \.tileIdentifier) { group in
                        miniCard(group, isWide: true)
                    }
                }
            case .list:
                VStack(spacing: 0) {
                    ForEach(Array(tiles), id: \.tileIdentifier) { group in
                        PassYRow(title: .init(text: group.name), showsDisclosure: true) {
                            PassYIconTile(systemImage: group.tileSymbol, tint: group.tileColor)
                        } trailing: {
                            Text(Self.sampleCount(group), format: .number)
                                .passYFont(.rowValue)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
            }

            VStack(spacing: 0) {
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

    /// A small tile card.
    private func miniCard(_ group: VaultListGroup, isWide: Bool) -> some View {
        CategoryTile(group: group, count: Self.sampleCount(group), isWide: isWide)
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
