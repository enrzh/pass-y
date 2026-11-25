import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AddEditItemView

/// A view that allows the user to add or edit a cipher to a vault.
///
struct AddEditLoginItemView: View {
    // MARK: Types

    /// The focusable fields in a login view.
    enum FocusedField: Int, Hashable {
        case userName
        case password
        case totp
    }

    // MARK: Properties

    /// The currently focused field.
    @FocusState private var focusedField: FocusedField?

    /// The `Store` for this view.
    @ObservedObject var store: Store<LoginItemState, AddEditItemAction, AddEditItemEffect>

    /// The closure to call when the fields are rendered for the guided tour.
    var didRenderFrame: ((GuidedTourStep, CGRect) -> Void)?

    // MARK: View

    var body: some View {
        Section {
            usernameField

            passwordField

            checkPasswordRow

            fidoField
        }

        Section {
            totpView
                .guidedTourStep(.step2) { frame in
                    didRenderFrame?(.step2, frame)
                }

            if store.state.canViewPassword {
                PassYInlineButtonRow(
                    Localizations.setUpAuthenticatorKey,
                    systemImage: "qrcode.viewfinder",
                    identifier: "SetupTotpButton",
                ) {
                    await store.perform(.setupTotpPressed)
                }
            }
        }

        uriSection
    }

    // MARK: Private views

    /// "Check for data breaches" below the password.
    @ViewBuilder private var checkPasswordRow: some View {
        if store.state.canViewPassword {
            PassYInlineButtonRow(
                Localizations.checkPasswordForDataBreaches,
                systemImage: "checkmark.shield",
                style: .plain,
                identifier: "CheckPasswordButton",
            ) {
                await store.perform(.checkPasswordPressed)
            }
        }
    }

    /// The passkey (informational) with its remove button.
    @ViewBuilder var fidoField: some View {
        if let fido2Credential = store.state.fido2Credentials.first {
            PassYCopyRow(
                Localizations.passkey,
                value: Localizations.createdX(fido2Credential.creationDate.dateTimeDisplay),
                identifier: "LoginPasskeyEntry",
                accessory: {
                if store.state.canViewPassword, store.state.editView {
                    PassYIconButton(Localizations.removePasskey, systemImage: "minus.circle.fill", role: .destructive) {
                        store.send(.removePasskeyPressed)
                    }
                    .accessibilityIdentifier("LoginRemovePasskeyButton")
                }
                },
                copy: nil,
            )
        }
    }

    /// The password: masked, eye button, generate button.
    private var passwordField: some View {
        PassYSecureField(
            Localizations.password,
            text: store.binding(
                get: \.password,
                send: AddEditItemAction.passwordChanged,
            ),
            isRevealed: store.binding(
                get: \.isPasswordVisible,
                send: AddEditItemAction.togglePasswordVisibilityChanged,
            ),
            canReveal: store.state.canViewPassword,
            identifier: "LoginPasswordEntry",
            revealIdentifier: "ViewPasswordButton",
            focus: .field($focusedField, equals: .password),
        ) {
            if store.state.canViewPassword {
                PassYIconButton(Localizations.generatePassword, systemImage: "arrow.trianglehead.2.clockwise") {
                    store.send(.generatePasswordPressed)
                }
                .guidedTourStep(.step1) { frame in
                    didRenderFrame?(.step1, frame)
                }
                .accessibilityIdentifier("RegeneratePasswordButton")
            }
        }
        .disabled(!store.state.canViewPassword)
        .textFieldConfiguration(.password)
        .onSubmit { focusNextField($focusedField) }
    }

