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
            PassYSetupSection(
                title: Localizations.autofillWithBitwarden,
                message: Localizations.autofillWithBitwardenDescriptionLong,
                systemImage: "key.fill",
                tint: .green,
                action: .init(title: Localizations.turnOnNow) {
                    await store.perform(.setUpAutofill)
                },
                secondary: .init(title: Localizations.learnMoreAboutAutofill) {
                    store.send(.learnMoreAboutAutofillTapped)
                },
                dismiss: .init(title: Localizations.dismiss) {
                    await store.perform(.dismissSetUpAutofillActionCard)
                },
            )
        }
    }

    /// The additional options section.
    private var additionalOptionsSection: some View {
        Group {
            if store.state.isFillAssistFeatureFlagEnabled {
                Section {
                    PassYToggleRow(
                        Localizations.turnOnFillAssist,
                        systemImage: "wand.and.stars",
                        tint: .purple,
                        isOn: store.binding(
                            get: \.isFillAssistEnabled,
                            send: AutoFillAction.toggleFillAssist,
                        ),
                        identifier: "FillAssistSwitch",
                    )
                } header: {
                    Text(Localizations.additionalOptions)
                } footer: {
                    PassYFooterText(Localizations.turnOnFillAssistDescriptionLong, link: Localizations.learnMore) {
                        openURL(ExternalLinksConstants.fillAssistHelp)
                    }
                }
            }

            Section {
                PassYToggleRow(
                    Localizations.copyTotpAutomatically,
                    systemImage: "doc.on.clipboard.fill",
                    tint: .blue,
                    isOn: store.binding(
                        get: \.isCopyTOTPToggleOn,
                        send: AutoFillAction.toggleCopyTOTPToggle,
                    ),
                    identifier: "CopyTotpAutomaticallySwitch",
                )
            } header: {
                if !store.state.isFillAssistFeatureFlagEnabled {
                    Text(Localizations.additionalOptions)
                }
            } footer: {
                PassYFooterText(Localizations.copyTotpAutomaticallyDescription)
            }

            Section {
                Picker(
                    selection: store.binding(
                        get: \.defaultUriMatchType,
                        send: AutoFillAction.defaultUriMatchTypeChanged,
                    ),
                ) {
                    ForEach(store.state.uriMatchTypeOptions, id: \.self) { option in
                        Text(option.localizedName).tag(option)
                    }
                } label: {
                    PassYSettingsRowLabel(
                        title: Localizations.defaultUriMatchDetection,
                        systemImage: "link",
                        tint: .indigo,
                    )
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("DefaultUriMatchDetectionChooser")
            } footer: {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.small) {
                    PassYFooterText(Localizations.uriMatchDetectionControlsHowBitwardenIdentifiesAutofillSuggestions)

                    if let warningMessage = store.state.warningMessage {
                        Label {
                            Text(LocalizedStringKey(warningMessage))
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        .font(.footnote)
                    }
                }
            }
        }
    }

    /// The auto-fill section.
    private var autoFillSection: some View {
        Section(Localizations.autofill) {
            if store.state.shouldShowPasswordAutofill {
                PassYSettingsRow(Localizations.passwordAutofill, systemImage: "key.viewfinder", tint: .green) {
                    store.send(.passwordAutoFillTapped)
                }
            }

            PassYSettingsRow(Localizations.appExtension, systemImage: "puzzlepiece.extension.fill", tint: .blue) {
                store.send(.appExtensionTapped)
            }
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
