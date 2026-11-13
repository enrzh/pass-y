import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - OtherSettingsView

/// A view that allows users to configure miscellaneous settings.
///
struct OtherSettingsView: View {
    // MARK: Properties

    /// An action that opens URLs.
    @Environment(\.openURL) private var openURL

    /// The store used to render the view.
    @ObservedObject var store: Store<OtherSettingsState, OtherSettingsAction, OtherSettingsEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                Toggle(
                    Localizations.enableSyncOnRefresh,
                    isOn: store.binding(
                        get: \.isAllowSyncOnRefreshToggleOn,
                        send: OtherSettingsAction.toggleAllowSyncOnRefresh,
                    ),
                )
                .accessibilityIdentifier("SyncOnRefreshSwitch")
                .accessibilityLabel(Localizations.enableSyncOnRefresh)
            } footer: {
                Text(Localizations.enableSyncOnRefreshDescription)
            }

            Section {
                AsyncButton {
                    await store.perform(.syncNow)
                } label: {
                    HStack {
                        Label(Localizations.syncNow, systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("SyncNowButton")
            } footer: {
                if let lastSyncDate = store.state.lastSyncDate {
                    FormattedDateTimeView(label: Localizations.lastSync, separator: "", date: lastSyncDate)
                        .accessibilityIdentifier("LastSyncLabel")
                } else {
                    Text(Localizations.lastSync + " --")
                        .accessibilityIdentifier("LastSyncLabel")
                }
            }

            Section {
                Picker(
                    Localizations.clearClipboard,
                    selection: store.binding(
                        get: \.clearClipboardValue,
                        send: OtherSettingsAction.clearClipboardValueChanged,
                    ),
                ) {
                    ForEach(ClearClipboardValue.allCases, id: \.self) { value in
                        Text(value.localizedName).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ClearClipboardChooser")
            } footer: {
                Text(Localizations.clearClipboardDescription)
            }

            Section {
                Toggle(
                    Localizations.allowUniversalClipboard,
                    isOn: store.binding(
                        get: \.isAllowUniversalClipboardToggleOn,
                        send: OtherSettingsAction.toggleAllowUniversalClipboard,
                    ),
                )
                .accessibilityIdentifier("UniversalClipboardChooser")
                .accessibilityLabel(Localizations.allowUniversalClipboard)
            } footer: {
                Text(Localizations.useUniversalClipboardToCopyDescriptionLong)
            }

            if store.state.shouldShowConnectToWatchToggle {
                Section {
                    Toggle(
                        Localizations.connectToWatch,
                        isOn: store.binding(
                            get: \.isConnectToWatchToggleOn,
                            send: OtherSettingsAction.toggleConnectToWatch,
                        ),
                    )
                    .accessibilityLabel(Localizations.connectToWatch)
                }
            }

            Section {
                Toggle(
                    Localizations.siriAndShortcutsAccess,
                    isOn: store.binding(
                        get: \.isSiriAndShortcutsAccessToggleOn,
                        send: OtherSettingsAction.toggleSiriAndShortcutsAccessToggleOn,
                    ),
                )
                .accessibilityIdentifier("SiriAndShortcutsAccessSwitch")
                .accessibilityLabel(Localizations.siriAndShortcutsAccess)
            } footer: {
                Text(Localizations.enableToAllowTheAppToRespondToSiriAndShortcutsUsingAppIntents)
            }
        }
        .navigationBar(title: Localizations.other, titleDisplayMode: .inline)
        .toast(store.binding(
            get: \.toast,
            send: OtherSettingsAction.toastShown,
        ))
        .task {
            await store.perform(.streamLastSyncTime)
        }
        .task {
            await store.perform(.loadInitialValues)
        }
    }
}

// MARK: Previews

#Preview {
    OtherSettingsView(store: Store(processor: StateProcessor(state: OtherSettingsState())))
}
