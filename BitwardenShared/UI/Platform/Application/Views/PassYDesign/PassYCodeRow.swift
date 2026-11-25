import SwiftUI

// MARK: - PassYOneTimeCode

/// Display rules of one-time codes: two groups of characters ("123 456", "1234 5678"; an odd length puts the
/// shorter group first: "123 4567") and a spoken form that reads every character on its own ("1 2 3 4 5 6").
enum PassYOneTimeCode {
    /// The two groups of a code (one group for codes shorter than 4 characters).
    static func groups(_ code: String) -> [String] {
        let characters = Array(code.filter { !$0.isWhitespace })
        guard characters.count >= 4 else { return characters.isEmpty ? [] : [String(characters)] }
        let split = characters.count / 2
        return [String(characters[..<split]), String(characters[split...])]
    }

    /// The code as shown: its two groups separated by a space.
    static func display(_ code: String) -> String {
        groups(code).joined(separator: " ")
    }

    /// The code as VoiceOver reads it: every character separated by a space.
    static func spoken(_ code: String) -> String {
        code.filter { !$0.isWhitespace }.map(String.init).joined(separator: " ")
    }

    /// The masked placeholder of a code that needs the master password first (same width as the code).
    static func masked(length: Int = 6) -> String {
        display(String(repeating: "•", count: max(length, 4)))
    }
}

// MARK: - PassYCodeRow

/// A row of the verification codes list: icon tile, name and account, the large monospaced code in two groups and a
/// `PassYCountdownRing`. The code keeps its width when it changes (tabular digits, numeric transition), so rows
/// never jump when codes refresh. At accessibility text sizes the code and ring move below the name.
/// A code that needs the master password first shows a masked placeholder and a lock instead of the ring.
///
/// Make it tappable with `.passYRowButton` (tap copies) and set its accessibility label with
/// `PassYOneTimeCode.accessibilityLabel(...)`.
struct PassYCodeRow<Leading: View>: View {
    // MARK: Properties

    /// The item name.
    let name: String

    /// The account (user name), if any.
    var account: String?

    /// The current code, `nil` while it is locked behind the master password.
    let code: String?

    /// The code period in seconds.
    let period: Int

    /// The leading content, usually a `PassYIconTile`.
    let leading: Leading

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Initialization

    /// Creates a code row.
    ///
    /// - Parameters:
    ///   - name: The item name.
    ///   - account: The account (user name).
    ///   - code: The current code, `nil` while it needs the master password.
    ///   - period: The code period in seconds.
    ///   - leading: The leading content.
    ///
    init(name: String, account: String?, code: String?, period: Int, @ViewBuilder leading: () -> Leading) {
        self.name = name
        self.account = account
        self.code = code
        self.period = period
        self.leading = leading()
    }

    // MARK: View

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.small) {
                    HStack(spacing: PassYDesign.Spacing.medium) {
                        leading
                        titles
                    }
                    HStack(spacing: PassYDesign.Spacing.medium) {
                        codeText
                        Spacer(minLength: 0)
                        status
                    }
                }
            } else {
                HStack(spacing: PassYDesign.Spacing.medium) {
                    leading
                    titles
                    Spacer(minLength: PassYDesign.Spacing.small)
                    codeText
                    status
                }
            }
        }
        .padding(.vertical, PassYDesign.Row.verticalPadding + 2)
        .frame(maxWidth: .infinity, minHeight: PassYDesign.Row.minHeight + 8, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Name and account.
    private var titles: some View {
        VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
            Text(name)
                .passYFont(.rowTitle)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            if let account, !account.isEmpty {
                Text(account)
                    .passYFont(.rowSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
        }
        .layoutPriority(1)
        .passYListSeparatorLeading()
    }

    /// The code (or its masked placeholder).
    private var codeText: some View {
        Text(code.map(PassYOneTimeCode.display) ?? PassYOneTimeCode.masked())
            .passYFont(.code)
            .foregroundStyle(code == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .fixedSize()
            .contentTransition(.numericText())
            .animation(.snappy, value: code)
            .accessibilityIdentifier("TOTPCodeLabel")
    }

    /// The countdown, or a lock for a code behind the master password.
    @ViewBuilder private var status: some View {
        if code == nil {
            Image(systemName: "lock.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 30)
                .accessibilityHidden(true)
        } else {
            PassYCountdownRing(period: period)
        }
    }
}

extension PassYOneTimeCode {
    /// The spoken label of a code row (`PassYCodeRow`): name, account, the code character by character and the seconds left.
    ///
    /// - Parameters:
    ///   - name: The item name.
    ///   - account: The account.
    ///   - code: The current code, `nil` while it needs the master password.
    ///   - secondsRemaining: The seconds left.
    ///
    static func accessibilityLabel(name: String, account: String?, code: String?, secondsRemaining: Int) -> String {
        var parts = [name]
        if let account, !account.isEmpty { parts.append(account) }
        if let code {
            parts.append("Code \(PassYOneTimeCode.spoken(code))")
            parts.append(secondsRemaining == 1 ? "1 second left" : "\(secondsRemaining) seconds left")
        } else {
            parts.append("Code hidden, master password required")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Code rows") {
    List {
        Section {
            PassYCodeRow(name: "GitHub", account: "octo@example.test", code: "123456", period: 30) {
                PassYIconTile(letter: "GitHub")
            }
            PassYCodeRow(name: "Bank", account: "me@example.test", code: "12345678", period: 60) {
                PassYIconTile(letter: "Bank")
            }
            PassYCodeRow(name: "Locked", account: nil, code: nil, period: 30) {
                PassYIconTile(letter: "Locked")
            }
        }
    }
    .passYCardList(reservesBottomBarSpace: false)
}

#Preview("Code rows AX") {
    List {
        PassYCodeRow(name: "A very long service name", account: "someone@example.test", code: "123456", period: 30) {
            PassYIconTile(letter: "A")
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
