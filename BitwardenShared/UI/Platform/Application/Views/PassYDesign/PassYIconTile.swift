import SwiftUI

// MARK: - PassYIconTile

/// A square icon tile with continuous corners: a tinted SF Symbol, a tinted first letter, or any image (e.g. a web
/// icon) on a neutral tile with a hairline border. The tile grows with Dynamic Type (up to 1.6 times its size).
///
/// ```swift
/// PassYIconTile(systemImage: "folder.fill", tint: .blue)
/// PassYIconTile(letter: "GitHub")                       // tint picked from the name
/// PassYIconTile { Image(uiImage: icon).resizable() }    // neutral tile for a web icon
/// ```
///
struct PassYIconTile<Content: View>: View {
    // MARK: Types

    /// The look of the tile.
    enum Style: Equatable {
        /// A pale tint of the colour behind content in the colour (symbols, letters).
        case tinted(Color)

        /// The neutral tile with a hairline border (web icons and other full-colour images).
        case plain

        /// A white tile with a hairline border in both appearances: web icons that are a dark logo on transparency
        /// (they vanish on the dark neutral tile in dark mode).
        case light
    }

    // MARK: Properties

    /// The look of the tile.
    let style: Style

    /// The side length before Dynamic Type scaling.
    let size: CGFloat

    /// The content (the caller sizes it to fit; symbol and letter tiles do that already).
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    /// Dynamic Type scale of the tile, relative to the row title.
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    // MARK: Initialization

    /// Creates a tile around custom content.
    ///
    /// - Parameters:
    ///   - style: The look of the tile (default: neutral with a hairline border).
    ///   - size: The side length before Dynamic Type scaling (default: the 40 pt row size).
    ///   - content: The content of the tile.
    ///
    init(style: Style = .plain, size: CGFloat = PassYDesign.IconSize.row, @ViewBuilder content: () -> Content) {
        self.style = style
        self.size = size
        self.content = content()
    }

    // MARK: View

    var body: some View {
        let side = PassYDesign.IconSize.scaled(size, by: scale)
        let shape = RoundedRectangle(cornerRadius: PassYDesign.Radius.tile(side: side), style: .continuous)
        content
            .frame(width: side, height: side)
            .background(background, in: shape)
            .clipShape(shape)
            .overlay {
                if style == .plain || style == .light {
                    shape.strokeBorder(Color(.separator), lineWidth: 0.5)
                }
            }
            .accessibilityHidden(true)
    }

    /// The tile fill.
    private var background: Color {
        switch style {
        case let .tinted(tint): tint.opacity(colorScheme == .dark ? 0.24 : 0.14)
        case .plain: Color(.systemBackground)
        case .light: .white
        }
    }
}

// MARK: - Symbol and letter tiles

extension PassYIconTile where Content == PassYTileGlyph {
    /// A tile with a tinted SF Symbol.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol name.
    ///   - tint: The colour of the tile.
    ///   - size: The side length before Dynamic Type scaling.
    ///
    init(systemImage: String, tint: Color, size: CGFloat = PassYDesign.IconSize.row) {
        self.init(style: .tinted(tint), size: size) {
            PassYTileGlyph(kind: .symbol(systemImage), tint: tint, size: size)
        }
    }

    /// A tile with the first letter of a name; the tint comes from the name (`PassYTilePalette`) unless given.
    ///
    /// - Parameters:
    ///   - name: The name whose first letter is shown.
    ///   - tint: The colour of the tile, `nil` for the name's palette colour.
    ///   - size: The side length before Dynamic Type scaling.
    ///
    init(letter name: String, tint: Color? = nil, size: CGFloat = PassYDesign.IconSize.row) {
        let tint = tint ?? PassYTilePalette.color(for: name)
        self.init(style: .tinted(tint), size: size) {
            PassYTileGlyph(kind: .letter(PassYTilePalette.initial(of: name)), tint: tint, size: size)
        }
    }
}

// MARK: - PassYTileGlyph

/// The symbol or letter inside a tinted `PassYIconTile`, in the tile colour (darkened in light mode for contrast on
/// the pale tint).
struct PassYTileGlyph: View {
    /// What the glyph shows.
    enum Kind: Equatable {
        /// An SF Symbol.
        case symbol(String)

        /// A letter.
        case letter(String)
    }

    /// What the glyph shows.
    let kind: Kind

    /// The tile colour.
    let tint: Color

    /// The tile side length before Dynamic Type scaling (the glyph is laid out for the scaled side, no
    /// `GeometryReader` per row).
    let size: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    /// Dynamic Type scale, the same as the tile's.
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let color = colorScheme == .dark ? tint : tint.mix(with: .black, by: 0.25)
        let side = PassYDesign.IconSize.scaled(size, by: scale)
        Group {
            switch kind {
            case let .symbol(name):
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.semibold)
                    .padding(side * 0.24)
            case let .letter(letter):
                Text(letter)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(side * 0.12)
            }
        }
        .frame(width: side, height: side)
        .foregroundStyle(color)
    }
}

// MARK: - PassYTilePalette

/// The colours of letter tiles. A name always gets the same colour (a stable hash of its characters, not Swift's
/// per-launch randomized `Hasher`).
enum PassYTilePalette {
    /// The palette, in order.
    static let colors: [Color] = [.blue, .indigo, .purple, .pink, .red, .orange, .brown, .green, .teal, .cyan]

    /// The palette index of a name (case-insensitive, ignores surrounding white space).
    static func index(for name: String) -> Int {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var hash: UInt64 = 5381
        for scalar in key.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        return Int(hash % UInt64(colors.count))
    }

    /// The colour of a name.
    static func color(for name: String) -> Color {
        colors[index(for: name)]
    }

    /// The upper-cased first letter or digit of a name, "?" when it has none.
    static func initial(of name: String) -> String {
        guard let first = name.first(where: { $0.isLetter || $0.isNumber }) else { return "?" }
        return String(first).uppercased()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Icon tiles") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            PassYIconTile(systemImage: "folder.fill", tint: .blue)
            PassYIconTile(systemImage: "creditcard.fill", tint: .orange)
            PassYIconTile(systemImage: "lock.rotation", tint: .green)
            PassYIconTile(systemImage: "trash.fill", tint: .red, size: PassYDesign.IconSize.small)
        }
        HStack(spacing: 12) {
            PassYIconTile(letter: "GitHub")
            PassYIconTile(letter: "Netflix")
            PassYIconTile(letter: "bank")
            PassYIconTile(letter: "  ")
        }
        PassYIconTile {
            Image(systemName: "globe").resizable().scaledToFit().padding(8)
        }
    }
    .padding()
}
#endif
