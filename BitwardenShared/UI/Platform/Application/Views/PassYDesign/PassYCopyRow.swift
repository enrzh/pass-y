import BitwardenResources
import SwiftUI

// MARK: - PassYCopyRow

/// A value row of a Pass-Y detail page (item view, Send view): the label in the primary colour, the value in the
/// secondary colour. Tapping the row copies the value (success haptic; the page shows the "copied" toast), a long press
/// offers Copy, Reveal/Hide for secrets and any extra actions, secrets have an eye button. Short values sit right of
/// the label (`.inline`); long values (notes, keys, addresses) and every value at accessibility text sizes stand below
/// it (`.stacked`).
///
/// The value text carries the accessibility identifier and stays its own element (a static text whose label is the
/// value or the mask), so VoiceOver and UI tests read it; the row adds a Copy action to it.
///
/// ```swift
/// PassYCopyRow(Localizations.username, value: username, identifier: "LoginUsernameEntry") {
///     store.send(.copyPressed(value: username, field: .username))
/// }
/// PassYCopyRow(
///     Localizations.password,
///     value: password,
///     secret: .init(isRevealed: isVisible, revealIdentifier: "ShowLoginPasswordButton") { toggle() },
///     identifier: "LoginPasswordEntry",
/// ) { copy() }
/// ```
///
struct PassYCopyRow<Accessory: View, MenuItems: View>: View {
    // MARK: Types

    /// The layout of the row.
    enum Layout {
        /// Label left, value right.
        case inline

        /// Label above the value (long values).
        case stacked
    }

    /// The reveal state of a secret value.
    struct Secret {
        /// Whether the value is shown.
        let isRevealed: Bool

        /// The accessibility identifier of the eye button.
        var revealIdentifier: String?

        /// Whether the revealed value tints digits and symbols (passwords; not card numbers or codes).
        var tintsCharacters = true

        /// Whether the user may reveal the value (no eye button and no Reveal action otherwise).
        var canReveal = true

        /// The field name VoiceOver reads on the eye button ("Account number is hidden"), `nil` for the generic
        /// password wording.
        var spokenName: String?

        /// Toggles the value.
        let toggle: () -> Void
    }

    // MARK: Properties

    /// The label.
    let title: String

    /// The value.
    let value: String

    /// The reveal state, `nil` for a plain value.
    var secret: Secret?

    /// The accessibility identifier of the value text.
    var identifier: String?

    /// The layout (accessibility sizes always stack).
    var layout: Layout = .inline

    /// Whether the value uses the monospaced font.
    var isMonospaced = false

    /// Whether VoiceOver reads the value character by character (account numbers, codes).
    var spellsOut = false

    /// Copies the value; `nil` for a value that cannot be copied (tap does nothing).
    var copy: (() -> Void)?

    /// Views after the value (a countdown, an open-website button).
    let accessory: Accessory

    /// Extra long-press actions after Copy and Reveal.
    let menuItems: MenuItems

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @SwiftUI.State private var copies = 0

    // MARK: Initialization

    /// Creates a value row.
    ///
    /// - Parameters:
    ///   - title: The label.
    ///   - value: The value.
    ///   - secret: The reveal state of a secret.
    ///   - identifier: The accessibility identifier of the value text.
    ///   - layout: The layout.
    ///   - isMonospaced: Whether the value is monospaced.
    ///   - spellsOut: Whether VoiceOver reads the value character by character.
    ///   - accessory: Views after the value.
    ///   - menuItems: Extra long-press actions.
    ///   - copy: Copies the value.
    ///
    init(
        _ title: String,
        value: String,
        secret: Secret? = nil,
        identifier: String? = nil,
        layout: Layout = .inline,
        isMonospaced: Bool = false,
        spellsOut: Bool = false,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder menuItems: () -> MenuItems,
        copy: (() -> Void)?,
    ) {
        self.title = title
        self.value = value
        self.secret = secret
        self.identifier = identifier
        self.layout = layout
        self.isMonospaced = isMonospaced || secret != nil
        self.spellsOut = spellsOut
        self.accessory = accessory()
        self.menuItems = menuItems()
        self.copy = copy
    }

    // MARK: View

