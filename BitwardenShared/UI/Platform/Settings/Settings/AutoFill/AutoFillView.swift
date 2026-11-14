import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AutoFillView

/// A view for configuring auto-fill settings.
///
struct AutoFillView: View {
    // MARK: Properties

    /// The store used to render the view.
    @ObservedObject var store: Store<AutoFillState, AutoFillAction, AutoFillEffect>

    /// An action that opens URLs.
    @Environment(\.openURL) private var openURL

    // MARK: View

    var body: some View {
        Form {
            autofillActionCard

            autoFillSection

            additionalOptionsSection
        }
        .animation(.easeInOut, value: store.state.badgeState?.autofillSetupProgress == .complete)
        .navigationBar(title: Localizations.autofill, titleDisplayMode: .inline)
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearUrl)
        }
        .task {
            await store.perform(.fetchSettingValues)
        }
        .task {
            await store.perform(.streamSettingsBadge)
        }
        .toast(store.binding(
            get: \.toast,
            send: AutoFillAction.toastShown,
        ))
    }

    // MARK: Private views

    /// The action card for setting up autofill.
    @ViewBuilder private var autofillActionCard: some View {
        if store.state.shouldShowAutofillActionCard {
            Section {
                if #available(iOS 18, *) {
                    ActionCard(
                        title: Localizations.autofillWithBitwarden,
                        message: Localizations.autofillWithBitwardenDescriptionLong,
                        actionButtonState: ActionCard.ButtonState(title: Localizations.turnOnNow) {
                            await store.perform(.setUpAutofill)
                        },
                        dismissButtonState: ActionCard.ButtonState(title: Localizations.dismiss) {
                            await store.perform(.dismissSetUpAutofillActionCard)
                        },
                        secondaryButtonState: ActionCard.ButtonState(title: Localizations.learnMoreAboutAutofill) {
                            store.send(.learnMoreAboutAutofillTapped)
                        },
                    ) {
                        BitwardenBadge(badgeValue: "1")
                    }
                } else {
                    ActionCard(
                        title: Localizations.setUpAutofill,
                        actionButtonState: ActionCard.ButtonState(title: Localizations.getStarted) {
                            await store.perform(.setUpAutofill)
                        },
                        dismissButtonState: ActionCard.ButtonState(title: Localizations.dismiss) {
                            await store.perform(.dismissSetUpAutofillActionCard)
                        },
                    ) {
                        BitwardenBadge(badgeValue: "1")
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    /// The additional options section.
    private var additionalOptionsSection: some View {
        Group {
            if store.state.isFillAssistFeatureFlagEnabled {
                Section {
                    Toggle(
                        isOn: store.binding(
                            get: \.isFillAssistEnabled,
                            send: AutoFillAction.toggleFillAssist,
                        ),
                    ) {
                        HStack(spacing: 8) {
                            Text(Localizations.turnOnFillAssist)
                            Button {
                                openURL(ExternalLinksConstants.fillAssistHelp)
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.footnote)
                                    .accessibilityLabel(Localizations.learnMore)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("FillAssistSwitch")
                    .accessibilityLabel(Localizations.turnOnFillAssist)
                } header: {
                    Text(Localizations.additionalOptions)
                } footer: {
                    Text(Localizations.turnOnFillAssistDescriptionLong)
                }
            }

            Section {
                Toggle(
                    Localizations.copyTotpAutomatically,
                    isOn: store.binding(
                        get: \.isCopyTOTPToggleOn,
                        send: AutoFillAction.toggleCopyTOTPToggle,
                    ),
                )
                .accessibilityIdentifier("CopyTotpAutomaticallySwitch")
                .accessibilityLabel(Localizations.copyTotpAutomatically)
            } header: {
                if !store.state.isFillAssistFeatureFlagEnabled {
                    Text(Localizations.additionalOptions)
                }
            } footer: {
                Text(Localizations.copyTotpAutomaticallyDescription)
            }

            Section {
                Picker(
                    Localizations.defaultUriMatchDetection,
                    selection: store.binding(
                        get: \.defaultUriMatchType,
                        send: AutoFillAction.defaultUriMatchTypeChanged,
                    ),
                ) {
                    ForEach(store.state.uriMatchTypeOptions, id: \.self) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("DefaultUriMatchDetectionChooser")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Localizations.uriMatchDetectionControlsHowBitwardenIdentifiesAutofillSuggestions)

                    if let warningMessage = store.state.warningMessage {
                        Text(LocalizedStringKey(warningMessage))
                    }
                }
            }
        }
    }

    /// The auto-fill section.
    private var autoFillSection: some View {
        Section(Localizations.autofill) {
            if store.state.shouldShowPasswordAutofill {
                NativeSettingsRow(
                    action: { store.send(.passwordAutoFillTapped) },
                    symbol: "key.viewfinder",
                    title: Localizations.passwordAutofill,
                )
            }

            NativeSettingsRow(
                action: { store.send(.appExtensionTapped) },
                symbol: "puzzlepiece.extension",
                title: Localizations.appExtension,
            )
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    NavigationView {
        AutoFillView(store: Store(processor: StateProcessor(state: AutoFillState())))
    }
}

#Preview("Autofill Action Card") {
    NavigationView {
        AutoFillView(store: Store(processor: StateProcessor(state: AutoFillState(
            badgeState: .fixture(autofillSetupProgress: .setUpLater),
        ))))
    }
}
#endif
