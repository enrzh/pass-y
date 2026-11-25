import SwiftUI

// MARK: - PassYButtonKind

/// The three button kinds of Pass-Y content (not toolbar items: toolbars use plain system buttons).
enum PassYButtonKind: Equatable {
    /// The main action of a page or empty state: prominent Liquid Glass in the accent colour.
    case primary

    /// A further action: regular Liquid Glass.
    case secondary

    /// A destructive action: regular Liquid Glass with a red label.
    case destructive
}

// MARK: - View + PassYButtonStyle

extension View {
    /// Styles a `Button` (or `Menu`) as a Pass-Y content button, built from the system glass button styles. A full-width
    /// button (forms, sheets) passes `fillsWidth: true`.
    ///
    /// ```swift
    /// Button("New login", systemImage: "plus") { add() }.passYButtonStyle(.primary)
    /// Button("Delete", role: .destructive) { delete() }.passYButtonStyle(.destructive, fillsWidth: true)
    /// ```
    ///
    /// - Parameters:
    ///   - kind: The button kind.
    ///   - fillsWidth: Whether the label fills the available width.
    ///
    func passYButtonStyle(_ kind: PassYButtonKind, fillsWidth: Bool = false) -> some View {
        modifier(PassYButtonStyleModifier(kind: kind, fillsWidth: fillsWidth))
    }
}

/// Applies a `PassYButtonKind`.
private struct PassYButtonStyleModifier: ViewModifier {
    let kind: PassYButtonKind
    let fillsWidth: Bool

    func body(content: Content) -> some View {
        Group {
            switch kind {
            case .primary:
                content.buttonStyle(.glassProminent)
            case .secondary:
                content.buttonStyle(.glass)
            case .destructive:
                content.buttonStyle(.glass).tint(.red).foregroundStyle(.red)
            }
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Button styles") {
    VStack(spacing: 16) {
        Button("New login", systemImage: "plus") {}
            .passYButtonStyle(.primary)
        Button("Import") {}
            .passYButtonStyle(.secondary)
        Button("Delete", role: .destructive) {}
            .passYButtonStyle(.destructive)
        Button("Save") {}
            .passYButtonStyle(.primary, fillsWidth: true)
    }
    .padding()
}
#endif
