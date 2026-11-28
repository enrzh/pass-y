import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ViewLoginItemView

/// The credentials card of a login item (Apple Passwords): username, password (masked, eye button), passkey and
/// verification code as tap-to-copy rows, then the breach check as a quiet action row. No section title.
struct ViewLoginItemView: View {
    // MARK: Private Properties

    @Environment(\.openURL) private var openURL

    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ViewLoginItemState, ViewItemAction, ViewItemEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    // MARK: View

    var body: some View {
        if !store.state.isEmpty {
            Section {
                if !store.state.username.isEmpty {
                    usernameRow
                }

                if !store.state.password.isEmpty {
                    passwordRow
                }

                if let fido2Credential = store.state.fido2Credentials.first {
                    passkeyRow(fido2Credential)
                }

                if let totpModel = store.state.totpCode {
                    if store.state.isTOTPAvailable {
                        totpRow(totpModel)
                    } else {
                        premiumSubscriptionRequired
                    }
                }

                checkPasswordRow
            }
        }
    }

    // MARK: Private views

    /// The password row: masked until revealed (eye button or long press), tap copies.
    @ViewBuilder private var passwordRow: some View {
        let password = store.state.password
        PassYCopyRow(
            Localizations.password,
            value: password,
            secret: store.state.canViewPassword
                ? .init(isRevealed: store.state.isPasswordVisible, revealIdentifier: "ShowLoginPasswordButton") {
                    store.send(.passwordVisibilityPressed)
                }
                : nil,
            identifier: "LoginPasswordEntry",
            isMonospaced: true,
            copy: store.state.canViewPassword
                ? { store.send(.copyPressed(value: password, field: .password)) }
                : nil,
        )
    }

    /// "Check for data breaches" as a quiet action row (Apple style, no blue link).
    @ViewBuilder private var checkPasswordRow: some View {
        if store.state.canViewPassword, !store.state.password.isEmpty {
            PassYInlineButtonRow(
                Localizations.checkPasswordForDataBreaches,
                systemImage: "checkmark.shield",
                style: .plain,
                identifier: "CheckPasswordButton",
            ) {
                await store.perform(.checkPasswordPressed)
            }
            .accessibilityLabel(Localizations.checkPassword)
        }
    }

    /// Row signifying that Premium subscription is required for TOTP.
    @ViewBuilder private var premiumSubscriptionRequired: some View {
        PassYCopyRow(
            Localizations.authenticatorKey,
            value: Localizations.notAvailableForThisAccount,
            identifier: "PremiumSubscriptionRequiredButton",
        ) {
            PassYIconButton(Localizations.learnMore, systemImage: "questionmark.circle") {
                openURL(ExternalLinksConstants.authenticatorHelp)
            }
            .accessibilityIdentifier("AuthenticatorHelpButton")
        } copy: {
            store.send(.premiumSubscriptionRequiredTapped)
        }
    }

    /// The username row.
    @ViewBuilder private var usernameRow: some View {
        let username = store.state.username
        PassYCopyRow(Localizations.username, value: username, identifier: "LoginUsernameEntry") {
            store.send(.copyPressed(value: username, field: .username))
        }
    }

    // MARK: Methods

    /// The passkey row (informational, nothing to copy).
    private func passkeyRow(_ fido2Credential: Fido2CredentialView) -> some View {
        PassYCopyRow(
            Localizations.passkey,
            value: Localizations.createdX(fido2Credential.creationDate.dateTimeDisplay),
            identifier: "LoginPasskeyEntry",
            copy: nil,
        )
    }

    /// The verification code row: the code in two groups, the countdown ring on the page clock, tap copies.
    private func totpRow(_ model: TOTPCodeModel) -> some View {
        PassYCopyRow(
            Localizations.verificationCode,
            value: PassYOneTimeCode.display(model.code),
            identifier: "LoginTotpEntry",
            isMonospaced: true,
        ) {
            PassYCodeExpiry(period: Int(model.period), generatedAt: model.codeGenerationDate) {
                Task { await store.perform(.totpCodeExpired) }
            }
        } copy: {
            store.send(.copyPressed(value: model.code, field: .totp))
        }
        .passYCountdownClock(timeProvider: timeProvider)
    }
}
