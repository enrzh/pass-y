import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AddEditBankAccountItemView

/// A view that allows the user to add or edit a bank account item for a vault.
///
struct AddEditBankAccountItemView: View {
    // MARK: Type

    /// The focusable fields in the bank account view.
    enum FocusedField: Int, Hashable {
        case bankName
        case nameOnAccount
        case accountNumber
        case routingNumber
        case branchNumber
        case pin
        case swiftCode
        case iban
        case bankContactPhone
    }

    // MARK: Properties

    /// The currently focused field.
    @FocusState private var focusedField: FocusedField?

    /// The `Store` for this view.
    @ObservedObject var store: Store<
        any AddEditBankAccountItemState,
        AddEditBankAccountItemAction,
        AddEditItemEffect,
    >

    var body: some View {
        Section {
            PassYFormField(
                Localizations.bankName,
                text: store.binding(
                    get: \.bankName,
                    send: AddEditBankAccountItemAction.bankNameChanged,
                ),
                identifier: "BankNameEntry",
                focus: .field($focusedField, equals: .bankName),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.nameOnAccount,
                text: store.binding(
                    get: \.nameOnAccount,
                    send: AddEditBankAccountItemAction.nameOnAccountChanged,
                ),
                identifier: "NameOnAccountEntry",
                focus: .field($focusedField, equals: .nameOnAccount),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYPickerRow(
                Localizations.accountType,
                options: BankAccountType.displayOrder.map(DefaultableType.custom),
                selection: store.binding(
                    get: \.accountType,
                    send: AddEditBankAccountItemAction.accountTypeChanged,
                ),
                identifier: "AccountTypePicker",
            )

            PassYSecureField(
                Localizations.accountNumber,
                text: store.binding(
                    get: \.accountNumber,
                    send: AddEditBankAccountItemAction.accountNumberChanged,
                ),
                isRevealed: store.binding(
                    get: \.isAccountNumberVisible,
                    send: AddEditBankAccountItemAction.toggleAccountNumberVisibilityChanged,
                ),
                identifier: "AccountNumberEntry",
                revealIdentifier: "ShowAccountNumberButton",
                revealSpokenName: Localizations.accountNumber,
                focus: .field($focusedField, equals: .accountNumber),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.routingNumber,
                text: store.binding(
                    get: \.routingNumber,
                    send: AddEditBankAccountItemAction.routingNumberChanged,
                ),
                identifier: "RoutingNumberEntry",
                focus: .field($focusedField, equals: .routingNumber),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.branchNumber,
                text: store.binding(
                    get: \.branchNumber,
                    send: AddEditBankAccountItemAction.branchNumberChanged,
                ),
                identifier: "BranchNumberEntry",
                focus: .field($focusedField, equals: .branchNumber),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYSecureField(
                Localizations.pin,
                text: store.binding(
                    get: \.pin,
                    send: AddEditBankAccountItemAction.pinChanged,
                ),
                isRevealed: store.binding(
                    get: \.isPinVisible,
                    send: AddEditBankAccountItemAction.togglePinVisibilityChanged,
                ),
                identifier: "PinEntry",
                revealIdentifier: "ShowPinButton",
                revealSpokenName: Localizations.pin,
                focus: .field($focusedField, equals: .pin),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.swiftCode,
                text: store.binding(
                    get: \.swiftCode,
                    send: AddEditBankAccountItemAction.swiftCodeChanged,
                ),
                identifier: "SwiftCodeEntry",
                focus: .field($focusedField, equals: .swiftCode),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYSecureField(
                Localizations.iban,
                text: store.binding(
                    get: \.iban,
                    send: AddEditBankAccountItemAction.ibanChanged,
                ),
                isRevealed: store.binding(
                    get: \.isIbanVisible,
                    send: AddEditBankAccountItemAction.toggleIbanVisibilityChanged,
                ),
                identifier: "IbanEntry",
                revealIdentifier: "ShowIbanButton",
                revealSpokenName: Localizations.iban,
                focus: .field($focusedField, equals: .iban),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.bankContactPhone,
                text: store.binding(
                    get: \.bankContactPhone,
                    send: AddEditBankAccountItemAction.bankContactPhoneChanged,
                ),
                identifier: "BankContactPhoneEntry",
                focus: .field($focusedField, equals: .bankContactPhone),
            )
            .textFieldConfiguration(.numeric(.telephoneNumber))
        }
    }
}

#if DEBUG
#Preview("Empty") {
    NavigationView {
        Form {
            AddEditBankAccountItemView(
                store: Store(
                    processor: StateProcessor(
                        state: BankAccountItemState() as (any AddEditBankAccountItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Empty Add Edit State")
    }
}

#Preview("Populated") {
    NavigationView {
        Form {
            AddEditBankAccountItemView(
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
                            state.swiftCode = "123234"
                            state.iban = "23423434543"
                            state.bankContactPhone = "123-456-7890"
                            return state
                        }() as (any AddEditBankAccountItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Populated Add Edit State")
    }
}
#endif
