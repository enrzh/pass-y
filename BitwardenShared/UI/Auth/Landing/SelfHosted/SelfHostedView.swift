import BitwardenKit
import BitwardenResources
import SwiftUI
import UniformTypeIdentifiers

// MARK: - SelfHostedView

/// A view for configuring a self-hosted environment.
///
struct SelfHostedView: View {
    // MARK: Properties

    /// The store used to render the view.
    @ObservedObject var store: Store<SelfHostedState, SelfHostedAction, SelfHostedEffect>

    /// Local state for the certificate alias text field in the dialog.
    @SwiftUI.State private var dialogAlias: String = ""

    /// Local state for the certificate password text field in the dialog.
    @SwiftUI.State private var dialogPassword: String = ""

    // MARK: View

    var body: some View {
        Form {
            selfHostedEnvironment
            customEnvironment
            clientCertificateSection
        }
        .navigationBar(title: Localizations.settings, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }

            saveToolbarItem {
                await store.perform(.saveEnvironment)
            }
        }
        .fileImporter(
            isPresented: store.binding(
                get: \.showingCertificateImporter,
                send: { _ in SelfHostedAction.dismissCertificateImporter },
            ),
            allowedContentTypes: [UTType(filenameExtension: "p12")!, UTType(filenameExtension: "pfx")!],
            onCompletion: { result in
                store.send(.certificateFileSelected(result))
            },
        )
        .alert(
            Localizations.importClientCertificate,
            isPresented: Binding(
                get: {
                    if case .setCertificateData = store.state.dialog { return true }
                    return false
                },
                set: { newValue in
                    if !newValue { store.send(.dialogDismiss) }
                },
            ),
        ) {
            TextField(Localizations.alias, text: $dialogAlias)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField(Localizations.password, text: $dialogPassword)
            Button(Localizations.cancel, role: .cancel) {
                dialogAlias = ""
                dialogPassword = ""
                store.send(.dialogDismiss)
            }
            Button(Localizations.submit) {
                let alias = dialogAlias
                let password = dialogPassword
                dialogAlias = ""
                dialogPassword = ""
                store.send(.certificateInfoSubmitted(alias: alias, password: password))
            }
            .disabled(dialogPassword.isEmpty)
        } message: {
            Text(Localizations.enterTheCertificatePasswordAndAlias)
        }
        .alert(
            Localizations.anErrorHasOccurred,
            isPresented: Binding(
                get: {
                    if case .error = store.state.dialog { return true }
                    return false
                },
                set: { newValue in
                    if !newValue { store.send(.dialogDismiss) }
                },
            ),
        ) {
            Button(Localizations.ok) {
                store.send(.dialogDismiss)
            }
        } message: {
            if case let .error(message) = store.state.dialog {
                Text(message)
            }
        }
        .alert(
            Localizations.replaceExistingCertificate,
            isPresented: Binding(
                get: {
                    if case .confirmOverwriteAlias = store.state.dialog { return true }
                    return false
                },
                set: { newValue in
                    if !newValue { store.send(.dialogDismiss) }
                },
            ),
        ) {
            Button(Localizations.cancel, role: .cancel) {
                store.send(.dialogDismiss)
            }
            Button(Localizations.replaceCertificate, role: .destructive) {
                store.send(.confirmOverwriteCertificate)
            }
        } message: {
            if case let .confirmOverwriteAlias(alias, _, _) = store.state.dialog {
                Text(Localizations.aCertificateWithTheAliasAlreadyExistsDescriptionLong(alias))
            }
        }
    }

    // MARK: Private views

    /// A native text field row bound to a store value.
    private func urlField(
        _ title: String,
        id: String,
        get: @escaping (SelfHostedState) -> String,
        send: @escaping (String) -> SelfHostedAction,
    ) -> some View {
        TextField(title, text: store.binding(get: get, send: send))
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier(id)
    }

    /// The custom environment section.
    private var customEnvironment: some View {
        Section {
            urlField(Localizations.webVaultUrl, id: "WebVaultUrlEntry", get: \.webVaultServerUrl, send: SelfHostedAction.webVaultUrlChanged)
            urlField(Localizations.apiUrl, id: "ApiUrlEntry", get: \.apiServerUrl, send: SelfHostedAction.apiUrlChanged)
            urlField(Localizations.identityUrl, id: "IdentityUrlEntry", get: \.identityServerUrl, send: SelfHostedAction.identityUrlChanged)
            urlField(Localizations.iconsUrl, id: "IconsUrlEntry", get: \.iconsServerUrl, send: SelfHostedAction.iconsUrlChanged)
        } header: {
            Text(Localizations.customEnvironment)
        } footer: {
            Text(Localizations.customEnvironmentFooter)
        }
    }

    /// The self-hosted environment section.
    private var selfHostedEnvironment: some View {
        Section {
            urlField(Localizations.serverUrl, id: "ServerUrlEntry", get: \.serverUrl, send: SelfHostedAction.serverUrlChanged)
        } header: {
            Text(Localizations.selfHostedEnvironment)
        } footer: {
            Text(Localizations.selfHostedEnvironmentFooter)
        }
    }

    /// The client certificate (mTLS) section.
    private var clientCertificateSection: some View {
        Section {
            HStack {
                Text(Localizations.certificateAlias)
                Spacer()
                Text(store.state.keyAlias)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("KeyAliasEntry")

            Button(Localizations.importCertificate) {
                store.send(.importCertificateTapped)
            }
            .accessibilityIdentifier("ImportCertificateButton")

            if !store.state.keyAlias.isEmpty {
                Button(Localizations.removeCertificate, role: .destructive) {
                    store.send(.removeCertificateTapped)
                }
                .accessibilityIdentifier("RemoveCertificateButton")
            }
        } header: {
            Text(Localizations.clientCertificateMtls)
        } footer: {
            Text(Localizations.certificateUsedForClientAuthentication)
        }
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    SelfHostedView(store: Store(processor: StateProcessor(state: SelfHostedState())))
}
#endif
