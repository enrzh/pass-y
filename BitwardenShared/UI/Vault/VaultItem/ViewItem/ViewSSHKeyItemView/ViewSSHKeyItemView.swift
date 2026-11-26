import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ViewSSHKeyItemView

/// The keys of an SSH key item: the private key masked (eye button), public key and fingerprint stacked and
/// monospaced. In the item view every row copies on tap; in the edit form (`showCopyButtons: false`) they are read-only.
struct ViewSSHKeyItemView: View {
    // MARK: Properties

    /// Whether the rows copy their value (item view).
    var showCopyButtons: Bool

    /// The `Store` for this view.
    @ObservedObject var store: Store<SSHKeyItemState, ViewSSHKeyItemAction, Void>

    var body: some View {
        Section {
            privateKeyField

            publicKeyField

            fingerprintField
        }
    }

    /// The private key.
    @ViewBuilder private var privateKeyField: some View {
        let privateKey = store.state.privateKey
        PassYCopyRow(
            Localizations.privateKey,
            value: privateKey,
            secret: store.state.canViewPrivateKey
                ? .init(
                    isRevealed: store.state.isPrivateKeyVisible,
                    revealIdentifier: "PrivateKeyVisibilityToggle",
                    tintsCharacters: false,
                ) {
                    store.send(.privateKeyVisibilityPressed)
                }
                : .init(isRevealed: false, tintsCharacters: false, canReveal: false) {},
            identifier: "PrivateKeyEntry",
            layout: .stacked,
            copy: showCopyButtons && store.state.canViewPrivateKey
                ? { store.send(.copyPressed(value: privateKey, field: .sshPrivateKey)) }
                : nil,
        )
    }

    /// The public key.
    @ViewBuilder private var publicKeyField: some View {
        let publicKey = store.state.publicKey
        PassYCopyRow(
            Localizations.publicKey,
            value: publicKey,
            identifier: "SSHKeyPublicKeyEntry",
            layout: .stacked,
            isMonospaced: true,
            copy: showCopyButtons ? { store.send(.copyPressed(value: publicKey, field: .sshPublicKey)) } : nil,
        )
    }

    /// The fingerprint.
    @ViewBuilder private var fingerprintField: some View {
        let keyFingerprint = store.state.keyFingerprint
        PassYCopyRow(
            Localizations.fingerprint,
            value: keyFingerprint,
            identifier: "FingerprintEntry",
            layout: .stacked,
            isMonospaced: true,
            copy: showCopyButtons
                ? { store.send(.copyPressed(value: keyFingerprint, field: .sshKeyFingerprint)) }
                : nil,
        )
    }
}

#Preview("SSH Key item view") {
    Form {
        ViewSSHKeyItemView(
            showCopyButtons: true,
            store: Store(
                processor: StateProcessor(
                    state: SSHKeyItemState(
                        isPrivateKeyVisible: false,
                        privateKey: "ajsdfopij1ZXCVZXC12312QW",
                        publicKey: "ssh-ed25519 AAAAA/asdjfoiwejrpo23323j23ASdfas",
                        keyFingerprint: "SHA-256:2qwer233ADJOIq1adfweqe21321qw",
                    ),
                ),
            ),
        )
    }
}
