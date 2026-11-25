import SwiftUI

// MARK: - PassYInlineButtonRow

/// An action row inside a form section ("New URI", "New custom field", "Check for data breaches", "Delete"): an SF
/// Symbol and a title, the whole row tappable. `.tinted` (the default) draws it in the tint colour like a system form
/// action; `.plain` in the primary colour (a quiet command); a destructive role draws it red. Async actions run in a
/// task and disable the row while they run.
///
/// ```swift
/// PassYInlineButtonRow(Localizations.newUri, systemImage: "plus", identifier: "LoginAddNewUriButton") { add() }
/// PassYInlineButtonRow(Localizations.checkPassword, systemImage: "checkmark.shield", style: .plain) {
///     await store.perform(.checkPasswordPressed)
/// }
/// ```
///
struct PassYInlineButtonRow: View {
    // MARK: Types

    /// The colour of the row.
    enum Style {
        /// The tint colour.
        case tinted

        /// The primary text colour.
        case plain
    }

    // MARK: Properties

    /// The title.
    let title: String

    /// The SF Symbol, `nil` for none.
    var systemImage: String?

    /// The colour.
    var style: Style = .tinted

    /// The role (`.destructive` draws red).
    var role: ButtonRole?

    /// The accessibility identifier.
    var identifier: String?

    /// The action: run directly, or in a task that disables the row while it runs.
    private let action: Action

    /// A synchronous or an asynchronous action.
    private enum Action {
        case sync(() -> Void)
        case async(() async -> Void)
    }

    @SwiftUI.State private var isRunning = false

    // MARK: Initialization

    /// Creates an action row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - systemImage: The SF Symbol.
    ///   - style: The colour.
    ///   - role: The role.
    ///   - identifier: The accessibility identifier.
    ///   - action: The action.
    ///
    init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .tinted,
        role: ButtonRole? = nil,
        identifier: String? = nil,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.role = role
        self.identifier = identifier
        self.action = .sync(action)
    }

    /// Creates an action row with an asynchronous action (the row is disabled while it runs).
    init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .tinted,
        role: ButtonRole? = nil,
        identifier: String? = nil,
        action: @escaping () async -> Void,
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.role = role
        self.identifier = identifier
        self.action = .async(action)
    }

    /// Runs the action (tests call this to tap the row).
    func perform() async {
        switch action {
        case let .sync(run): run()
        case let .async(run): await run()
        }
    }

    // MARK: View

    var body: some View {
        Button(role: role) {
            switch action {
            case let .sync(run):
                run()
            case let .async(run):
                guard !isRunning else { return }
                isRunning = true
                Task { @MainActor in
                    await run()
                    isRunning = false
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: PassYDesign.Spacing.small) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.body)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(identifier ?? title)
    }

    /// The colour of symbol and title.
    private var foreground: AnyShapeStyle {
        if role == .destructive { return AnyShapeStyle(Color.red) }
        switch style {
        case .tinted: return AnyShapeStyle(.tint)
        case .plain: return AnyShapeStyle(Color.primary)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Inline button rows") {
    Form {
        Section {
            PassYInlineButtonRow("New URI", systemImage: "plus") {}
            PassYInlineButtonRow("Check for data breaches", systemImage: "checkmark.shield", style: .plain) {}
        }
        Section {
            PassYInlineButtonRow("Delete", systemImage: "trash", role: .destructive) {}
        }
    }
}
#endif
