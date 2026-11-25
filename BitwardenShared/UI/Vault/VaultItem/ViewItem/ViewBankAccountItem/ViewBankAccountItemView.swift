import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ViewBankAccountItemView

/// The account details of a bank account item: tap-to-copy rows; account number, PIN and IBAN masked with eye
/// buttons; numbers are read character by character by VoiceOver. No section title.
struct ViewBankAccountItemView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<BankAccountItemState, ViewItemAction, Void>

    var body: some View {
        if !store.state.isBankAccountDetailsSectionEmpty {
            Section {
                textField(
                    title: Localizations.bankName,
                    value: store.state.bankName,
                    valueAccessibilityIdentifier: "BankAccountBankNameEntry",
                )

                copyableTextField(
                    title: Localizations.nameOnAccount,
                    value: store.state.nameOnAccount,
                    valueAccessibilityIdentifier: "BankAccountNameOnAccountEntry",
                    copyField: .nameOnAccount,
                )

                accountTypeItem

                secretField(
                    title: Localizations.accountNumber,
                    value: store.state.accountNumber,
                    isVisible: store.state.isAccountNumberVisible,
                    valueAccessibilityIdentifier: "BankAccountNumberEntry",
                    revealIdentifier: "ShowBankAccountNumberButton",
                    copyField: .accountNumber,
                ) { .toggleAccountNumberVisibilityChanged($0) }

                copyableTextField(
                    title: Localizations.routingNumber,
                    value: store.state.routingNumber,
                    valueAccessibilityIdentifier: "BankAccountRoutingNumberEntry",
                    copyField: .routingNumber,
                    spellOutAccessibilityValue: true,
                )

                copyableTextField(
                    title: Localizations.branchNumber,
                    value: store.state.branchNumber,
                    valueAccessibilityIdentifier: "BankAccountBranchNumberEntry",
                    copyField: .branchNumber,
                    spellOutAccessibilityValue: true,
                )

                secretField(
                    title: Localizations.pin,
                    value: store.state.pin,
                    isVisible: store.state.isPinVisible,
                    valueAccessibilityIdentifier: "BankAccountPinEntry",
                    revealIdentifier: "ShowBankAccountPinButton",
                    copyField: .pin,
                ) { .togglePinVisibilityChanged($0) }

                copyableTextField(
                    title: Localizations.swiftCode,
                    value: store.state.swiftCode,
                    valueAccessibilityIdentifier: "BankAccountSwiftCodeEntry",
                    copyField: .swiftCode,
                    spellOutAccessibilityValue: true,
                )

                secretField(
                    title: Localizations.iban,
                    value: store.state.iban,
                    isVisible: store.state.isIbanVisible,
                    valueAccessibilityIdentifier: "BankAccountIbanEntry",
                    revealIdentifier: "ShowBankAccountIbanButton",
                    copyField: .iban,
                ) { .toggleIbanVisibilityChanged($0) }

                copyableTextField(
                    title: Localizations.bankContactPhone,
                    value: store.state.bankContactPhone,
                    valueAccessibilityIdentifier: "BankAccountContactPhoneEntry",
                    copyField: .bankContactPhone,
                )
            }
        }
    }

    // MARK: Private Views

    /// The account type, hidden when no type is selected.
    @ViewBuilder private var accountTypeItem: some View {
        if let type = store.state.accountType.customValue {
            PassYCopyRow(
                Localizations.accountType,
                value: type.localizedName,
                identifier: "BankAccountTypeEntry",
                copy: nil,
            )
        }
    }

    /// A masked value with an eye button (spoken with its field name) that copies on tap, hidden when empty.
    @ViewBuilder
    private func secretField(
        title: String,
        value: String,
        isVisible: Bool,
        valueAccessibilityIdentifier: String,
        revealIdentifier: String,
        copyField: CopyableField,
        toggle: @escaping (Bool) -> ViewBankAccountItemAction,
    ) -> some View {
        if !value.isEmpty {
            PassYCopyRow(
                title,
                value: value,
                secret: .init(
                    isRevealed: isVisible,
                    revealIdentifier: revealIdentifier,
                    tintsCharacters: false,
                    spokenName: title,
                ) {
                    store.send(.bankAccountItemAction(toggle(!isVisible)))
                },
                identifier: valueAccessibilityIdentifier,
                spellsOut: true,
            ) {
                store.send(.copyPressed(value: value, field: copyField))
            }
        }
    }

    /// A value that copies on tap, hidden when empty.
    @ViewBuilder
    private func copyableTextField(
        title: String,
        value: String,
        valueAccessibilityIdentifier: String,
        copyField: CopyableField,
        spellOutAccessibilityValue: Bool = false,
    ) -> some View {
        if !value.isEmpty {
            PassYCopyRow(
                title,
                value: value,
                identifier: valueAccessibilityIdentifier,
                spellsOut: spellOutAccessibilityValue,
            ) {
                store.send(.copyPressed(value: value, field: copyField))
            }
        }
    }

    /// A read-only value, hidden when empty.
    @ViewBuilder
    private func textField(title: String, value: String, valueAccessibilityIdentifier: String) -> some View {
        if !value.isEmpty {
            PassYCopyRow(title, value: value, identifier: valueAccessibilityIdentifier, copy: nil)
        }
    }
}

#if DEBUG
#Preview("Empty View State") {
    NavigationView {
        Form {
            Group {
                ViewBankAccountItemView(
                    store: Store(
                        processor: StateProcessor(state: BankAccountItemState()),
                    ),
                )
            }
        }
    }
}

#Preview("Populated View State") {
    NavigationView {
        Form {
            Group {
                ViewBankAccountItemView(
                    store: Store(
                        processor: StateProcessor(
                            state: {
                                var state = BankAccountItemState()
                                state.bankName = "Bank of America"
                                state.nameOnAccount = "Personal Checking"
                                state.accountType = .custom(.checking)
                                state.accountNumber = "1234567890123456"
                                state.routingNumber = "1234567890"
                                state.branchNumber = "100"
                                state.pin = "1234"
                                state.swiftCode = "BOFAUS3N"
                                state.iban = "GB33BUKB20201555555555"
                                state.bankContactPhone = "123-456-7890"
                                return state
                            }(),
                        ),
                    ),
                )
            }
        }
    }
}
#endif
