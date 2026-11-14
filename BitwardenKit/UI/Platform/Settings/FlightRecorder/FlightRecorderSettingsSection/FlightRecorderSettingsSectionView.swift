import BitwardenResources
import SwiftUI

// MARK: - FlightRecorderSettingsSectionView

/// A reusable view component that displays Flight Recorder settings.
///
/// This view provides a toggle to enable/disable flight recording and displays the active log's
/// end date and time when logging is enabled. It also includes a button to view recorded logs
/// and a help link for more information about the Flight Recorder feature.
///
/// This component can be integrated into any settings view that needs to display Flight Recorder
/// settings.
///
public struct FlightRecorderSettingsSectionView: View {
    // MARK: Types

    public typealias FlightRecorderSettingsSectionStore = Store<
        FlightRecorderSettingsSectionState,
        FlightRecorderSettingsSectionAction,
        FlightRecorderSettingsSectionEffect,
    >

    // MARK: Properties

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: FlightRecorderSettingsSectionStore

    // MARK: View

    public var body: some View {
        Group {
            Toggle(
                isOn: store.bindingAsync(
                    get: { $0.activeLog != nil },
                    perform: FlightRecorderSettingsSectionEffect.toggleFlightRecorder,
                ),
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(Localizations.flightRecorder)

                        Button {
                            openURL(ExternalLinksConstants.flightRecorderHelp)
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.footnote)
                                .accessibilityLabel(Localizations.learnMore)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    if let log = store.state.activeLog {
                        Text(Localizations.loggingEndsOnDateAtTime(log.formattedEndDate, log.formattedEndTime))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .accessibilityIdentifier("FlightRecorderSwitch")
            .accessibilityLabel(store.state.flightRecorderToggleAccessibilityLabel)

            Button {
                store.send(.viewLogsTapped)
            } label: {
                HStack {
                    Label(Localizations.viewRecordedLogs, systemImage: "doc.text.magnifyingglass")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Initialization

    /// Creates a new `FlightRecorderSettingsSectionView`.
    ///
    /// - Parameter store: The `Store` for managing the Flight Recorder settings section state,
    ///     actions, and effects.
    ///
    public init(store: FlightRecorderSettingsSectionStore) {
        self.store = store
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Disabled") {
    Form {
        FlightRecorderSettingsSectionView(
            store: Store(processor: StateProcessor(state: FlightRecorderSettingsSectionState())),
        )
    }
}

#Preview("Enabled") {
    Form {
        FlightRecorderSettingsSectionView(
            store: Store(processor: StateProcessor(state: FlightRecorderSettingsSectionState(
                activeLog: FlightRecorderData.LogMetadata(
                    duration: .eightHours,
                    startDate: Date(timeIntervalSinceNow: 60 * 60 * -4),
                ),
            ))),
        )
    }
}
#endif
