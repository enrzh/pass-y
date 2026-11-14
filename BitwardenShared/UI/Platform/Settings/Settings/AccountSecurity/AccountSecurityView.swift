import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AccountSecurityView

/// A view that allows the user to update their account security settings.
///
struct AccountSecurityView: View {
    // MARK: Properties

    /// An action that opens URLs.
    @Environment(\.openURL) private var openURL

    /// The store used to render the view.
    @ObservedObject var store: Store<AccountSecurityState, AccountSecurityAction, AccountSecurityEffect>

    // MARK: View

    var body: some View {
        Form {
            setUpUnlockActionCard

            if !store.state.isManageDevicesEnabled {
                pendingLoginRequests
            }

            if store.state.showUnlockOptions {
                unlockOptionsSection
            }

            authenticatorSyncSection

            sessionTimeoutSection

            otherSection
        }
        .animation(.easeInOut, value: store.state.badgeState?.vaultUnlockSetupProgress == .complete)
        .navigationBar(title: Localizations.accountSecurity, titleDisplayMode: .inline)
        .onChange(of: store.state.twoStepLoginUrl) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearTwoStepLoginUrl)
        }
        .onChange(of: store.state.fingerprintPhraseUrl) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearFingerprintPhraseUrl)
        }
        .task {
            await store.perform(.appeared)
        }
        .task {
            await store.perform(.loadData)
        }
        .task {
            await store.perform(.streamSettingsBadge)
        }
    }

    // MARK: Private views

    /// The action card for setting up vault unlock methods.
    @ViewBuilder private var setUpUnlockActionCard: some View {
        if let progress = store.state.badgeState?.vaultUnlockSetupProgress, progress != .complete {
            Section {
                ActionCard(
                    title: Localizations.setUpUnlock,
                    actionButtonState: ActionCard.ButtonState(title: Localizations.getStarted) {
                        store.send(.showSetUpUnlock)
                    },
                    dismissButtonState: ActionCard.ButtonState(title: Localizations.dismiss) {
                        await store.perform(.dismissSetUpUnlockActionCard)
                    },
                ) {
                    BitwardenBadge(badgeValue: "1")
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    /// The other section.
    private var otherSection: some View {
        Section(Localizations.other) {
            NativeSettingsRow(
                action: {
                    Task {
                        await store.perform(.accountFingerprintPhrasePressed)
                    }
                },
                accessibilityIdentifier: "AccountFingerprintPhraseLabel",
                symbol: "touchid",
                title: Localizations.accountFingerprintPhrase,
            )

            NativeSettingsRow(
                accessory: .symbol("arrow.up.right.square"),
                action: { store.send(.twoStepLoginPressed) },
                accessibilityIdentifier: "TwoStepLoginLinkItemView",
                symbol: "lock.shield",
                title: Localizations.twoStepLogin,
            )

            if store.state.isManageDevicesEnabled {
                NativeSettingsRow(
                    action: { store.send(.manageDevicesTapped) },
                    accessibilityIdentifier: "ManageDevicesLabel",
                    symbol: "iphone.and.ipad",
                    title: Localizations.devices,
                )
            }

            if store.state.isLockNowVisible {
                NativeSettingsRow(
                    accessory: .none,
                    action: {
                        Task {
                            await store.perform(.lockVault)
                        }
                    },
                    accessibilityIdentifier: "LockNowLabel",
                    symbol: "lock",
                    title: Localizations.lockNow,
                )
            }

            NativeSettingsRow(
                accessory: .none,
                action: { store.send(.logout) },
                accessibilityIdentifier: "LogOutLabel",
                symbol: "rectangle.portrait.and.arrow.right",
                titleStyle: .red,
                title: Localizations.logOut,
            )

            NativeSettingsRow(
                accessory: .none,
                action: { store.send(.deleteAccountPressed) },
                accessibilityIdentifier: "DeleteAccountLabel",
                symbol: "trash",
                titleStyle: .red,
                title: Localizations.deleteAccount,
            )
        }
    }

    /// The pending login requests section.
    private var pendingLoginRequests: some View {
        Section(Localizations.approveLoginRequests) {
            NativeSettingsRow(
                action: { store.send(.pendingLoginRequestsTapped) },
                accessibilityIdentifier: "PendingLogInRequestsLabel",
                symbol: "person.badge.clock",
                title: Localizations.pendingLogInRequests,
            )
        }
    }

    /// The session timeout section.
    @ViewBuilder private var sessionTimeoutSection: some View {
        Section {
            Picker(
                Localizations.sessionTimeout,
                selection: store.binding(
                    get: \.sessionTimeoutValue,
                    send: AccountSecurityAction.sessionTimeoutValueChanged,
                ),
            ) {
                ForEach(store.state.availableTimeoutOptions, id: \.self) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("VaultTimeoutChooser")
            .disabled(store.state.isSessionTimeoutPickerDisabled)

            if store.state.isShowingCustomTimeout {
                SettingsPickerField(
                    title: "",
                    footer: store.state.policyTimeoutCustomMessage,
                    customTimeoutValue: store.state.customTimeoutString,
                    pickerValue: store.binding(
                        get: \.customTimeoutValueSeconds,
                        send: AccountSecurityAction.customTimeoutValueSecondsChanged,
                    ),
                    customTimeoutAccessibilityLabel: store.state.customTimeoutAccessibilityLabel,
                )
            }
        } header: {
            Text(Localizations.sessionTimeout)
        } footer: {
            if let message = store.state.policyTimeoutMessage {
                Text(message)
            }
        }

        Section {
            Picker(
                Localizations.sessionTimeoutAction,
                selection: store.binding(
                    get: \.sessionTimeoutAction,
                    send: AccountSecurityAction.sessionTimeoutActionChanged,
                ),
            ) {
                ForEach(store.state.availableTimeoutActions, id: \.self) { action in
                    Text(action.localizedName).tag(action)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("VaultTimeoutActionChooser")
            .disabled(store.state.isSessionTimeoutActionDisabled)
        } footer: {
            if let message = store.state.policyTimeoutActionMessage {
                Text(message)
            }
        }
    }

    /// The unlock options section.
    private var unlockOptionsSection: some View {
        Section(Localizations.unlockOptions) {
            biometricsSetting

            if store.state.unlockWithPinFeatureAvailable {
                Toggle(
                    Localizations.unlockWithPIN,
                    isOn: store.bindingAsync(
                        get: \.isUnlockWithPINCodeOn,
                        perform: AccountSecurityEffect.toggleUnlockWithPINCode,
                    ),
                )
                .accessibilityIdentifier("UnlockWithPinSwitch")
                .accessibilityLabel(Localizations.unlockWithPIN)
            }
        }
    }

    /// The authenticator sync section.
    @ViewBuilder private var authenticatorSyncSection: some View {
        Section(Localizations.authenticatorSync) {
            Toggle(
                Localizations.allowAuthenticatorSyncing,
                isOn: store.bindingAsync(
                    get: \.isAuthenticatorSyncEnabled,
                    perform: AccountSecurityEffect.toggleSyncWithAuthenticator,
                ),
            )
            .accessibilityIdentifier(Localizations.allowAuthenticatorSyncing)
            .accessibilityLabel(Localizations.allowAuthenticatorSyncing)
        }
    }

    /// A view for the user's biometrics setting
    ///
    @ViewBuilder private var biometricsSetting: some View {
        switch store.state.biometricUnlockStatus {
        case let .available(type, enabled: enabled):
            biometricUnlockToggle(enabled: enabled, type: type)
        default:
            EmptyView()
        }
    }

    /// A toggle for the user's biometric unlock preference.
    ///
    @ViewBuilder
    private func biometricUnlockToggle(enabled: Bool, type: BiometricAuthenticationType) -> some View {
        let toggleText = biometricsToggleText(type)
        Toggle(
            toggleText,
            isOn: store.bindingAsync(
                get: { _ in enabled },
                perform: AccountSecurityEffect.toggleUnlockWithBiometrics,
            ),
        )
        .accessibilityIdentifier("UnlockWithBiometricsSwitch")
        .accessibilityLabel(toggleText)
    }

    private func biometricsToggleText(_ biometryType: BiometricAuthenticationType) -> String {
        switch biometryType {
        case .faceID:
            Localizations.unlockWithFaceID
        case .opticID:
            Localizations.unlockWithOpticID
        case .touchID:
            Localizations.unlockWithTouchID
        case .unknown:
            Localizations.unlockWithBiometrics
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    NavigationView {
        AccountSecurityView(
            store: Store(processor: StateProcessor(state: AccountSecurityState())),
        )
    }
}

#Preview("Vault Unlock Action Card") {
    NavigationView {
        AccountSecurityView(store: Store(processor: StateProcessor(state: AccountSecurityState(
            badgeState: .fixture(vaultUnlockSetupProgress: .setUpLater),
        ))))
    }
}
#endif
