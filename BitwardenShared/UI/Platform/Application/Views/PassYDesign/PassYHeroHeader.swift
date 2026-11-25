import SwiftUI

// MARK: - PassYHeroHeader

/// The calm, centred header of an auth or one-off page: the Pass-Y shield mark (or an SF Symbol), a title and an
/// optional message. In a `Form` put it in its own section with `.passYPlainListRow()` so it sits on the page
/// background without a card.
///
/// ```swift
/// Form {
///     Section { PassYHeroHeader(title: Localizations.logInToBitwarden) }.passYPlainListRow()
///     Section { ...fields... }
/// }
/// ```
///
struct PassYHeroHeader: View {
    // MARK: Types

    /// The symbol of the header.
    enum Mark: Equatable {
        /// The Pass-Y shield mark in the accent colour.
        case shield

        /// An SF Symbol in the given colour.
        case symbol(String, Color)

        /// No symbol.
        case none
    }

    // MARK: Properties

    /// The symbol of the header.
    var mark: Mark = .shield

    /// The title.
    let title: String

    /// The message under the title.
    var message: String?

    /// The accessibility identifier of the title.
    var titleIdentifier: String?

    /// The size of the mark, scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 56

    // MARK: Initialization

    /// Creates a header.
    ///
    /// - Parameters:
    ///   - mark: The symbol of the header.
    ///   - title: The title.
    ///   - message: The message under the title.
    ///   - titleIdentifier: The accessibility identifier of the title.
    ///
    init(mark: Mark = .shield, title: String, message: String? = nil, titleIdentifier: String? = nil) {
        self.mark = mark
        self.title = title
        self.message = message
        self.titleIdentifier = titleIdentifier
    }

    // MARK: View

    var body: some View {
        VStack(spacing: PassYDesign.Spacing.medium) {
            switch mark {
            case .shield:
                PassYShieldMark()
                    .foregroundStyle(.tint)
                    .frame(width: markSize, height: markSize)
                    .accessibilityHidden(true)
            case let .symbol(name, color):
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .frame(width: markSize, height: markSize * 0.85)
                    .accessibilityHidden(true)
            case .none:
                EmptyView()
            }
            VStack(spacing: PassYDesign.Spacing.small) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(titleIdentifier ?? "")
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PassYDesign.Spacing.small)
    }
}

// MARK: - PassYShieldMark

/// The Pass-Y mark: a solid shield with the Y knocked out (the geometry of `Scripts-passy/generate_logo.swift`, on
/// its 1024 grid), drawn in the foreground style at any size.
struct PassYShieldMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 1024
            context.translateBy(x: (size.width - 1024 * scale) / 2, y: (size.height - 1024 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let shield = Self.shieldPath(scale: 0.93)
            context.fill(shield, with: .foreground)
            context.stroke(shield, with: .foreground, style: StrokeStyle(lineWidth: 48, lineJoin: .round))
            context.blendMode = .destinationOut
            context.stroke(
                Self.yPath,
                with: .color(.black),
                style: StrokeStyle(lineWidth: 90, lineCap: .round, lineJoin: .round),
            )
        }
        .compositingGroup()
    }

    /// The shield outline, scaled about its centre (512, 520).
    static func shieldPath(scale s: CGFloat) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 512 + (x - 512) * s, y: 520 + (y - 520) * s) }
        var p = Path()
        p.move(to: pt(512, 168))
        p.addCurve(to: pt(792, 262), control1: pt(590, 222), control2: pt(700, 262))
        p.addLine(to: pt(792, 506))
        p.addCurve(to: pt(512, 872), control1: pt(792, 700), control2: pt(660, 810))
        p.addCurve(to: pt(232, 506), control1: pt(364, 810), control2: pt(232, 700))
        p.addLine(to: pt(232, 262))
        p.addCurve(to: pt(512, 168), control1: pt(324, 262), control2: pt(434, 222))
        p.closeSubpath()
        return p
    }

    /// The Y.
    static var yPath: Path {
        var p = Path()
        p.move(to: CGPoint(x: 392, y: 366))
        p.addLine(to: CGPoint(x: 512, y: 526))
        p.addLine(to: CGPoint(x: 632, y: 366))
        p.move(to: CGPoint(x: 512, y: 526))
        p.addLine(to: CGPoint(x: 512, y: 712))
        return p
    }
}

// MARK: - View + plain list row

extension View {
    /// Shows a `Form`/`List` section's content on the page background: no card, no separators, no row insets
    /// (headers and button stacks of auth pages).
    func passYPlainListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Hero headers") {
    Form {
        Section {
            PassYHeroHeader(title: "Log in to Pass-Y", message: "Enter your e-mail address to continue.")
        }
        .passYPlainListRow()
        Section {
            PassYHeroHeader(mark: .symbol("lock.fill", .orange), title: "Your vault is locked")
        }
        .passYPlainListRow()
    }
}
#endif
