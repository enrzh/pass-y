import SwiftUI

// MARK: - PassYValueRow

/// A read-only settings row (`LabeledContent`): an optional small tinted SF Symbol tile, the title and its value on
/// the trailing side (under the title at accessibility text sizes). The value can be selected for copying.
///
/// ```swift
/// PassYValueRow(Localizations.version, value: "2026.11.0 (1234)", systemImage: "info.circle.fill", tint: .gray)
/// ```
///
struct PassYValueRow: View {
    // MARK: Properties

    /// The title.
    let title: String

    /// The value.
    let value: String

    /// The SF Symbol of the leading tile, `nil` for a row without a tile.
    var systemImage: String?

    /// The colour of the tile.
    var tint: Color = .accentColor

    /// Whether the value can be selected (copied).
    var isSelectable = false

    /// The accessibility identifier of the row.
    var identifier: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Initialization

    /// Creates a value row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - value: The value.
    ///   - systemImage: The SF Symbol of the leading tile, `nil` for none.
    ///   - tint: The colour of the tile.
    ///   - isSelectable: Whether the value can be selected (copied).
    ///   - identifier: The accessibility identifier of the row.
    ///
    init(
        _ title: String,
        value: String,
        systemImage: String? = nil,
        tint: Color = .accentColor,
        isSelectable: Bool = false,
        identifier: String? = nil,
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.isSelectable = isSelectable
        self.identifier = identifier
    }

    // MARK: View

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: PassYDesign.Spacing.medium) {
                    tile
                    VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                        Text(title)
                        valueText
                    }
                    .passYListSeparatorLeading()
                    Spacer(minLength: 0)
                }
            } else {
                LabeledContent {
                    valueText
                } label: {
                    HStack(spacing: PassYDesign.Spacing.medium) {
                        tile
                        Text(title)
                            .passYListSeparatorLeading()
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? "")
    }

    /// The leading tile.
    @ViewBuilder private var tile: some View {
        if let systemImage {
            PassYIconTile(systemImage: systemImage, tint: tint, size: PassYDesign.IconSize.small)
        }
    }

    /// The value text.
    @ViewBuilder private var valueText: some View {
        if isSelectable {
            Text(value).foregroundStyle(.secondary).textSelection(.enabled)
        } else {
            Text(value).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Value rows") {
    List {
        PassYValueRow("Version", value: "2026.11.0 (1234)", systemImage: "info.circle.fill", tint: .gray,
                      isSelectable: true)
        PassYValueRow("Server", value: "vault.example.test")
    }
}
#endif
