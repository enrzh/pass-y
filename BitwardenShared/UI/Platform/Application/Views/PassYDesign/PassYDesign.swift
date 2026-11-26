import SwiftUI

// MARK: - PassYDesign

/// The Pass-Y design tokens: corner radii, spacing, icon tile sizes and text roles. Every Pass-Y component takes its
/// measures from here, so lists, forms and settings share one rhythm.
///
/// Rules (see Docs/Architecture.md, "Design system"):
/// - New UI is built from the `PassY*` components and SwiftUI/system elements only, never from the Bitwarden UI kit
///   (`ContentBlock`, `SectionView`, `BitwardenTextField`, `IllustratedMessageView`, `LoadingView`, `AsyncButton`,
///   `.styleGuide`, `SharedAsset` colours, `.primary`/`.secondary` button styles, ...).
/// - Text uses Dynamic Type text styles only (no fixed point sizes); shapes use continuous corners.
///
enum PassYDesign {
    // MARK: Radius

    /// Corner radii (always used with `.continuous` corners).
    enum Radius {
        /// Small elements: badges, small tiles (28 pt).
        static let small: CGFloat = 7

        /// The 40 pt row icon tile (Apple Passwords / Settings proportions).
        static let tile: CGFloat = 10

        /// Large tiles and buttons.
        static let large: CGFloat = 14

        /// The corner radius of a tile of the given side length (keeps the tile proportions at every size).
        static func tile(side: CGFloat) -> CGFloat {
            (side * 0.25).rounded()
        }
    }

    // MARK: Spacing

    /// The spacing scale (4 pt grid).
    enum Spacing {
        /// 2 pt: between a title and its subtitle.
        static let xxSmall: CGFloat = 2

        /// 4 pt: between inline accessories.
        static let xSmall: CGFloat = 4

        /// 8 pt: between trailing elements.
        static let small: CGFloat = 8

        /// 12 pt: between the icon tile and the text column.
        static let medium: CGFloat = 12

        /// 16 pt: the side margin of a row.
        static let large: CGFloat = 16

        /// 24 pt: between blocks of a page.
        static let xLarge: CGFloat = 24
    }

    // MARK: IconSize

    /// The side lengths of the square icon tiles.
    enum IconSize {
        /// 28 pt: settings rows, menus.
        static let small: CGFloat = 28

        /// 40 pt: list rows.
        static let row: CGFloat = 40

        /// 56 pt: headers of detail pages.
        static let large: CGFloat = 56

        /// The side of a tile of `size` at the Dynamic Type `scale` (`@ScaledMetric` of 1 relative to `.body`):
        /// tiles grow with the text, at most to 1.6 times their size.
        static func scaled(_ size: CGFloat, by scale: CGFloat) -> CGFloat {
            (size * min(max(scale, 1), 1.6)).rounded()
        }
    }

    // MARK: Row

    /// Row measures.
    enum Row {
        /// The minimum height of a list row (rows grow with Dynamic Type).
        static let minHeight: CGFloat = 56

        /// The vertical padding of a row's content.
        static let verticalPadding: CGFloat = 8
    }

    // MARK: TextRole

    /// The text roles of Pass-Y. Each maps to a Dynamic Type text style.
    enum TextRole {
        /// A row title (`.body`, semibold).
        case rowTitle

        /// The secondary line of a row (`.subheadline`).
        case rowSubtitle

        /// A trailing value of a row, e.g. a count (`.body`).
        case rowValue

        /// A section header (`.subheadline`, semibold).
        case sectionHeader

        /// A one-time code in a list (`.title2`, monospaced digits, medium).
        case code

        /// Small notes (`.footnote`).
        case footnote

        /// The font of the role.
        var font: Font {
            switch self {
            case .rowTitle: .body.weight(.semibold)
            case .rowSubtitle: .subheadline
            case .rowValue: .body
            case .sectionHeader: .subheadline.weight(.semibold)
            case .code: .system(.title2, design: .rounded).weight(.medium).monospacedDigit()
            case .footnote: .footnote
            }
        }
    }
}

// MARK: - View + text role

extension View {
    /// Sets the font of a Pass-Y text role.
    func passYFont(_ role: PassYDesign.TextRole) -> some View {
        font(role.font)
    }
}
