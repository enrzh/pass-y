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
                PassYSettingsRow(
                    Localizations.syncNow,
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .blue,
                    accessory: .none,
                    identifier: "SyncNowButton",
                ) {
                    Task { await store.perform(.syncNow) }
                }
                PassYToggleRow(
                    Localizations.enableSyncOnRefresh,
                    systemImage: "arrow.down.circle.fill",
                    tint: .blue,
                    isOn: store.binding(
                        get: \.isAllowSyncOnRefreshToggleOn,
                        send: OtherSettingsAction.toggleAllowSyncOnRefresh,
                    ),
                    identifier: "SyncOnRefreshSwitch",
                )
            } footer: {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.small) {
                    Group {
                        if let lastSyncDate = store.state.lastSyncDate {
                            Text("\(Localizations.lastSync) \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                        } else {
                            Text(Localizations.lastSync + " --")
                        }
                    }
                    .accessibilityIdentifier("LastSyncLabel")
                    PassYFooterText(Localizations.enableSyncOnRefreshDescription)
                }
                .font(.footnote)
            }

            Section {
                Picker(
                    selection: store.binding(
                        get: \.clearClipboardValue,
                        send: OtherSettingsAction.clearClipboardValueChanged,
                    ),
                ) {
                    ForEach(ClearClipboardValue.allCases, id: \.self) { value in
                        Text(value.localizedName).tag(value)
                    }
                } label: {
                    PassYSettingsRowLabel(title: Localizations.clearClipboard, systemImage: "clipboard.fill", tint: .orange)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ClearClipboardChooser")
                PassYToggleRow(
                    Localizations.allowUniversalClipboard,
                    systemImage: "laptopcomputer.and.iphone",
                    tint: .orange,
                    isOn: store.binding(
                        get: \.isAllowUniversalClipboardToggleOn,
                        send: OtherSettingsAction.toggleAllowUniversalClipboard,
                    ),
                    identifier: "UniversalClipboardChooser",
                )
            } footer: {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.small) {
                    PassYFooterText(Localizations.clearClipboardDescription)
                    PassYFooterText(Localizations.useUniversalClipboardToCopyDescriptionLong)
                }
            }

            if store.state.shouldShowConnectToWatchToggle {
                Section {
                    PassYToggleRow(
                        Localizations.connectToWatch,
                        systemImage: "applewatch",
                        tint: .gray,
                        isOn: store.binding(
                            get: \.isConnectToWatchToggleOn,
                            send: OtherSettingsAction.toggleConnectToWatch,
                        ),
                    )
                }
            }

            Section {
                PassYToggleRow(
                    Localizations.siriAndShortcutsAccess,
                    systemImage: "square.2.layers.3d.fill",
                    tint: .purple,
                    isOn: store.binding(
                        get: \.isSiriAndShortcutsAccessToggleOn,
                        send: OtherSettingsAction.toggleSiriAndShortcutsAccessToggleOn,
                    ),
                    identifier: "SiriAndShortcutsAccessSwitch",
                )
            } footer: {
                PassYFooterText(Localizations.enableToAllowTheAppToRespondToSiriAndShortcutsUsingAppIntents)
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
