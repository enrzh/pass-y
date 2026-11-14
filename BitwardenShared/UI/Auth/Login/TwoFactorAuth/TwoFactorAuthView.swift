import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - TwoFactorAuthView

/// A view that prompts the user for a two-factor authentication code.
///
struct TwoFactorAuthView: View {
    // MARK: Properties

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: Store<TwoFactorAuthState, TwoFactorAuthAction, TwoFactorAuthEffect>

    /// The task running NFC listening, managed manually to allow cancellation when the auth method changes.
    @SwiftUI.State private var nfcTask: Task<Void, Never>?

    /// The text field configuration for the verification field.
    var verificationTextFieldConfiguration: TextFieldConfiguration {
        switch store.state.authMethod {
        case .yubiKey:
            TextFieldConfiguration.oneTimeCode(keyboardType: .default)
        default:
            if #available(iOS 26, *) {
                TextFieldConfiguration.oneTimeCode(
                    // WORKAROUND: Using an iPad with the floating keyboard on iOS 26 will occasionally
                    // crash on this screen when displaying the `numberPad` keyboard type. Using the
                    // default keyboard prevents this. (PM-31717)
                    keyboardType: UIDevice.current.userInterfaceIdiom == .pad ? .default : .numberPad,
                )
            } else {
                TextFieldConfiguration.oneTimeCode()
            }
        }
    }

    // MARK: View

    var body: some View {
        content
            .onChange(of: store.state.url) { newValue in
                guard let url = newValue else { return }
                openURL(url)
                store.send(.clearURL)
            }
            .toast(store.binding(
                get: \.toast,
                send: TwoFactorAuthAction.toastShown,
            ))
            .navigationBar(title: store.state.titleText, titleDisplayMode: .inline)
            .task {
                await store.perform(.appeared)
            }
            .onAppear { updateNFCTask(isYubiKey: store.state.authMethod == .yubiKey) }
            .onChange(of: store.state.authMethod) { newValue in
                updateNFCTask(isYubiKey: newValue == .yubiKey)
            }
            .onDisappear {
                nfcTask?.cancel()
                nfcTask = nil
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelToolbarButton {
                        store.send(.dismiss)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !store.state.deviceVerificationRequired {
                        authMethodsMenu
                    }
                }
            }
    }

    // MARK: Private Views

    /// The two-factor authentication menu buttons.
    private var authMethodsMenu: some View {
        optionsToolbarMenu {
            Menu(Localizations.useAnotherTwoStepMethod) {
                ForEach(store.state.availableAuthMethods) { method in
                    Button(method.title) {
                        store.send(.authMethodSelected(method))
                    }
                }
            }
        }
    }

    /// The main body content of the view
    @ViewBuilder private var content: some View {
        switch store.state.authMethod {
        case .duo,
             .duoOrganization:
            duo2FAView
        case .webAuthn:
            webAuthn2FAView
        default:
            defaultContent
        }
    }

    /// The continue button.
    private var continueButton: some View {
        AsyncButton {
            await store.perform(.continueTapped)
        } label: {
            Text(Localizations.continue)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!store.state.continueEnabled)
        .accessibilityIdentifier("ContinueButton")
    }

    /// The header: method icon (SF Symbol) and instructions.
    @ViewBuilder private var header: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: headerSymbol)
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(store.state.detailsText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .accessibilityElement(children: .combine)
        }
    }

    /// The SF Symbol representing the current method.
    private var headerSymbol: String {
        switch store.state.authMethod {
        case .email: "envelope"
        case .yubiKey: "key.radiowaves.forward"
        case .duo, .duoOrganization: "lock.shield"
        case .webAuthn: "person.badge.key"
        case .recoveryCode: "lifepreserver"
        default: "lock.shield"
        }
    }

    /// Applies the native form look with a visible card background (also inside sheets).
    private func nativeForm(@ViewBuilder _ content: () -> some View) -> some View {
        Form { content() }
            .passYNativeFormBackground()
    }

    /// The body content for most 2FA methods.
    private var defaultContent: some View {
        nativeForm {
            header

            Section {
                TextField(Localizations.verificationCode, text: store.binding(
                    get: \.verificationCode,
                    send: TwoFactorAuthAction.verificationCodeChanged,
                ))
                .textContentType(.oneTimeCode)
                .keyboardType(verificationKeyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .accessibilityIdentifier("VerificationCodeEntry")
                .accessibilityLabel(Localizations.verificationCode)

                if !store.state.deviceVerificationRequired {
                    rememberMeToggle
                }
            }

            Section {
                continueButton
                resendEmailButton
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    /// The keyboard type for the verification field.
    private var verificationKeyboardType: UIKeyboardType {
        if store.state.authMethod == .yubiKey { return .default }
        if #available(iOS 26, *), UIDevice.current.userInterfaceIdiom == .pad { return .default }
        return .numberPad
    }

    /// A view for DUO 2FA type.
    @ViewBuilder private var duo2FAView: some View {
        nativeForm {
            header
            Section { rememberMeToggle }
            Section {
                launchButton(title: Localizations.launchDuo, id: "LaunchDuoButton") {
                    await store.perform(.beginDuoAuth)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    /// A view for WebAuthn 2FA type.
    @ViewBuilder private var webAuthn2FAView: some View {
        nativeForm {
            header
            Section { rememberMeToggle }
            Section {
                launchButton(title: Localizations.launchWebAuthn, id: "LaunchWebAuthnButton") {
                    await store.perform(.beginWebAuthn)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    /// A prominent full-width launch button.
    private func launchButton(title: String, id: String, action: @escaping () async -> Void) -> some View {
        AsyncButton {
            await action()
        } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier(id)
    }

    /// The remember me toggle.
    private var rememberMeToggle: some View {
        Toggle(
            Localizations.rememberMe,
            isOn: store.binding(
                get: { $0.isRememberMeOn },
                send: { .rememberMeToggleChanged($0) },
            ),
        )
        .accessibilityIdentifier("RememberMeSwitch")
    }

    /// The resend email button for the email authentication option.
    @ViewBuilder private var resendEmailButton: some View {
        if store.state.authMethod == .email {
            AsyncButton {
                await store.perform(.resendEmailTapped)
            } label: {
                Label(Localizations.resendCode, systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("ResendCodeButton")
        } else if store.state.authMethod == .yubiKey {
            AsyncButton {
                await store.perform(.tryAgainTapped)
            } label: {
                Label(Localizations.tryAgain, systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("TryAgainButton")
        }
    }

    // MARK: Private Methods

    /// Cancels any in-flight NFC listening task and starts a new one when the YubiKey method is active.
    ///
    /// - Parameter isYubiKey: Whether the current auth method is YubiKey.
    private func updateNFCTask(isYubiKey: Bool) {
        nfcTask?.cancel()
        guard isYubiKey else { return }
        nfcTask = Task { await store.perform(.listenForNFC) }
    }
}

// MARK: - Previews

#Preview {
    TwoFactorAuthView(store: Store(processor: StateProcessor(
        state: TwoFactorAuthState(),
    ))).navStackWrapped
}

#Preview("Duo") {
    TwoFactorAuthView(store: Store(processor: StateProcessor(
        state: TwoFactorAuthState(authMethod: .duo),
    ))).navStackWrapped
}

#Preview("WebAuthn") {
    TwoFactorAuthView(store: Store(processor: StateProcessor(
        state: TwoFactorAuthState(authMethod: .webAuthn),
    ))).navStackWrapped
}