    /// The authenticator key (masked, eye button, copy button once set).
    @ViewBuilder private var totpView: some View {
        if store.state.canViewPassword {
            PassYSecureField(
                Localizations.authenticatorKey,
                text: store.binding(
                    get: \.authenticatorKey,
                    send: AddEditItemAction.totpKeyChanged,
                ),
                isRevealed: store.binding(
                    get: \.isAuthKeyVisible,
                    send: AddEditItemAction.authKeyVisibilityTapped,
                ),
                identifier: "LoginTotpEntry",
                revealIdentifier: "TextVisibilityToggle",
                focus: .field($focusedField, equals: .totp),
            ) {
                if !store.state.authenticatorKey.isEmpty {
                    PassYIconButton(Localizations.copyTotp, systemImage: "doc.on.doc") {
                        Task { await store.perform(.copyTotpPressed) }
                    }
                    .accessibilityIdentifier("CopyTotpButton")
                }
            }
            .onSubmit {
                store.send(.totpFieldLeftFocus)
                focusNextField($focusedField)
            }
        } else {
            PassYCopyRow(
                Localizations.authenticatorKey,
                value: store.state.authenticatorKey,
                secret: .init(isRevealed: false, canReveal: false) {},
                copy: nil,
            )
        }
    }

    /// The websites: one field per URI with an options menu (match detection, remove), then "Add website".
    @ViewBuilder private var uriSection: some View {
        Section {
            ForEachIndexed(store.state.uris) { index, uriState in
                PassYFormField(
                    Localizations.websiteURI,
                    text: store.binding(
                        get: { _ in uriState.uri },
                        send: { AddEditItemAction.uriChanged($0, index: index) },
                    ),
                    prompt: "example.com",
                    identifier: "LoginUriEntry",
                ) {
                    Menu {
                        Picker(Localizations.matchDetection, selection: store.binding(
                            get: { _ in uriState.matchType },
                            send: { .uriTypeChanged($0, index: index) },
                        )) {
                            ForEach(store.state.uriMatchTypeOptions, id: \.hashValue) { option in
                                if option == DefaultableType<UriMatchType>.default {
                                    Text(store.state.defaultUriMatchTypeOptionLabel).tag(option)
                                } else {
                                    Text(option.localizedName).tag(option)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        Button(Localizations.remove, systemImage: "trash", role: .destructive) {
                            withAnimation {
                                store.send(.removeUriPressed(index: index))
                            }
                        }
                    } label: {
                        Label(Localizations.options, systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("LoginUriOptionsButton")
                }
                .textFieldConfiguration(.url)
            }

            PassYInlineButtonRow(Localizations.addWebsite, systemImage: "plus", identifier: "LoginAddNewUriButton") {
                withAnimation {
                    store.send(.newUriPressed)
                }
            }
        }
        .guidedTourStep(.step3) { frame in
            didRenderFrame?(.step3, frame)
        }
    }

    /// The username with its generate button.
    private var usernameField: some View {
        PassYFormField(
            Localizations.username,
            text: store.binding(
                get: \.username,
                send: AddEditItemAction.usernameChanged,
            ),
            identifier: "LoginUsernameEntry",
            focus: .field($focusedField, equals: .userName),
        ) {
            PassYIconButton(Localizations.generateUsername, systemImage: "wand.and.stars") {
                store.send(.generateUsernamePressed)
            }
            .accessibilityIdentifier("GenerateUsernameButton")
        }
        .textFieldConfiguration(.username)
        .onSubmit { focusNextField($focusedField) }
    }
}

// MARK: Previews

#if DEBUG
private enum AddEditLoginItemPreviewData {
    // swiftlint:disable:next line_length
    static let key = "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA1&digits=6&period=30"
}

#Preview("Empty Add Edit State") {
    NavigationView {
        Form {
            Group {
                AddEditLoginItemView(
                    store: Store(
                        processor: StateProcessor(
                            state: LoginItemState(
                                isTOTPAvailable: false,
                                totpState: .none,
                            ),
                        ),
                    ),
                )
            }
        }
    }
}

#Preview("Auth Key") {
    NavigationView {
        Form {
            Group {
                AddEditLoginItemView(
                    store: Store(
                        processor: StateProcessor(
                            state: LoginItemState(
                                isTOTPAvailable: true,
                                totpState: .init(AddEditLoginItemPreviewData.key),
                            ),
                        ),
                    ),
                )
            }
        }
    }
}
#endif
