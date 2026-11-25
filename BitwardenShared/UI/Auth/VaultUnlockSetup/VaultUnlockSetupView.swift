import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - VaultUnlockSetupView

/// A view that allows the user to enable vault unlock methods when setting up their account.
///
struct VaultUnlockSetupView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultUnlockSetupState, VaultUnlockSetupAction, VaultUnlockSetupEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("faceid", .accentColor),
                    title: Localizations.setUpUnlock,
                    message: Localizations.setUpBiometricsOrChooseAPinCodeToQuicklyAccessYourVaultAndAutofillYourLogins,
                )
            }
            .passYPlainListRow()

            Section {
                ForEach(store.state.unlockMethods) { unlockMethod in
                    PassYToggleRow(
                        unlockMethod.title,
                        isOn: store.bindingAsync(
                            get: { $0[keyPath: unlockMethod.keyPath] },
                            perform: { VaultUnlockSetupEffect.toggleUnlockMethod(unlockMethod, newValue: $0) },
                        ),
                        identifier: unlockMethod.accessibilityIdentifier,
                    )
                }
            }

            PassYActionStack {
                Button {
                    Task { await store.perform(.continueFlow) }
                } label: {
                    Text(Localizations.continue).frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)
                .disabled(!store.state.isContinueButtonEnabled)

                if store.state.shouldDisplaySetUpLaterButton {
                    Button(Localizations.setUpLater) {
                        store.send(.setUpLater)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .navigationBar(title: store.state.navigationBarTitle, titleDisplayMode: .inline)
        .task {
            await store.perform(.loadData)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Create Account Flow") {
    VaultUnlockSetupView(store: Store(processor: StateProcessor(state: VaultUnlockSetupState(
        accountSetupFlow: .createAccount,
    ))))
    .navStackWrapped
}

#Preview("Settings Flow") {
    VaultUnlockSetupView(store: Store(processor: StateProcessor(state: VaultUnlockSetupState(
        accountSetupFlow: .settings,
    ))))
    .navStackWrapped
}
#endif
