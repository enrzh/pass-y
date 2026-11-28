import BitwardenResources
import SwiftUI

// MARK: - EnableFlightRecorderView

/// A view that allows a user to enable and configure the flight recorder.
///
struct EnableFlightRecorderView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<EnableFlightRecorderState, EnableFlightRecorderAction, EnableFlightRecorderEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                loggingDuration
            } footer: {
                footer
            }
        }
        .navigationBar(title: Localizations.enableFlightRecorder, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }

            saveToolbarItem {
                await store.perform(.save)
            }
        }
    }

    // MARK: Private Views

    /// The footer view: automatic deletion and the help link.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Localizations.logsWillBeAutomaticallyDeletedAfter30DaysDescriptionLong)

            let helpCenterText = Localizations.forDetailsOnWhatIsAndIsntLoggedVisitTheBitwardenHelpCenter(
                ExternalLinksConstants.helpAndFeedback,
            )
            Text(LocalizedStringKey(helpCenterText))
                .accessibilityLinks(in: helpCenterText)
        }
    }

    /// The header view: symbol, title and explanation, centred on the page background.
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "record.circle")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.red)
                .accessibilityHidden(true)
                .padding(.bottom, 4)

            Text(Localizations.experiencingAnIssue)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text(Localizations.enableTemporaryLoggingDescriptionLong)
            Text(Localizations.toGetStartedSetALoggingDurationDescriptionLong)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// The menu choice of the logging duration.
    private var loggingDuration: some View {
        Picker(
            Localizations.loggingDuration,
            selection: store.binding(
                get: \.loggingDuration,
                send: EnableFlightRecorderAction.loggingDurationChanged,
            ),
        ) {
            ForEach(FlightRecorderLoggingDuration.allCases, id: \.self) { duration in
                Text(duration.localizedName)
                    .tag(duration)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("LoggingDurationChooser")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    EnableFlightRecorderView(store: Store(processor: StateProcessor(state: EnableFlightRecorderState())))
        .navStackWrapped
}
#endif
