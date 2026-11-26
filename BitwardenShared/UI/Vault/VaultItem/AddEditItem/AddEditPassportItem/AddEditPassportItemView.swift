import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AddEditPassportItemView

/// A view that allows the user to add or edit a passport item for a vault.
///
struct AddEditPassportItemView: View {
    // MARK: Types

    /// The focusable fields in the passport view.
    enum FocusedField: Int, Hashable {
        case givenName
        case surname
        case sex
        case birthPlace
        case nationality
        case passportNumber
        case passportType
        case nationalIdentificationNumber
        case issuingCountry
        case issuingAuthority
    }

    // MARK: Properties

    /// The currently focused field.
    @FocusState private var focusedField: FocusedField?

    /// The `Store` for this view.
    @ObservedObject var store: Store<
        any AddEditPassportItemState,
        AddEditPassportItemAction,
        AddEditItemEffect,
    >

    var body: some View {
        Section {
            PassYFormField(
                Localizations.firstName,
                text: store.binding(
                    get: \.givenName,
                    send: AddEditPassportItemAction.givenNameChanged,
                ),
                identifier: "PassportFirstNameEntry",
                focus: .field($focusedField, equals: .givenName),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.lastName,
                text: store.binding(
                    get: \.surname,
                    send: AddEditPassportItemAction.surnameChanged,
                ),
                identifier: "PassportLastNameEntry",
                focus: .field($focusedField, equals: .surname),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYDateRow(
                Localizations.dateOfBirth,
                date: store.binding(
                    get: \.dateOfBirth,
                    send: AddEditPassportItemAction.dateOfBirthChanged,
                ),
                in: Date.distantPast ... Date().asUTCCalendarDay(),
                identifier: "PassportDateOfBirthEntry",
            )

            PassYFormField(
                Localizations.sex,
                text: store.binding(
                    get: \.sex,
                    send: AddEditPassportItemAction.sexChanged,
                ),
                identifier: "PassportSexEntry",
                focus: .field($focusedField, equals: .sex),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.birthPlace,
                text: store.binding(
                    get: \.birthPlace,
                    send: AddEditPassportItemAction.birthPlaceChanged,
                ),
                identifier: "PassportBirthPlaceEntry",
                focus: .field($focusedField, equals: .birthPlace),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.nationality,
                text: store.binding(
                    get: \.nationality,
                    send: AddEditPassportItemAction.nationalityChanged,
                ),
                identifier: "PassportNationalityEntry",
                focus: .field($focusedField, equals: .nationality),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYSecureField(
                Localizations.passportNumber,
                text: store.binding(
                    get: \.passportNumber,
                    send: AddEditPassportItemAction.passportNumberChanged,
                ),
                isRevealed: store.binding(
                    get: \.isPassportNumberVisible,
                    send: AddEditPassportItemAction.togglePassportNumberVisibilityChanged,
                ),
                identifier: "PassportNumberEntry",
                revealIdentifier: "ShowPassportNumberButton",
                focus: .field($focusedField, equals: .passportNumber),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.passportType,
                text: store.binding(
                    get: \.passportType,
                    send: AddEditPassportItemAction.passportTypeChanged,
                ),
                identifier: "PassportTypeEntry",
                focus: .field($focusedField, equals: .passportType),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYSecureField(
                Localizations.nationalIdentificationNumber,
                text: store.binding(
                    get: \.nationalIdentificationNumber,
                    send: AddEditPassportItemAction.nationalIdentificationNumberChanged,
                ),
                isRevealed: store.binding(
                    get: \.isNationalIdentificationNumberVisible,
                    send: AddEditPassportItemAction.toggleNationalIdentificationNumberVisibilityChanged,
                ),
                identifier: "PassportNationalIdentificationNumberEntry",
                revealIdentifier: "ShowPassportNationalIdentificationNumberButton",
                focus: .field($focusedField, equals: .nationalIdentificationNumber),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.issuingCountry,
                text: store.binding(
                    get: \.issuingCountry,
                    send: AddEditPassportItemAction.issuingCountryChanged,
                ),
                identifier: "PassportIssuingCountryEntry",
                focus: .field($focusedField, equals: .issuingCountry),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.issuingAuthorityOffice,
                text: store.binding(
                    get: \.issuingAuthority,
                    send: AddEditPassportItemAction.issuingAuthorityChanged,
                ),
                identifier: "PassportIssuingAuthorityEntry",
                focus: .field($focusedField, equals: .issuingAuthority),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYDateRow(
                Localizations.issueDate,
                date: store.binding(
                    get: \.issueDate,
                    send: AddEditPassportItemAction.issueDateChanged,
                ),
                in: Date.distantPast ... Date().asUTCCalendarDay(),
                identifier: "PassportIssueDateEntry",
            )

            PassYDateRow(
                Localizations.expirationDate,
                date: store.binding(
                    get: \.expirationDate,
                    send: AddEditPassportItemAction.expirationDateChanged,
                ),
                identifier: "PassportExpirationDateEntry",
            )
        }
    }
}

#if DEBUG
#Preview("Empty") {
    NavigationView {
        Form {
            AddEditPassportItemView(
                store: Store(
                    processor: StateProcessor(
                        state: PassportItemState() as (any AddEditPassportItemState),
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
            AddEditPassportItemView(
                store: Store(
                    processor: StateProcessor(
                        state: PassportItemState.previewPopulated as (any AddEditPassportItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Populated Add Edit State")
    }
}

#Preview("Hidden Fields Visible") {
    NavigationView {
        Form {
            AddEditPassportItemView(
                store: Store(
                    processor: StateProcessor(
                        state: {
                            var state = PassportItemState.previewPopulated
                            state.isPassportNumberVisible = true
                            state.isNationalIdentificationNumberVisible = true
                            return state
                        }() as (any AddEditPassportItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Visible Add Edit State")
    }
}

private extension PassportItemState {
    /// A fully populated state used by previews.
    static var previewPopulated: PassportItemState {
        PassportItemState(
            birthPlace: "USA",
            dateOfBirth: Date(year: 2025, month: 4, day: 20),
            expirationDate: Date(year: 2026, month: 8, day: 10),
            givenName: "Mitchell",
            issueDate: Date(year: 2021, month: 8, day: 10),
            issuingAuthority: "U.S. Department of State",
            issuingCountry: "United States",
            nationalIdentificationNumber: "123456789",
            nationality: "USA",
            passportNumber: "X12345678",
            passportType: "Regular/Tourist",
            sex: "Male",
            surname: "Johnson",
        )
    }
}
#endif
