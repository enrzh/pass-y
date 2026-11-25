import SwiftUI

// MARK: - PassYRow

/// The one list row of Pass-Y: a leading icon tile, a title (row title role) with optional inline accessories, up to
/// two secondary lines, a trailing accessory and an optional disclosure chevron. At least 56 pt high; it grows with
/// Dynamic Type and lets the title wrap (up to three lines) at accessibility sizes instead of truncating it.
///
/// `PassYRow` is only the content. Make it tappable with `.passYRowButton(identifier:action:)` (press highlight,
/// pointer hover, the identifier on the button) and add options with `.passYRowContextMenu` and
/// `.passYRowSwipeActions`. It works in a `List` (the system separator starts at the text column) and in a plain
/// stack (`divider: true` draws its own hairline).
///
/// ```swift
/// PassYRow(title: "GitHub", subtitles: ["octo@example.test"], showsDisclosure: true) {
///     PassYIconTile(letter: "GitHub")
/// }
/// .passYRowButton(identifier: "VaultListItemRowButton") { open() }
/// ```
///
struct PassYRow<Leading: View, TitleAccessory: View, Trailing: View>: View {
    // MARK: Types

    /// A line of text of a row (`PassYRowLine`).
    typealias Line = PassYRowLine

    // MARK: Properties

    /// The title.
    let title: Line

    /// The secondary lines below the title (at most two are useful).
    var subtitles: [Line] = []

    /// Whether the row ends with a disclosure chevron.
    var showsDisclosure = false

    /// The accessibility identifier of the chevron.
    var disclosureIdentifier: String?

    /// Whether the row draws its own bottom hairline (rows outside a `List`).
    var divider = false

    /// The leading content, usually a `PassYIconTile`.
    let leading: Leading

    /// Small views right after the title (quiet `PassYBadge` symbols such as shared or attachments).
    let titleAccessory: TitleAccessory

    /// The trailing content (a count, a code, a button).
    let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Initialization

    /// Creates a row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - subtitles: The secondary lines.
    ///   - showsDisclosure: Whether the row ends with a disclosure chevron.
    ///   - disclosureIdentifier: The accessibility identifier of the chevron.
    ///   - divider: Whether the row draws its own bottom hairline (outside a `List`).
    ///   - leading: The leading content.
    ///   - titleAccessory: Small views right after the title.
    ///   - trailing: The trailing content.
    ///
    init(
        title: Line,
        subtitles: [Line?] = [],
        showsDisclosure: Bool = false,
        disclosureIdentifier: String? = nil,
        divider: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder titleAccessory: () -> TitleAccessory,
        @ViewBuilder trailing: () -> Trailing,
    ) {
        self.title = title
        self.subtitles = subtitles.compactMap(\.self)
        self.showsDisclosure = showsDisclosure
        self.disclosureIdentifier = disclosureIdentifier
        self.divider = divider
        self.leading = leading()
        self.titleAccessory = titleAccessory()
        self.trailing = trailing()
    }

    // MARK: View

    var body: some View {
        HStack(spacing: PassYDesign.Spacing.medium) {
            leading

            VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: PassYDesign.Spacing.xSmall + 2) {
                    text(title, role: .rowTitle, style: .primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    titleAccessory
                }
                ForEach(subtitles, id: \.text) { line in
                    text(line, role: .rowSubtitle, style: .secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
            }
            .multilineTextAlignment(.leading)
            .accessibilityElement(children: .combine)
            // The system separator starts at the text column (Apple Passwords), not under the tile.
            .passYListSeparatorLeading()

            Spacer(minLength: PassYDesign.Spacing.small)

            trailing

            if showsDisclosure {
                PassYDisclosureChevron(identifier: disclosureIdentifier)
            }
        }
        .padding(.vertical, PassYDesign.Row.verticalPadding)
        .frame(maxWidth: .infinity, minHeight: PassYDesign.Row.minHeight, alignment: .leading)
        // The blank space between text and trailing content is part of the hit area.
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if divider {
                Divider()
                    .padding(.leading, PassYDesign.IconSize.row + PassYDesign.Spacing.medium)
            }
        }
    }

    /// One line of the text column.
    private func text(_ line: Line, role: PassYDesign.TextRole, style: HierarchicalShapeStyle) -> some View {
        Text(line.text)
            .passYFont(role)
            .foregroundStyle(style)
            .accessibilityIdentifier(line.identifier ?? "")
    }
}

extension PassYRow where TitleAccessory == EmptyView {
    /// Creates a row without title accessories.
    init(
        title: Line,
        subtitles: [Line?] = [],
        showsDisclosure: Bool = false,
        disclosureIdentifier: String? = nil,
        divider: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
    ) {
        self.init(
            title: title,
            subtitles: subtitles,
            showsDisclosure: showsDisclosure,
            disclosureIdentifier: disclosureIdentifier,
            divider: divider,
            leading: leading,
            titleAccessory: { EmptyView() },
            trailing: trailing,
        )
    }
}

