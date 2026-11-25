import SwiftUI

// MARK: - PassYBadge

/// A small status mark: a quiet SF Symbol next to a row title (shared, attachments, favourite, Send status) or a
/// tinted capsule with a short text ("Shared", a count). Symbol badges scale with the text they sit next to and carry
/// an accessibility label (and identifier for UI tests).
///
/// ```swift
/// PassYBadge(systemImage: "paperclip", label: "Attachments", identifier: "CipherWithAttachmentsIcon")
/// PassYBadge(text: "Expired", tint: .red)
/// ```
///
struct PassYBadge: View {
    // MARK: Types

    /// What the badge shows.
    enum Content: Equatable {
        /// A quiet symbol.
        case symbol(String)

        /// A capsule with text.
        case text(String)
    }

    // MARK: Properties

    /// What the badge shows.
    let content: Content

    /// The colour (`nil`: secondary label colour for symbols, accent colour for capsules).
    var tint: Color?

    /// The spoken label (symbol badges only; text badges read their text).
    var label: String?

    /// The accessibility identifier.
    var identifier: String?

    // MARK: Initialization

    /// A quiet symbol badge.
    init(systemImage: String, tint: Color? = nil, label: String, identifier: String? = nil) {
        content = .symbol(systemImage)
        self.tint = tint
        self.label = label
        self.identifier = identifier
    }

    /// A capsule badge with a short text.
    init(text: String, tint: Color? = nil, identifier: String? = nil) {
        content = .text(text)
        self.tint = tint
        self.identifier = identifier
    }

    // MARK: View

    var body: some View {
        switch content {
        case let .symbol(name):
            Image(systemName: name)
                .font(.footnote.weight(.medium))
                .imageScale(.small)
                .foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
                .accessibilityLabel(label ?? "")
                .accessibilityIdentifier(identifier ?? "")
        case let .text(text):
            let color = tint ?? .accentColor
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, PassYDesign.Spacing.small - 1)
                .padding(.vertical, PassYDesign.Spacing.xxSmall)
                .foregroundStyle(color)
                .background(color.opacity(0.15), in: Capsule())
                .accessibilityIdentifier(identifier ?? "")
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Badges") {
    HStack(spacing: 8) {
        PassYBadge(systemImage: "star.fill", tint: .yellow, label: "Favorite")
        PassYBadge(systemImage: "person.2.fill", label: "Shared")
        PassYBadge(systemImage: "paperclip", label: "Attachments")
        PassYBadge(text: "Expired", tint: .red)
        PassYBadge(text: "12")
    }
    .padding()
}
#endif
