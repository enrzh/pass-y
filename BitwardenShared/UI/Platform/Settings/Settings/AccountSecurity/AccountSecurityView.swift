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

            if store.state.showUnlockOptions {
                unlockOptionsSection
            }

            // Pass-Y: no "Authenticator sync" row; the sync with Bitwarden's Authenticator app cannot work with
            // Pass-Y's own bundle IDs/app group/team (see `DefaultStateService.isAuthenticatorSyncAvailable`).
            if DefaultStateService.isAuthenticatorSyncAvailable {
                authenticatorSyncSection
            }

            sessionTimeoutSection

            otherSection
        }
        .animation(.easeInOut, value: store.state.badgeState?.vaultUnlockSetupProgress == .complete)
        .navigationBar(title: Localizations.accountSecurity, titleDisplayMode: .inline)
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
            PassYSetupSection(
                title: Localizations.setUpUnlock,
                systemImage: "lock.open.fill",
                tint: .blue,
                action: .init(title: Localizations.getStarted) {
                    store.send(.showSetUpUnlock)
                },
                dismiss: .init(title: Localizations.dismiss) {
                    await store.perform(.dismissSetUpUnlockActionCard)
                },
            )
        }
    }

    /// The account rows (fingerprint phrase, devices), then the session actions (lock, log out) and, on its own,
    /// the account deletion.
    @ViewBuilder private var otherSection: some View {
        Section(Localizations.other) {
            PassYSettingsRow(
                Localizations.accountFingerprintPhrase,
                systemImage: "touchid",
                tint: .pink,
                accessory: .external,
                identifier: "AccountFingerprintPhraseLabel",
            ) {
                Task {
                    await store.perform(.accountFingerprintPhrasePressed)
                }
            }

            if store.state.isManageDevicesEnabled {
                PassYSettingsRow(
                    Localizations.devices,
                    systemImage: "laptopcomputer.and.iphone",
                    tint: .blue,
                    identifier: "ManageDevicesLabel",
                ) {
                    store.send(.manageDevicesTapped)
                }
            }
        }

        Section {
            if store.state.isLockNowVisible {
                PassYSettingsRow(
                    Localizations.lockNow,
                    systemImage: "lock.fill",
                    tint: .gray,
                    accessory: .none,
                    identifier: "LockNowLabel",
                ) {
                    Task {
                        await store.perform(.lockVault)
                    }
                }
            }

            PassYSettingsRow(
                Localizations.logOut,
                systemImage: "rectangle.portrait.and.arrow.right",
                role: .destructive,
                accessory: .none,
                identifier: "LogOutLabel",
            ) {
                store.send(.logout)
            }
        }

        Section {
            PassYSettingsRow(
                Localizations.deleteAccount,
                systemImage: "trash.fill",
                role: .destructive,
                accessory: .none,
                identifier: "DeleteAccountLabel",
            ) {
                store.send(.deleteAccountPressed)
            }
        }
    }

    /// The session timeout section.
    @ViewBuilder private var sessionTimeoutSection: some View {
        Section {
            Picker(
                selection: store.binding(
                    get: \.sessionTimeoutValue,
                    send: AccountSecurityAction.sessionTimeoutValueChanged,
                ),
            ) {
                ForEach(store.state.availableTimeoutOptions, id: \.self) { option in
                    Text(option.localizedName).tag(option)
                }
            } label: {
                PassYSettingsRowLabel(title: Localizations.sessionTimeout, systemImage: "timer", tint: .orange)
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
                PassYFooterText(message)
            }
        }

        Section {
            Picker(
                selection: store.binding(
                    get: \.sessionTimeoutAction,
                    send: AccountSecurityAction.sessionTimeoutActionChanged,
                ),
            ) {
                ForEach(store.state.availableTimeoutActions, id: \.self) { action in
                    Text(action.localizedName).tag(action)
                }
            } label: {
                PassYSettingsRowLabel(
                    title: Localizations.sessionTimeoutAction,
                    systemImage: "rectangle.portrait.and.arrow.right",
                    tint: .orange,
                )
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("VaultTimeoutActionChooser")
            .disabled(store.state.isSessionTimeoutActionDisabled)
        } footer: {
            if let message = store.state.policyTimeoutActionMessage {
                PassYFooterText(message)
            }
        }
    }

    /// The unlock options section.
    private var unlockOptionsSection: some View {
        Section(Localizations.unlockOptions) {
            biometricsSetting

            if store.state.unlockWithPinFeatureAvailable {
                PassYToggleRow(
                    Localizations.unlockWithPIN,
                    systemImage: "circle.grid.3x3.fill",
                    tint: .blue,
                    isOn: store.bindingAsync(
                        get: \.isUnlockWithPINCodeOn,
                        perform: AccountSecurityEffect.toggleUnlockWithPINCode,
                    ),
                    identifier: "UnlockWithPinSwitch",
                )
            }
        }
    }

    /// The authenticator sync section.
    @ViewBuilder private var authenticatorSyncSection: some View {
        Section(Localizations.authenticatorSync) {
            PassYToggleRow(
                Localizations.allowAuthenticatorSyncing,
                systemImage: "arrow.triangle.2.circlepath",
                tint: .teal,
                isOn: store.bindingAsync(
                    get: \.isAuthenticatorSyncEnabled,
                    perform: AccountSecurityEffect.toggleSyncWithAuthenticator,
                ),
                identifier: Localizations.allowAuthenticatorSyncing,
            )
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
        PassYToggleRow(
            toggleText,
            systemImage: type == .touchID ? "touchid" : (type == .opticID ? "opticid" : "faceid"),
            tint: .green,
            isOn: store.bindingAsync(
                get: { _ in enabled },
                perform: AccountSecurityEffect.toggleUnlockWithBiometrics,
            ),
            identifier: "UnlockWithBiometricsSwitch",
        )
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