extension PassYRow where Trailing == EmptyView {
    /// Creates a row without trailing content.
    init(
        title: Line,
        subtitles: [Line?] = [],
        showsDisclosure: Bool = false,
        disclosureIdentifier: String? = nil,
        divider: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder titleAccessory: () -> TitleAccessory,
    ) {
        self.init(
            title: title,
            subtitles: subtitles,
            showsDisclosure: showsDisclosure,
            disclosureIdentifier: disclosureIdentifier,
            divider: divider,
            leading: leading,
            titleAccessory: titleAccessory,
            trailing: { EmptyView() },
        )
    }
}

extension PassYRow where TitleAccessory == EmptyView, Trailing == EmptyView {
    /// Creates a row with a leading tile and text only.
    init(
        title: Line,
        subtitles: [Line?] = [],
        showsDisclosure: Bool = false,
        disclosureIdentifier: String? = nil,
        divider: Bool = false,
        @ViewBuilder leading: () -> Leading,
    ) {
        self.init(
            title: title,
            subtitles: subtitles,
            showsDisclosure: showsDisclosure,
            disclosureIdentifier: disclosureIdentifier,
            divider: divider,
            leading: leading,
            titleAccessory: { EmptyView() },
            trailing: { EmptyView() },
        )
    }
}

// MARK: - PassYRowLine

/// A line of text of a `PassYRow` with its optional accessibility identifier. A string literal is a line without
/// identifier.
struct PassYRowLine: Equatable, ExpressibleByStringLiteral {
    /// The text.
    let text: String

    /// The accessibility identifier of the text (kept stable for UI tests).
    var identifier: String?

    /// Creates a line.
    init(text: String, identifier: String? = nil) {
        self.text = text
        self.identifier = identifier
    }

    init(stringLiteral value: String) {
        self.init(text: value)
    }

    /// Creates a line, `nil` for an empty or missing text.
    static func make(_ text: String?, identifier: String? = nil) -> PassYRowLine? {
        guard let text, !text.isEmpty else { return nil }
        return PassYRowLine(text: text, identifier: identifier)
    }
}

// MARK: - PassYDisclosureChevron

/// The quiet disclosure chevron at the end of a row that opens a page.
struct PassYDisclosureChevron: View {
    /// The accessibility identifier (the chevron itself is hidden from VoiceOver).
    var identifier: String?

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
            .accessibilityIdentifier(identifier ?? "")
    }
}

// MARK: - PassYRowButtonStyle

/// The button style of a tappable row: the content stays as drawn, a pressed row gets the system fill across the
/// whole row (also under the side margins given as `horizontalBleed`). In a `List` only one button per row may use a
/// non-default style for taps to stay separate (several default-style buttons in one row would all fire).
struct PassYRowButtonStyle: ButtonStyle {
    /// How far the pressed highlight extends past the label on each side (the row's own side margin).
    var horizontalBleed: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Color(.systemFill)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .padding(.horizontal, -horizontalBleed)
                    .animation(configuration.isPressed ? nil : .easeOut(duration: 0.25), value: configuration.isPressed)
            }
    }
}

// MARK: - Row modifiers

extension View {
    /// Makes a row tappable: one button with the row's press highlight and pointer hover, the accessibility
    /// identifier on the button. Keep the row's side margin outside the button (`horizontalBleed` lets the highlight
    /// reach the row edges): a button as wide as the list row was merged with the row container by the accessibility
    /// system and lost its identifier (found in the UI test tree dump).
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the button.
    ///   - horizontalBleed: The row's side margin outside the button.
    ///   - action: The tap action.
    ///
    func passYRowButton(
        identifier: String? = nil,
        horizontalBleed: CGFloat = PassYDesign.Spacing.large,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) { self }
            .buttonStyle(PassYRowButtonStyle(horizontalBleed: horizontalBleed))
            .hoverEffect(.highlight)
            .accessibilityIdentifier(identifier ?? "")
    }

    /// The long-press menu of a row (native menu items with SF Symbols; the destructive item last, after a divider).
    func passYRowContextMenu<MenuItems: View>(@ViewBuilder _ items: () -> MenuItems) -> some View {
        contextMenu(menuItems: items)
    }

    /// The trailing swipe actions of a row (Apple Mail / Passwords style: icon-only buttons, no full swipe). Do not
    /// give a delete button `role: .destructive` when the delete is confirmed first: the list then drops the row on
    /// the tap and crashes when the real removal arrives ("Invalid number of items in section").
    func passYRowSwipeActions<Actions: View>(@ViewBuilder _ actions: () -> Actions) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: false, content: actions)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Rows") {
    List {
        Section {
            PassYRow(
                title: .init(text: "GitHub"),
                subtitles: [.make("octo@example.test")],
                showsDisclosure: true,
            ) {
                PassYIconTile(letter: "GitHub")
            } titleAccessory: {
                PassYBadge(systemImage: "star.fill", tint: .yellow, label: "Favorite")
                PassYBadge(systemImage: "paperclip", label: "Attachments")
            }
            .passYRowButton {}
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            PassYRow(title: "Work", showsDisclosure: true) {
                PassYIconTile(systemImage: "folder.fill", tint: .blue)
            } trailing: {
                Text("12").passYFont(.rowValue).foregroundStyle(.secondary)
            }
            .passYRowButton {}
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }
    .passYCardList(reservesBottomBarSpace: false)
}
#endif
