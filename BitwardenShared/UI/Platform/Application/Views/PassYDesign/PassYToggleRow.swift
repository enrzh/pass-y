import BitwardenResources
import SwiftUI

// MARK: - PassYToggleRow

/// A switch row of a Pass-Y form: a system `Toggle` with a title, an optional one-line explanation below it and an
/// optional help button (opens a help page) instead of Bitwarden's custom toggle and tooltip.
///
/// ```swift
/// PassYToggleRow(
///     Localizations.passwordPrompt,
///     isOn: $reprompt,
///     identifier: "MasterPasswordRepromptToggle",
///     helpURL: ExternalLinksConstants.protectIndividualItems,
/// )
/// ```
///
struct PassYToggleRow: View {
    // MARK: Properties

    /// The title.
    let title: String

    /// The explanation below the title.
    var subtitle: String?

    /// The value.
    @Binding var isOn: Bool

    /// The accessibility identifier of the switch.
    var identifier: String?

    /// The spoken label (defaults to the title).
    var accessibilityLabel: String?

    /// A help page opened by the info button.
    var helpURL: URL?

    /// The spoken label of the info button.
    var helpLabel: String?

    @Environment(\.openURL) private var openURL

    // MARK: Initialization

    /// Creates a switch row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - subtitle: The explanation below the title.
    ///   - isOn: The value.
    ///   - identifier: The accessibility identifier of the switch.
    ///   - accessibilityLabel: The spoken label.
    ///   - helpURL: A help page opened by the info button.
    ///   - helpLabel: The spoken label of the info button.
    ///
    init(
        _ title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        identifier: String? = nil,
        accessibilityLabel: String? = nil,
        helpURL: URL? = nil,
        helpLabel: String? = nil,
    ) {
        self.title = title
        self.subtitle = subtitle
        _isOn = isOn
        self.identifier = identifier
        self.accessibilityLabel = accessibilityLabel
        self.helpURL = helpURL
        self.helpLabel = helpLabel
    }

    // MARK: View

    var body: some View {
        HStack(spacing: PassYDesign.Spacing.small) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                    Text(title)
                        .font(.body)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier(identifier ?? title)
            .accessibilityLabel(accessibilityLabel ?? title)

            if let helpURL {
                Button {
                    openURL(helpURL)
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(helpLabel ?? Localizations.learnMore)
            }
        }
        .frame(minHeight: 44)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Toggle rows") {
    @Previewable @SwiftUI.State var isOn = true
    Form {
        Section {
            PassYToggleRow("Master password re-prompt", isOn: $isOn, helpURL: URL(string: "https://example.test"))
            PassYToggleRow("Hide email", subtitle: "Recipients do not see your email address.", isOn: $isOn)
        }
    }
}
#endif
