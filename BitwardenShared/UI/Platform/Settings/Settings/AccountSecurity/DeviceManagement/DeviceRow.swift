import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - DeviceRowState

/// An object representing the visual state of a `DeviceRow`.
struct DeviceRowState: Equatable {
    // MARK: Properties

    /// The device to display.
    let device: DeviceListItem

    /// The formatted first-login date and time for display.
    var formattedFirstLogin: String {
        DeviceRowState.formattedDateTime(from: device.firstLogin)
    }
}

extension DeviceRowState {
    /// Locale-aware formatter for the date portion of a first-login timestamp, e.g. "Apr 1, 2026".
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter
    }()

    /// Locale-aware formatter for the time portion of a first-login timestamp, including seconds
    /// and respecting the user's 12/24-hour preference, e.g. "5:29:54 PM".
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("jj:mm:ss")
        return formatter
    }()

    /// Formats a date as a localized "MMM d, yyyy, h:mm:ss a"-style string (e.g.
    /// "Apr 1, 2026, 5:29:54 PM"), including seconds and respecting the user's 12/24-hour
    /// preference.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: The formatted date and time string.
    ///
    private static func formattedDateTime(from date: Date) -> String {
        "\(dateFormatter.string(from: date)), \(timeFormatter.string(from: date))"
    }
}

// MARK: - DeviceRowAction

/// Actions that can be sent from a `DeviceRow`.
enum DeviceRowAction: Equatable, Sendable {
    /// The row was tapped (for devices with a pending request).
    case rowTapped(DeviceListItem)
}

// MARK: - DeviceRow

/// A row displaying device information in the device management list.
///
struct DeviceRow: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<DeviceRowState, DeviceRowAction, Void>

    // MARK: View

    var body: some View {
        if store.state.device.hasPendingRequest {
            Button {
                store.send(.rowTapped(store.state.device))
            } label: {
                rowContent
            }
            .buttonStyle(.automatic)
            .foregroundStyle(Color.primary)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("DeviceRowCell")
        } else {
            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("DeviceRowCell")
        }
    }

    // MARK: Private Views

    /// The row content shared between actionable and non-actionable states: a device tile, the name with a status
    /// badge, the trust and activity lines, and a chevron for a device with a pending request.
    @ViewBuilder private var rowContent: some View {
        HStack(alignment: .center, spacing: PassYDesign.Spacing.medium) {
            PassYIconTile(systemImage: deviceSymbol, tint: .blue, size: PassYDesign.IconSize.small)

            VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                Text(store.state.device.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("DeviceNameLabel")

                if store.state.device.isCurrentSession {
                    PassYBadge(text: Localizations.currentSession, tint: .blue)
                } else if store.state.device.hasPendingRequest {
                    PassYBadge(text: Localizations.pendingRequest, tint: .orange)
                }

                if store.state.device.isTrusted {
                    Text(Localizations.trusted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("TrustedLabel")
                }

                if shouldShowRecentlyActiveRow {
                    recentlyActiveRow
                }

                firstLoginRow
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .passYListSeparatorLeading()

            if store.state.device.hasPendingRequest {
                PassYDisclosureChevron()
            }
        }
        .padding(.vertical, PassYDesign.Spacing.xSmall)
        .contentShape(Rectangle())
        .foregroundStyle(Color.primary)
    }

    /// The SF Symbol of the device type (phone, tablet, computer, browser).
    private var deviceSymbol: String {
        switch store.state.device.deviceType.category {
        case .mobile: "iphone"
        case .extension: "puzzlepiece.extension.fill"
        case .webApp: "globe"
        case .desktop: "laptopcomputer"
        case .cli, .sdk: "terminal.fill"
        case .server: "server.rack"
        case .unknown: "questionmark.circle.fill"
        }
    }

    /// Whether the recently active row should be shown. It's hidden for the current session and
    /// for devices with a pending request, since those cases are already communicated by their
    /// badge and don't need a separate activity timestamp.
    private var shouldShowRecentlyActiveRow: Bool {
        !store.state.device.isCurrentSession &&
            !store.state.device.hasPendingRequest &&
            store.state.device.lastActivityDate != nil
    }

    /// The recently active row with bold label and regular status.
    private var recentlyActiveRow: some View {
        HStack(spacing: PassYDesign.Spacing.xSmall) {
            Text(Localizations.recentlyActiveLabel)
                .fontWeight(.semibold)

            Text(store.state.device.activityStatus.localizedString)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("RecentlyActiveRow")
    }

    /// The first login row with bold label and regular date.
    private var firstLoginRow: some View {
        HStack(spacing: 4) {
            Text(Localizations.firstLoginLabel)
                .fontWeight(.semibold)

            Text(store.state.formattedFirstLogin)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("FirstLoginRow")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Device Row - Current Session") {
    DeviceRow(
        store: Store(processor: StateProcessor(state: DeviceRowState(device: DeviceListItem(
            activityStatus: .today,
            deviceType: .iOS,
            displayName: "Mobile - iOS",
            firstLogin: Date(),
            id: "1",
            identifier: "abc123",
            isCurrentSession: true,
            isTrusted: true,
            lastActivityDate: Date(),
            pendingAuthRequestId: nil,
            pendingRequest: nil,
        )))),
    )
    .padding()
}

#Preview("Device Row - Pending Request") {
    DeviceRow(
        store: Store(processor: StateProcessor(state: DeviceRowState(device: DeviceListItem(
            activityStatus: .pastSevenDays,
            deviceType: .chromeExtension,
            displayName: "Web vault - Chrome",
            firstLogin: Date().addingTimeInterval(-86400 * 30),
            id: "2",
            identifier: "def456",
            isCurrentSession: false,
            isTrusted: false,
            lastActivityDate: Date().addingTimeInterval(-86400 * 3),
            pendingAuthRequestId: nil,
            pendingRequest: .fixture(),
        )))),
    )
    .padding()
}

#Preview("Device Row - Trusted Not Current") {
    DeviceRow(
        store: Store(processor: StateProcessor(state: DeviceRowState(device: DeviceListItem(
            activityStatus: .pastFourteenDays,
            deviceType: .macOsDesktop,
            displayName: "Desktop - macOS",
            firstLogin: Date().addingTimeInterval(-86400 * 60),
            id: "3",
            identifier: "ghi789",
            isCurrentSession: false,
            isTrusted: true,
            lastActivityDate: Date().addingTimeInterval(-86400 * 10),
            pendingAuthRequestId: nil,
            pendingRequest: nil,
        )))),
    )
    .padding()
}
#endif
