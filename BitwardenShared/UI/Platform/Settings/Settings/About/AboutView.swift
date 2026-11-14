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
    private var miscSection: some View {
        Section {
            externalLinkRow(Localizations.bitwardenHelpCenter, symbol: "questionmark.circle", action: .helpCenterTapped)

            externalLinkRow(Localizations.privacyPolicy, symbol: "hand.raised", action: .privacyPolicyTapped)

            externalLinkRow(Localizations.webVault, symbol: "globe", action: .webVaultTapped)

            externalLinkRow(Localizations.learnOrg, symbol: "building.2", action: .learnAboutOrganizationsTapped)

            NativeSettingsRow(
                accessory: .symbol("doc.on.doc"),
                action: {
                    Task {
                        await store.perform(.copyVersionInfo)
                    }
                },
                symbol: "info.circle",
                title: store.state.version,
            )
        } footer: {
            Text(store.state.copyrightText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    /// The submit crash logs toggle.
    private var submitCrashLogs: some View {
        Section {
            Toggle(
                Localizations.submitCrashLogs,
                isOn: store.binding(
                    get: \.isSubmitCrashLogsToggleOn,
                    send: AboutAction.toggleSubmitCrashLogs,
                ),
            )
            .accessibilityIdentifier("SubmitCrashLogsSwitch")
            .accessibilityLabel(Localizations.submitCrashLogs)
        }
    }

    /// Returns a native row configured for an external web link.
    ///
    /// - Parameters:
    ///   - name: The localized name of the row.
    ///   - symbol: The SF Symbol shown before the name.
    ///   - action: An action to send when the row is tapped.
    /// - Returns: A row configured for an external web link.
    ///
    private func externalLinkRow(_ name: String, symbol: String, action: AboutAction) -> some View {
        NativeSettingsRow(
            accessory: .symbol("arrow.up.right.square"),
            action: { store.send(action) },
            symbol: symbol,
            title: name,
        )
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