    /// Whether the label stands above the value.
    private var stacks: Bool {
        layout == .stacked || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        HStack(spacing: PassYDesign.Spacing.medium) {
            Group {
                if stacks {
                    VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
                        titleText
                        valueText
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: PassYDesign.Spacing.medium) {
                        titleText
                        Spacer(minLength: PassYDesign.Spacing.small)
                        valueText
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: performCopy)

            if let secret, secret.canReveal {
                PassYRevealButton(
                    isRevealed: secret.isRevealed,
                    fieldName: secret.spokenName,
                    identifier: secret.revealIdentifier,
                ) {
                    secret.toggle()
                }
            }
            accessory
                .buttonStyle(.borderless)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.success, trigger: copies)
        .contextMenu {
            if copy != nil {
                Button(Localizations.copy, systemImage: "doc.on.doc", action: performCopy)
            }
            if let secret, secret.canReveal {
                Button(
                    secret.isRevealed ? "Hide" : "Reveal",
                    systemImage: secret.isRevealed ? "eye.slash" : "eye",
                    action: secret.toggle,
                )
            }
            menuItems
        }
    }

    /// The label.
    private var titleText: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(stacks ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(stacks ? 0 : 1)
    }

    /// The value (or its mask).
    private var valueText: some View {
        PassYValueText(
            value: value,
            isMasked: secret.map { !$0.isRevealed } ?? false,
            isMonospaced: isMonospaced,
            tintsCharacters: secret?.tintsCharacters ?? false,
            spellsOut: spellsOut,
        )
            .multilineTextAlignment(stacks ? .leading : .trailing)
            .textSelection(.disabled)
            .accessibilityIdentifier(identifier ?? title)
            .accessibilityHint(copy == nil ? "" : Localizations.copy)
            .accessibilityAction(named: Localizations.copy) { performCopy() }
    }

    /// Copies the value with a success haptic.
    private func performCopy() {
        guard let copy else { return }
        copies += 1
        copy()
    }
}

extension PassYCopyRow where Accessory == EmptyView, MenuItems == EmptyView {
    /// Creates a value row without accessory and extra actions.
    init(
        _ title: String,
        value: String,
        secret: Secret? = nil,
        identifier: String? = nil,
        layout: Layout = .inline,
        isMonospaced: Bool = false,
        spellsOut: Bool = false,
        copy: (() -> Void)?,
    ) {
        self.init(
            title,
            value: value,
            secret: secret,
            identifier: identifier,
            layout: layout,
            isMonospaced: isMonospaced,
            spellsOut: spellsOut,
            accessory: { EmptyView() },
            menuItems: { EmptyView() },
            copy: copy,
        )
    }
}

extension PassYCopyRow where MenuItems == EmptyView {
    /// Creates a value row with an accessory and without extra actions.
    init(
        _ title: String,
        value: String,
        secret: Secret? = nil,
        identifier: String? = nil,
        layout: Layout = .inline,
        isMonospaced: Bool = false,
        spellsOut: Bool = false,
        @ViewBuilder accessory: () -> Accessory,
        copy: (() -> Void)?,
    ) {
        self.init(
            title,
            value: value,
            secret: secret,
            identifier: identifier,
            layout: layout,
            isMonospaced: isMonospaced,
            spellsOut: spellsOut,
            accessory: accessory,
            menuItems: { EmptyView() },
            copy: copy,
        )
    }
}

// MARK: - PassYValueText

/// The value of a detail row: plain text, a fixed-length mask for hidden secrets, or a revealed secret with digits and
/// symbols tinted (Apple Passwords) so similar characters are easy to tell apart.
struct PassYValueText: View {
    /// The value.
    let value: String

    /// Whether the value is hidden behind the mask.
    var isMasked = false

    /// Whether the text is monospaced.
    var isMonospaced = false

    /// Whether digits and symbols are tinted (revealed secrets).
    var tintsCharacters = false

    /// Whether VoiceOver reads the value character by character.
    var spellsOut = false

    /// The mask of a hidden secret (its length does not reveal the secret's length).
    static let mask = String(repeating: "•", count: 8)

    var body: some View {
        Group {
            if isMasked {
                Text(Self.mask)
                    .accessibilityLabel(Localizations.passwordIsNotVisibleTapToShow)
            } else if tintsCharacters {
                Text(Self.tinted(value))
                    .accessibilityLabel(value)
                    .speechSpellsOutCharacters(spellsOut)
            } else {
                Text(value)
                    .speechSpellsOutCharacters(spellsOut)
            }
        }
        .font(isMonospaced ? .body.monospaced() : .body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The value with digits in blue and symbols in orange; a zero-width space after every character lets long
    /// secrets wrap anywhere.
    static func tinted(_ value: String) -> AttributedString {
        var result = AttributedString()
        for character in value {
            var part = AttributedString(String(character) + "\u{200B}")
            if character.isNumber {
                part.foregroundColor = .blue
            } else if !character.isLetter, !character.isWhitespace {
                part.foregroundColor = .orange
            }
            result.append(part)
        }
        return result
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Copy rows") {
    @Previewable @SwiftUI.State var revealed = false
    List {
        Section {
            PassYCopyRow("Username", value: "octo@example.test", identifier: "LoginUsernameEntry") {}
            PassYCopyRow(
                "Password",
                value: "Sup3r-Secret!42",
                secret: .init(isRevealed: revealed) { revealed.toggle() },
            ) {}
            PassYCopyRow("Website", value: "https://github.com") {
                Button("Open", systemImage: "arrow.up.forward.app") {}
                    .labelStyle(.iconOnly)
            } copy: {}
        }
        Section {
            PassYCopyRow("Notes", value: "A longer note that wraps onto more lines.", layout: .stacked) {}
        }
    }
}
#endif
