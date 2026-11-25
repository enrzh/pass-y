import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - MasterPasswordGeneratorView

/// A view that allows the user to generate a master password.
///
struct MasterPasswordGeneratorView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<
        MasterPasswordGeneratorState,
        MasterPasswordGeneratorAction,
        MasterPasswordGeneratorEffect,
    >

    // MARK: View

    var body: some View {
        Form {
            Section {
                passwordText
                Button {
                    Task { await store.perform(.generate) }
                } label: {
                    Label(Localizations.generate, systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("GenerateButton")
            } footer: {
                PassYFooterText(
                    Localizations.writeThisPasswordDownAndKeepItSomewhereSafe,
                    link: Localizations.learnAboutOtherWaysToPreventAccountLockout,
                ) {
                    store.send(.preventAccountLock)
                }
            }
        }
        .navigationBar(
            title: Localizations.generateMasterPassword,
            titleDisplayMode: .inline,
        )
        .toolbar {
            saveToolbarItem {
                await store.perform(.save)
            }
        }
        .task {
            await store.perform(.loadData)
        }
    }

    // MARK: Private views

    /// The generated password (monospaced, coloured digits and symbols), selectable.
    private var passwordText: some View {
        PasswordText(
            password: store.state.generatedPassword,
            isPasswordVisible: true,
        )
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .padding(.vertical, PassYDesign.Spacing.xSmall)
        .textSelection(.enabled)
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    MasterPasswordGeneratorView(
        store: Store(
            processor: StateProcessor(
                state: MasterPasswordGeneratorState(generatedPassword: "Imma-Little-Teapot2"),
            ),
        ),
    )
}
#endif
