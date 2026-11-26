import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ExportVaultView

/// A view that allows users to export their vault to a file.
///
struct ExportVaultView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ExportVaultState, ExportVaultAction, ExportVaultEffect>

    // MARK: View

    var body: some View {
        Form {
            disabledExportInfo

            Section {
                Picker(selection: store.binding(
                    get: \.fileFormat,
                    send: ExportVaultAction.fileFormatTypeChanged,
                )) {
                    ForEach(ExportFormatType.allCases, id: \.self) { format in
                        Text(format.localizedName).tag(format)
                    }
                } label: {
                    PassYSettingsRowLabel(title: Localizations.fileFormat, systemImage: "doc.fill", tint: .blue)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("FileFormatPicker")
            }

            filePasswordFields

            masterPasswordSection
        }
        .passYGroupedBackground()
        .animation(.default, value: store.state.filePasswordStrengthScore)
        .disabled(store.state.disableIndividualVaultExport)
        .navigationBar(title: Localizations.exportVault, titleDisplayMode: .inline)
        .task {
            await store.perform(.loadData)
        }
        .toast(store.binding(
            get: \.toast,
            send: ExportVaultAction.toastShown,
        ))
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }

            ToolbarItem(placement: .topBarTrailing) {
                primaryActionToolbarButton(Localizations.export) {
                    Task { await store.perform(.exportVaultTapped) }
                }
                .accessibilityIdentifier("ExportVaultButton")
                .disabled(store.state.disableIndividualVaultExport)
            }
        }
    }

    // MARK: Private Views

    /// A notice displayed if individual export is disabled.
    @ViewBuilder private var disabledExportInfo: some View {
        if store.state.disableIndividualVaultExport {
            Section {
                Label(Localizations.disablePersonalVaultExportPolicyInEffect, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("DisablePrivateVaultPolicyLabel")
            }
        }
    }

    /// A password row with a reveal button (`PassYPasswordField`).
    private func secureRow(
        title: String,
        text: Binding<String>,
        visible: Binding<Bool>,
        fieldId: String,
        toggleId: String,
    ) -> some View {
        PassYPasswordField(
            title,
            text: text,
            isRevealed: visible.wrappedValue,
            contentType: nil,
            fieldIdentifier: fieldId,
            toggleIdentifier: toggleId,
        ) { visible.wrappedValue = $0 }
    }

    /// The file password fields for a JSON encrypted export.
    @ViewBuilder private var filePasswordFields: some View {
        if store.state.fileFormat == .jsonEncrypted {
            Section {
                secureRow(
                    title: Localizations.filePassword,
                    text: store.binding(
                        get: \.filePasswordText,
                        send: ExportVaultAction.filePasswordTextChanged,
                    ),
                    visible: store.binding(
                        get: \.isFilePasswordVisible,
                        send: ExportVaultAction.toggleFilePasswordVisibility,
                    ),
                    fieldId: "FilePasswordEntry",
                    toggleId: "FilePasswordVisibilityToggle",
                )

                secureRow(
                    title: Localizations.confirmFilePassword,
                    text: store.binding(
                        get: \.filePasswordConfirmationText,
                        send: ExportVaultAction.filePasswordConfirmationTextChanged,
                    ),
                    visible: store.binding(
                        get: \.isFilePasswordVisible,
                        send: ExportVaultAction.toggleFilePasswordVisibility,
                    ),
                    fieldId: "FilePasswordEntry",
                    toggleId: "FilePasswordVisibilityToggle",
                )

                PasswordStrengthIndicator(
                    passwordStrengthScore: store.state.filePasswordStrengthScore,
                )
            } footer: {
                Text(Localizations.filePasswordDescription)
            }
        }
    }

    /// The master password / OTP section.
    private var masterPasswordSection: some View {
        Section {
            secureRow(
                title: store.state.masterPasswordOrOtpTitle,
                text: store.binding(
                    get: \.masterPasswordOrOtpText,
                    send: ExportVaultAction.masterPasswordOrOtpTextChanged,
                ),
                visible: store.binding(
                    get: \.isMasterPasswordOrOtpVisible,
                    send: ExportVaultAction.toggleMasterPasswordOrOtpVisibility,
                ),
                fieldId: "MasterPasswordEntry",
                toggleId: "PasswordVisibilityToggle",
            )

            if !store.state.hasMasterPassword {
                Button {
                    Task { await store.perform(.sendCodeTapped) }
                } label: {
                    Label(Localizations.sendCode, systemImage: "envelope")
                }
                .accessibilityIdentifier("SendTOTPCodeButton")
                .disabled(store.state.isSendCodeButtonDisabled)
            }
        } header: {
            if !store.state.hasMasterPassword {
                Text(Localizations.sendVerificationCodeToEmail)
            }
        } footer: {
            Text(store.state.masterPasswordOrOtpFooter)
        }
    }
}

// MARK: - Previews

#Preview("Export Vault") {
    NavigationView {
        ExportVaultView(store: Store(processor: StateProcessor(state: ExportVaultState())))
    }
}

#Preview("Export Vault without Master Password") {
    ExportVaultView(store: Store(processor: StateProcessor(state: ExportVaultState(hasMasterPassword: false))))
}

#Preview("Disabled Export") {
    NavigationView {
        ExportVaultView(
            store: Store(
                processor: StateProcessor(
                    state: ExportVaultState(disableIndividualVaultExport: true),
                ),
            ),
        )
    }
}
