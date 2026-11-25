import SwiftUI

// MARK: - PassYIconButton

/// A small symbol button inside a form row (generate, copy, remove, open): the SF Symbol in the tint colour, a
/// 28 pt minimum hit area, borderless (so the row itself is not one big button), and the title as its spoken label.
///
/// ```swift
/// PassYIconButton(Localizations.generatePassword, systemImage: "arrow.trianglehead.2.clockwise") { generate() }
/// ```
///
struct PassYIconButton: View {
    /// The spoken label.
    let title: String

    /// The SF Symbol.
    let systemImage: String

    /// The role (`.destructive` draws red).
    var role: ButtonRole?

    /// The action.
    let action: () -> Void

    /// Creates a symbol button.
    ///
    /// - Parameters:
    ///   - title: The spoken label.
    ///   - systemImage: The SF Symbol.
    ///   - role: The role.
    ///   - action: The action.
    ///
    init(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(role == .destructive ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tint))
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Icon buttons") {
    Form {
        HStack {
            Text("Password")
            Spacer()
            PassYIconButton("Generate", systemImage: "arrow.trianglehead.2.clockwise") {}
            PassYIconButton("Remove", systemImage: "minus.circle.fill", role: .destructive) {}
        }
    }
}
#endif
