import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ViewLoginItemView

/// A view for displaying the contents of a login item.
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
            SectionView(Localizations.loginCredentials, contentSpacing: 8) {
                ContentBlock {
                    if !store.state.username.isEmpty {
                        usernameRow
                    }

                    if !store.state.password.isEmpty {
                        passwordRow
                    }

                    if let fido2Credential = store.state.fido2Credentials.first {
                        passkeyRow(fido2Credential)
                    }
                }

                checkPasswordRow

                if let totpModel = store.state.totpCode {
                    if store.state.isTOTPAvailable {
                        totpRow(totpModel)
                    } else {
                        premiumSubscriptionRequired
                    }
                }
            }
        }
    }

    // MARK: Private views

    /// The password row.
    ///
    @ViewBuilder private var passwordRow: some View {
        let password = store.state.password
        BitwardenField(title: Localizations.password, titleAccessibilityIdentifier: "ItemName") {
            PasswordText(password: password, isPasswordVisible: store.state.isPasswordVisible)
                .styleGuide(.body)
                .foregroundColor(SharedAsset.Colors.textPrimary.swiftUIColor)
                .accessibilityIdentifier("LoginPasswordEntry")
        }
        .accessibilityElement(children: .contain)
        .contentShape(Rectangle())
        // Apple Passwords: tap copies, long press offers Reveal and Copy (no eye or copy icons).
        .onTapGesture {
            guard store.state.canViewPassword else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            store.send(.copyPressed(value: password, field: .password))
        }
        .contextMenu {
            if store.state.canViewPassword {
                Button {
                    store.send(.passwordVisibilityPressed)
                } label: {
                    Label(
                        store.state.isPasswordVisible ? "Hide" : "Reveal",
                        systemImage: store.state.isPasswordVisible ? "eye.slash" : "eye",
                    )
                }
                Button {
                    store.send(.copyPressed(value: password, field: .password))
                } label: {
                    Label(Localizations.copy, systemImage: "doc.on.doc")
                }
            }
        }
    }

    /// "Check password for data breaches" as a plain row with a symbol (Apple style, no blue link).
    @ViewBuilder private var checkPasswordRow: some View {
        if store.state.canViewPassword, !store.state.password.isEmpty {
            AsyncButton {
                await store.perform(.checkPasswordPressed)
            } label: {
                // ui-r7: an HStack (not a `Label`) so the text wraps onto as many lines as it needs at large
                // text sizes instead of being clipped.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .accessibilityHidden(true)
                    Text(Localizations.checkPasswordForDataBreaches)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .accessibilityLabel(Localizations.checkPassword)
            .accessibilityIdentifier("CheckPasswordButton")
        }
    }

    /// Row signifying that Premium subscription is required for TOTP.
    ///
    @ViewBuilder private var premiumSubscriptionRequired: some View {
        BitwardenField {
            HStack(spacing: 8) {
                Text(Localizations.authenticatorKey)
                    .styleGuide(
                        .body,
                        weight: .regular,
                        includeLinePadding: false,
                        includeLineSpacing: false,
                    )
                    .foregroundColor(SharedAsset.Colors.textSecondary.swiftUIColor)
                    .accessibilityIdentifier("ItemName")

                Button {
                    openURL(ExternalLinksConstants.authenticatorHelp)
                } label: {
                    SharedAsset.Icons.questionCircle16.swiftUIImage
                        .scaledFrame(width: 16, height: 16)
                        .accessibilityLabel(Localizations.learnMore)
                }
                .buttonStyle(.fieldLabelIcon)
                .accessibilityIdentifier("AuthenticatorHelpButton")
            }
        } footer: {
            Button(Localizations.premiumSubscriptionRequired) {
                store.send(.premiumSubscriptionRequiredTapped)
            }
            .buttonStyle(.bitwardenBorderless)
            .padding(.vertical, 14)
            .accessibilityIdentifier("PremiumSubscriptionRequiredButton")
        }
        .accessibilityElement(children: .contain)
    }

    /// The username field.
    ///
    @ViewBuilder private var usernameRow: some View {
        let username = store.state.username
        BitwardenTextValueField(
            title: Localizations.username,
            value: username,
            valueAccessibilityIdentifier: "LoginUsernameEntry",
        )
        .accessibilityElement(children: .contain)
        .contentShape(Rectangle())
        .onTapGesture {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            store.send(.copyPressed(value: username, field: .username))
        }
        .contextMenu {
            Button {
                store.send(.copyPressed(value: username, field: .username))
            } label: {
                Label(Localizations.copy, systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: Methods

    /// The passkey row.
    ///
    private func passkeyRow(_ fido2Credential: Fido2CredentialView) -> some View {
        BitwardenTextValueField(
            title: Localizations.passkey,
            value: Localizations.createdX(fido2Credential.creationDate.dateTimeDisplay),
        )
        .accessibilityIdentifier("LoginPasskeyEntry")
        .accessibilityElement(children: .contain)
    }

    /// The TOTP row.
    ///
    /// - Parameter model: The TOTP code model.
    /// - Returns: The TOTP code row.
    ///
    private func totpRow(_ model: TOTPCodeModel) -> some View {
        BitwardenField(
            title: Localizations.authenticatorKey,
            titleAccessibilityIdentifier: "ItemName",
            content: {
                Text(model.displayCode)
                    .styleGuide(.bodyMonospaced)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(SharedAsset.Colors.textPrimary.swiftUIColor)
                    .accessibilityIdentifier("LoginTotpEntry")
            },
            accessoryContent: {
                TOTPCountdownTimerView(
                    timeProvider: timeProvider,
                    totpCode: model,
                    onExpiration: {
                        Task {
                            await store.perform(.totpCodeExpired)
                        }
                    },
                )
            },
        )
        .accessibilityElement(children: .contain)
        .contentShape(Rectangle())
        .onTapGesture {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            store.send(.copyPressed(value: model.code, field: .totp))
        }
        .contextMenu {
            Button {
                store.send(.copyPressed(value: model.code, field: .totp))
            } label: {
                Label(Localizations.copy, systemImage: "doc.on.doc")
            }
        }
    }
}
