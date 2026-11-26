import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AboutView

/// A view that allows users to view miscellaneous information about the app.
///
struct AboutView: View {
    // MARK: Properties

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: Store<AboutState, AboutAction, AboutEffect>

    // MARK: View

    var body: some View {
        Form {
            submitCrashLogs

            flightRecorderSection

            miscSection
        }
        .animation(.default, value: store.state.flightRecorderState.activeLog)
        .navigationBar(title: Localizations.about, titleDisplayMode: .inline)
        .task {
            await store.perform(.streamFlightRecorderLog)
        }
        .toast(store.binding(
            get: \.toast,
            send: AboutAction.toastShown,
        ))
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearURL)
        }
        .onChange(of: store.state.appReviewUrl) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearAppReviewURL)
        }
    }

    // MARK: Private views

    /// The section for the flight recorder.
    @ViewBuilder private var flightRecorderSection: some View {
        Section {
            FlightRecorderSettingsSectionView(
                store: store.child(
                    state: \.flightRecorderState,
                    mapAction: { .flightRecorder($0) },
                    mapEffect: { .flightRecorder($0) },
                ),
            )
        }
    }

    /// The section of miscellaneous about items.
    @ViewBuilder private var miscSection: some View {
        Section {
            externalLinkRow(
                Localizations.bitwardenHelpCenter,
                symbol: "questionmark.circle.fill",
                tint: .blue,
                action: .helpCenterTapped,
            )

            externalLinkRow(Localizations.privacyPolicy, symbol: "hand.raised.fill", tint: .blue, action: .privacyPolicyTapped)

            externalLinkRow(Localizations.learnOrg, symbol: "building.2.fill", tint: .gray, action: .learnAboutOrganizationsTapped)
        }

        Section {
            PassYSettingsRow(store.state.version, systemImage: "info.circle.fill", tint: .gray, accessory: .none) {
                Task {
                    await store.perform(.copyVersionInfo)
                }
            }
            .accessibilityHint(Localizations.copy)
        } footer: {
            Text(store.state.copyrightText)
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, PassYDesign.Spacing.small)
        }
    }

    /// The submit crash logs toggle.
    private var submitCrashLogs: some View {
        Section {
            PassYToggleRow(
                Localizations.submitCrashLogs,
                systemImage: "ladybug.fill",
                tint: .red,
                isOn: store.binding(
                    get: \.isSubmitCrashLogsToggleOn,
                    send: AboutAction.toggleSubmitCrashLogs,
                ),
                identifier: "SubmitCrashLogsSwitch",
            )
        }
    }

    /// Returns a native row configured for an external web link.
    ///
    /// - Parameters:
    ///   - name: The localized name of the row.
    ///   - symbol: The SF Symbol of the row tile.
    ///   - tint: The colour of the row tile.
    ///   - action: An action to send when the row is tapped.
    /// - Returns: A row configured for an external web link.
    ///
    private func externalLinkRow(_ name: String, symbol: String, tint: Color, action: AboutAction) -> some View {
        PassYSettingsRow(name, systemImage: symbol, tint: tint, accessory: .external) {
            store.send(action)
        }
    }
}

// MARK: - Previews

#Preview {
    AboutView(store: Store(processor: StateProcessor(state: AboutState(
        flightRecorderState: FlightRecorderSettingsSectionState(activeLog: FlightRecorderData.LogMetadata(
            duration: .eightHours,
            startDate: Date(timeIntervalSinceNow: 60 * 60 * -4),
        )),
    ))))
}
