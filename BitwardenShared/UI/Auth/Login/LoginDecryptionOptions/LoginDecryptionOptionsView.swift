import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - LoginDecryptionOptionsView

/// A view that allows users to trust their device and decrypt their vault
/// with master password, another device or through admin approval
///
struct LoginDecryptionOptionsView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<
        LoginDecryptionOptionsState,
        LoginDecryptionOptionsAction,
        LoginDecryptionOptionsEffect,
    >
    var body: some View {
        Form {
            Section {
                PassYHeroHeader(title: Localizations.loggingIn)
            }
            .passYPlainListRow()

            Section {
                PassYToggleRow(
                    Localizations.rememberThisDevice,
                    subtitle: Localizations.turnOffUsingPublicDevice,
                    isOn: store.binding(
                        get: \.isRememberDeviceToggleOn,
                        send: LoginDecryptionOptionsAction.toggleRememberDevice,
                    ),
                    identifier: "RememberThisDeviceToggle",
                )
            }

            Section {
                VStack(spacing: PassYDesign.Spacing.medium) {
                    decryptMethodButtons
                }
                .padding(.horizontal, PassYDesign.Spacing.large)
            }
            .passYPlainListRow()

            Section {
                loggedInAs
            }
            .passYPlainListRow()
        }
        .navigationBar(title: Localizations.loggingIn, titleDisplayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .task {
            await store.perform(.loadLoginDecryptionOptions)
        }
    }

    // MARK: Private Views

    /// A full-width action button that performs an effect.
    private func actionButton(
        _ title: String,
        kind: PassYButtonKind,
        identifier: String,
        effect: LoginDecryptionOptionsEffect,
    ) -> some View {
        Button {
            Task { await store.perform(effect) }
        } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .passYButtonStyle(kind, fillsWidth: true)
        .accessibilityIdentifier(identifier)
    }

    /// The decrypt method buttons: the first available one is the primary action.
    @ViewBuilder var decryptMethodButtons: some View {
        if store.state.shouldShowContinueButton {
            actionButton(Localizations.continue, kind: .primary, identifier: "ContinueButton", effect: .continuePressed)
        }

        if store.state.shouldShowApproveWithOtherDeviceButton {
            actionButton(
                Localizations.approveWithMyOtherDevice,
                kind: store.state.shouldShowContinueButton ? .secondary : .primary,
                identifier: "ApproveWithOtherDeviceButton",
                effect: .approveWithOtherDevicePressed,
            )
        }

        if store.state.shouldShowAdminApprovalButton {
            actionButton(
                Localizations.requestAdminApproval,
                kind: .secondary,
                identifier: "RequestAdminApprovalButton",
                effect: .requestAdminApprovalPressed,
            )
        }

        if store.state.shouldShowApproveMasterPasswordButton {
            actionButton(
                Localizations.approveWithMasterPassword,
                kind: .secondary,
                identifier: "ApproveWithMasterPasswordButton",
                effect: .approveWithMasterPasswordPressed,
            )
        }
    }

    /// The account being logged in, with a "Not you?" button.
    @ViewBuilder var loggedInAs: some View {
        VStack(alignment: .center, spacing: PassYDesign.Spacing.xSmall) {
            Text(Localizations.loggingInAsX(store.state.email))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("LoggingInAsLabel")

            Button(Localizations.notYou) {
                Task { await store.perform(.notYouPressed) }
            }
            .fontWeight(.semibold)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("NotYouButton")
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .padding(.vertical, PassYDesign.Spacing.small)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    NavigationView {
        LoginDecryptionOptionsView(store: Store(processor: StateProcessor(
            state: LoginDecryptionOptionsState(
                shouldShowContinueButton: true,
                email: "user@example.com",
                shouldShowAdminApprovalButton: true,
            ),
        )))
    }
}
#endif
