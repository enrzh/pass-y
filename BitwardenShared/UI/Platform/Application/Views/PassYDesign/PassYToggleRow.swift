import SwiftUI

// MARK: - PassYToggleRow

/// A settings switch (iOS Settings style): an optional small tinted SF Symbol tile, the title, an optional explanation
/// under it and the system `Toggle`. The accessibility identifier sits on the toggle (UI tests query it as a switch).
///
/// ```swift
/// PassYToggleRow(Localizations.unlockWithPIN, systemImage: "circle.grid.3x3.fill", tint: .blue,
///                isOn: $isOn, identifier: "UnlockWithPinSwitch")
/// ```
///
struct PassYToggleRow: View {
    // MARK: Properties

    /// The title.
    let title: String

    /// An explanation under the title.
    var subtitle: String?

    /// The SF Symbol of the leading tile, `nil` for a row without a tile.
    var systemImage: String?

    /// The colour of the tile.
    var tint: Color = .accentColor

    /// Whether the switch is on.
    @Binding var isOn: Bool

    /// The accessibility identifier of the toggle.
    var identifier: String?

    // MARK: Initialization

    /// Creates a toggle row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - subtitle: An explanation under the title.
    ///   - systemImage: The SF Symbol of the leading tile, `nil` for none.
    ///   - tint: The colour of the tile.
    ///   - isOn: Whether the switch is on.
    ///   - identifier: The accessibility identifier of the toggle.
    ///
    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = .accentColor,
        isOn: Binding<Bool>,
        identifier: String? = nil,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        _isOn = isOn
        self.identifier = identifier
    }

    // MARK: View

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: PassYDesign.Spacing.medium) {
                if let systemImage {
                    PassYIconTile(systemImage: systemImage, tint: tint, size: PassYDesign.IconSize.small)
                }
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .passYListSeparatorLeading()
            }
        }
        .accessibilityIdentifier(identifier ?? "")
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Toggle rows") {
    @Previewable @SwiftUI.State var isOn = true
    List {
        PassYToggleRow("Unlock with Face ID", systemImage: "faceid", tint: .green, isOn: $isOn)
        PassYToggleRow(
            "Unlock with PIN",
            subtitle: "Use a PIN instead of the master password.",
            systemImage: "circle.grid.3x3.fill",
            tint: .blue,
            isOn: $isOn,
        )
        PassYToggleRow("Show website icons", isOn: $isOn)
    }
}
#endif
