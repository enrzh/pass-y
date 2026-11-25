import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AddEditDriversLicenseItemView

/// A view that allows the user to add or edit a driver's license item for a vault.
///
struct AddEditDriversLicenseItemView: View {
    // MARK: Types

    /// The focusable fields in the driver's license view.
    enum FocusedField: Int, Hashable {
        case firstName
        case middleName
        case lastName
        case licenseNumber
        case issuingCountry
        case issuingState
        case issuingAuthority
        case licenseClass
    }

    // MARK: Properties

    /// The currently focused field.
    @FocusState private var focusedField: FocusedField?

    /// The `Store` for this view.
    @ObservedObject var store: Store<
        any AddEditDriversLicenseItemState,
        AddEditDriversLicenseItemAction,
        AddEditItemEffect,
    >

    var body: some View {
        Section {
            PassYFormField(
                Localizations.firstName,
                text: store.binding(
                    get: \.firstName,
                    send: AddEditDriversLicenseItemAction.firstNameChanged,
                ),
                identifier: "DriversLicenseFirstNameEntry",
                focus: .field($focusedField, equals: .firstName),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.middleName,
                text: store.binding(
                    get: \.middleName,
                    send: AddEditDriversLicenseItemAction.middleNameChanged,
                ),
                identifier: "DriversLicenseMiddleNameEntry",
                focus: .field($focusedField, equals: .middleName),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.lastName,
                text: store.binding(
                    get: \.lastName,
                    send: AddEditDriversLicenseItemAction.lastNameChanged,
                ),
                identifier: "DriversLicenseLastNameEntry",
                focus: .field($focusedField, equals: .lastName),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYSecureField(
                Localizations.licenseNumber,
                text: store.binding(
                    get: \.licenseNumber,
                    send: AddEditDriversLicenseItemAction.licenseNumberChanged,
                ),
                isRevealed: store.binding(
                    get: \.isLicenseNumberVisible,
                    send: AddEditDriversLicenseItemAction.toggleLicenseNumberVisibilityChanged,
                ),
                identifier: "DriversLicenseNumberEntry",
                revealIdentifier: "ShowDriversLicenseNumberButton",
                revealSpokenName: Localizations.licenseNumber,
                focus: .field($focusedField, equals: .licenseNumber),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYDateRow(
                Localizations.dateOfBirth,
                date: store.binding(
                    get: \.dateOfBirth,
                    send: AddEditDriversLicenseItemAction.dateOfBirthChanged,
                ),
                in: Date.distantPast ... Date().asUTCCalendarDay(),
                identifier: "DriversLicenseDateOfBirthEntry",
            )

            PassYFormField(
                Localizations.issuingCountry,
                text: store.binding(
                    get: \.issuingCountry,
                    send: AddEditDriversLicenseItemAction.issuingCountryChanged,
                ),
                identifier: "DriversLicenseIssuingCountryEntry",
                focus: .field($focusedField, equals: .issuingCountry),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.issuingStateProvince,
                text: store.binding(
                    get: \.issuingState,
                    send: AddEditDriversLicenseItemAction.issuingStateChanged,
                ),
                identifier: "DriversLicenseIssuingStateEntry",
                focus: .field($focusedField, equals: .issuingState),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.issuingAuthority,
                text: store.binding(
                    get: \.issuingAuthority,
                    send: AddEditDriversLicenseItemAction.issuingAuthorityChanged,
                ),
                identifier: "DriversLicenseIssuingAuthorityEntry",
                focus: .field($focusedField, equals: .issuingAuthority),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYDateRow(
                Localizations.issueDate,
                date: store.binding(
                    get: \.issueDate,
                    send: AddEditDriversLicenseItemAction.issueDateChanged,
                ),
                in: Date.distantPast ... Date().asUTCCalendarDay(),
                identifier: "DriversLicenseIssueDateEntry",
            )

            PassYDateRow(
                Localizations.expirationDate,
                date: store.binding(
                    get: \.expirationDate,
                    send: AddEditDriversLicenseItemAction.expirationDateChanged,
                ),
                identifier: "DriversLicenseExpirationDateEntry",
            )

            PassYFormField(
                Localizations.licenseClass,
                text: store.binding(
                    get: \.licenseClass,
                    send: AddEditDriversLicenseItemAction.licenseClassChanged,
                ),
                identifier: "DriversLicenseClassEntry",
                focus: .field($focusedField, equals: .licenseClass),
            )
        }
    }
}

#if DEBUG
#Preview("Empty") {
    NavigationView {
        Form {
            AddEditDriversLicenseItemView(
                store: Store(
                    processor: StateProcessor(
                        state: DriversLicenseItemState() as (any AddEditDriversLicenseItemState),
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
            AddEditDriversLicenseItemView(
                store: Store(
                    processor: StateProcessor(
                        state: DriversLicenseItemState.previewPopulated as (any AddEditDriversLicenseItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Populated Add Edit State")
    }
}

#Preview("License Number Visible") {
    NavigationView {
        Form {
            AddEditDriversLicenseItemView(
                store: Store(
                    processor: StateProcessor(
                        state: {
                            var state = DriversLicenseItemState.previewPopulated
                            state.isLicenseNumberVisible = true
                            return state
                        }() as (any AddEditDriversLicenseItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Visible Add Edit State")
    }
}

private extension DriversLicenseItemState {
    /// A fully populated state used by previews.
    static var previewPopulated: DriversLicenseItemState {
        DriversLicenseItemState(
            dateOfBirth: Date(year: 1989, month: 8, day: 1),
            expirationDate: Date(year: 2029, month: 8, day: 1),
            firstName: "Bit",
            issueDate: Date(year: 2019, month: 8, day: 1),
            issuingAuthority: "DMV",
            issuingCountry: "United States",
            issuingState: "California",
            lastName: "Warden",
            licenseClass: "C",
            licenseNumber: "D1234567",
            middleName: "W",
        )
    }
}
#endif
