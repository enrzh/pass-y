import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ManualEntryView

/// A view for the user to manually enter an authenticator key.
///
struct ManualEntryView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ManualEntryState, ManualEntryAction, ManualEntryEffect>

    var body: some View {
        content
            .navigationTitle(Localizations.authenticatorKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismissPressed)
                }

                saveToolbarItem {
                    store.send(
                        ManualEntryAction.addPressed(code: store.state.authenticatorKey),
                    )
                }
            }
    }

    /// The key field with its explanation and, on devices with a camera, "Scan QR code".
    private var content: some View {
        Form {
            Section {
                PassYFormField(
                    Localizations.authenticatorKey,
                    text: store.binding(
                        get: \.authenticatorKey,
                        send: ManualEntryAction.authenticatorKeyChanged,
                    ),
                    style: .free,
                    identifier: "AddTOTPManuallyField",
                    isMonospaced: true,
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            } header: {
                PassYSectionHeader(Localizations.enterKeyManually)
            } footer: {
                PassYSectionFooter(Localizations.onceTheKeyIsSuccessfullyEntered)
            }

            if store.state.deviceSupportsCamera {
                Section {
                    PassYInlineButtonRow(
                        Localizations.scanQRCode,
                        systemImage: "qrcode.viewfinder",
                        identifier: "ScanQRCodeButton",
                    ) {
                        await store.perform(.scanCodePressed)
                    }
                } footer: {
                    PassYSectionFooter(Localizations.cannotAddAuthenticatorKey)
                }
            }
        }
        .passYReadableWidth()
    }
}

#if DEBUG
private struct ManualEntryPreviewState: ManualEntryState {
    var authenticatorKey: String = ""

    var deviceSupportsCamera: Bool = true

    var manualEntryState: ManualEntryState {
        self
    }
}

#Preview("Empty") {
    NavigationView {
        ManualEntryView(
            store: Store(
                processor: StateProcessor(
                    state: ManualEntryPreviewState().manualEntryState,
                ),
            ),
        )
    }
}

#Preview("Text Added") {
    NavigationView {
        ManualEntryView(
            store: Store(
                processor: StateProcessor(
                    state: ManualEntryPreviewState(
                        authenticatorKey: "manualEntry",
                    ).manualEntryState,
                ),
            ),
        )
    }
}
#endif
