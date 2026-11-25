import SwiftUI

// MARK: - PassYSettingsAccessory

/// The trailing accessory of a `PassYSettingsRow`.
enum PassYSettingsAccessory: Equatable {
    /// A disclosure chevron: the row opens a page.
    case disclosure

    /// An arrow out of a square: the row opens a web page or another app.
    case external

    /// A checkmark: the row is the selected option of a list.
    case checkmark

    /// No accessory: the row performs an action in place (lock, log out, delete).
    case none
}

// MARK: - PassYSettingsRow

/// The settings row of Pass-Y (iOS Settings style): a small tinted SF Symbol tile, the title, an optional secondary
/// value and badge, and a trailing accessory. The whole row is one button with the system row highlight; a
/// destructive row draws its title (and tile) in red. At accessibility text sizes the value moves under the title.
///
/// Navigation stays with the coordinators: the row sends the processor action, it is not a `NavigationLink`.
///
/// ```swift
/// PassYSettingsRow(Localizations.accountSecurity, systemImage: "lock.fill", tint: .blue,
///                  badge: "1", identifier: "AccountSecuritySettingsButton") { store.send(.accountSecurityPressed) }
/// PassYSettingsRow(Localizations.logOut, systemImage: "rectangle.portrait.and.arrow.right",
///                  role: .destructive, accessory: .none) { store.send(.logout) }
/// ```
///
struct PassYSettingsRow: View {
    // MARK: Properties

    /// The title.
    let title: String

    /// The SF Symbol of the leading tile, `nil` for a row without a tile.
    var systemImage: String?

    /// The colour of the tile.
    var tint: Color = .accentColor

    /// A secondary value after the title (the current choice, a count, a version).
    var value: String?

    /// A red count badge (settings that need attention).
    var badge: String?

    /// The trailing accessory.
    var accessory: PassYSettingsAccessory = .disclosure

    /// The role of the button (`.destructive` draws the row in red).
    var role: ButtonRole?

    /// The accessibility identifier of the button.
    var identifier: String?

    /// The tap action.
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Initialization

    /// Creates a settings row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - systemImage: The SF Symbol of the leading tile, `nil` for none.
    ///   - tint: The colour of the tile.
    ///   - value: A secondary value after the title.
    ///   - badge: A red count badge.
    ///   - role: The role of the button (`.destructive` draws the row in red).
    ///   - accessory: The trailing accessory.
    ///   - identifier: The accessibility identifier of the button.
    ///   - action: The tap action.
    ///
    init(
        _ title: String,
        systemImage: String? = nil,
        tint: Color = .accentColor,
        value: String? = nil,
        badge: String? = nil,
        role: ButtonRole? = nil,
        accessory: PassYSettingsAccessory = .disclosure,
        identifier: String? = nil,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = role == .destructive ? .red : tint
        self.value = value
        self.badge = badge
        self.role = role
        self.accessory = accessory
        self.identifier = identifier
        self.action = action
    }

    // MARK: View

    var body: some View {
        Button(role: role, action: action) {
            PassYSettingsRowLabel(
                title: title,
                systemImage: systemImage,
                tint: tint,
                value: value,
                badge: badge,
                accessory: accessory,
                titleStyle: role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary),
            )
        }
        .buttonStyle(.automatic)
        .accessibilityIdentifier(identifier ?? "")
        .accessibilityAddTraits(accessory == .checkmark ? .isSelected : [])
    }
}

// MARK: - PassYSettingsRowLabel

/// The content of a settings row (tile, title, value, badge, accessory) without the button, for rows that are a
/// `Menu` label or a `Toggle` label.
struct PassYSettingsRowLabel: View {
    /// The title.
    let title: String

    /// The SF Symbol of the leading tile.
    var systemImage: String?

    /// The colour of the tile.
    var tint: Color = .accentColor

    /// A secondary value after the title.
    var value: String?

    /// A red count badge.
    var badge: String?

    /// The trailing accessory.
    var accessory: PassYSettingsAccessory = .none

    /// The style of the title.
    var titleStyle = AnyShapeStyle(.primary)

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: PassYDesign.Spacing.medium) {
            if let systemImage {
                PassYIconTile(systemImage: systemImage, tint: tint, size: PassYDesign.IconSize.small)
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                    titleText
                    if let value {
                        valueText(value).multilineTextAlignment(.leading)
                    }
                }
                .passYListSeparatorLeading()
                Spacer(minLength: 0)
            } else {
                titleText
                    .passYListSeparatorLeading()
                Spacer(minLength: PassYDesign.Spacing.small)
                if let value {
                    valueText(value)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
            }
            if let badge {
                PassYCountBadge(text: badge)
            }
            accessoryView
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// The title text.
    private var titleText: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(titleStyle)
            .multilineTextAlignment(.leading)
    }

    /// The secondary value.
    private func valueText(_ value: String) -> some View {
        Text(value)
            .font(.body)
            .foregroundStyle(.secondary)
    }

    /// The trailing accessory.
    @ViewBuilder private var accessoryView: some View {
        switch accessory {
        case .disclosure:
            PassYDisclosureChevron()
        case .external:
            Image(systemName: "arrow.up.forward.app")
                .font(.body)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        case .checkmark:
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - PassYCountBadge

/// The red count capsule of a settings row (like the iOS Settings update badge).
struct PassYCountBadge: View {
    /// The count text.
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, PassYDesign.Spacing.small - 1)
            .padding(.vertical, PassYDesign.Spacing.xxSmall)
            .frame(minWidth: 24)
            .background(Capsule().fill(Color.red))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Settings rows") {
    List {
        Section {
            PassYSettingsRow("Account security", systemImage: "lock.fill", tint: .blue, badge: "1") {}
            PassYSettingsRow("Autofill", systemImage: "key.fill", tint: .green) {}
            PassYSettingsRow("Appearance", systemImage: "paintbrush.fill", tint: .indigo, value: "System") {}
        }
        Section {
            PassYSettingsRow("Help center", systemImage: "questionmark.circle.fill", tint: .gray, accessory: .external) {}
            PassYSettingsRow("Dark", accessory: .checkmark) {}
        }
        Section {
            PassYSettingsRow("Log out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive,
                             accessory: .none) {}
        }
    }
}

#Preview("Settings rows, AX") {
    List {
        PassYSettingsRow("Session timeout", systemImage: "timer", tint: .orange, value: "15 minutes") {}
        PassYSettingsRow("Autofill", systemImage: "key.fill", tint: .green, badge: "1") {}
    }
    .dynamicTypeSize(.accessibility3)
}
#endif
