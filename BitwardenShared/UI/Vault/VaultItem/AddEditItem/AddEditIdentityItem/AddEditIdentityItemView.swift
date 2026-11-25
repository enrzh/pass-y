import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AddEditIdentityItemView

/// A view that allows the user to add or edit Identity part of the cipherItem to a vault.
///
struct AddEditIdentityItemView: View {
    // MARK: Type

    /// The focusable fields in identity view.
    enum FocusedField: Int, Hashable {
        case firstName
        case middleName
        case lastName
        case username
        case company
        case ssn
        case passport
        case license
        case email
        case phone
        case address1
        case address2
        case address3
        case city
        case state
        case zipcode
        case country
    }

    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<IdentityItemState, AddEditIdentityItemAction, AddEditItemEffect>

    /// The currently focused field.
    @FocusState private var focusedField: FocusedField?

    // MARK: Views

    var body: some View {
        personalDetailsSection
        identificationSection
        contactInfoSection
        addressSection
    }

    /// The address section.
    var addressSection: some View {
        Section {
            PassYFormField(
                Localizations.address1,
                text: store.binding(
                    get: \.address1,
                    send: AddEditIdentityItemAction.address1Changed,
                ),
                identifier: "IdentityAddressOneEntry",
                focus: .field($focusedField, equals: .address1),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.address2,
                text: store.binding(
                    get: \.address2,
                    send: AddEditIdentityItemAction.address2Changed,
                ),
                identifier: "IdentityAddressTwoEntry",
                focus: .field($focusedField, equals: .address2),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.address3,
                text: store.binding(
                    get: \.address3,
                    send: AddEditIdentityItemAction.address3Changed,
                ),
                identifier: "IdentityAddressThreeEntry",
                focus: .field($focusedField, equals: .address3),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.cityTown,
                text: store.binding(
                    get: \.cityOrTown,
                    send: AddEditIdentityItemAction.cityOrTownChanged,
                ),
                identifier: "IdentityCityEntry",
                focus: .field($focusedField, equals: .city),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.stateProvince,
                text: store.binding(
                    get: \.state,
                    send: AddEditIdentityItemAction.stateChanged,
                ),
                identifier: "IdentityStateEntry",
                focus: .field($focusedField, equals: .state),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.zipPostalCode,
                text: store.binding(
                    get: \.postalCode,
                    send: AddEditIdentityItemAction.postalCodeChanged,
                ),
                identifier: "IdentityPostalCodeEntry",
                focus: .field($focusedField, equals: .zipcode),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.country,
                text: store.binding(
                    get: \.country,
                    send: AddEditIdentityItemAction.countryChanged,
                ),
                identifier: "IdentityCountryEntry",
                focus: .field($focusedField, equals: .country),
            )
            .onSubmit { focusNextField($focusedField) }
        }
    }

    /// The contact info section.
    var contactInfoSection: some View {
        Section {
            PassYFormField(
                Localizations.email,
                text: store.binding(
                    get: \.email,
                    send: AddEditIdentityItemAction.emailChanged,
                ),
                identifier: "IdentityEmailEntry",
                focus: .field($focusedField, equals: .email),
            )
            .textFieldConfiguration(.email)
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.phone,
                text: store.binding(
                    get: \.phone,
                    send: AddEditIdentityItemAction.phoneNumberChanged,
                ),
                identifier: "IdentityPhoneEntry",
                focus: .field($focusedField, equals: .phone),
            )
            .textFieldConfiguration(.numeric(.telephoneNumber))
            .onSubmit { focusNextField($focusedField) }
        }
    }

    /// The identification section.
    var identificationSection: some View {
        Section {
            PassYSecureField(
                Localizations.ssn,
                text: store.binding(
                    get: \.socialSecurityNumber,
                    send: AddEditIdentityItemAction.socialSecurityNumberChanged,
                ),
                isRevealed: store.binding(
                    get: \.showSocialSecurityNumber,
                    send: AddEditIdentityItemAction.ssnVisibilityChanged,
                ),
                canReveal: true,
                identifier: "IdentitySsnEntry",
                revealIdentifier: "IdentitySsnVisibilityButton",
                focus: .field($focusedField, equals: .ssn),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.passportNumber,
                text: store.binding(
                    get: \.passportNumber,
                    send: AddEditIdentityItemAction.passportNumberChanged,
                ),
                identifier: "IdentityPassportNumberEntry",
                focus: .field($focusedField, equals: .passport),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.licenseNumber,
                text: store.binding(
                    get: \.licenseNumber,
                    send: AddEditIdentityItemAction.licenseNumberChanged,
                ),
                identifier: "IdentityLicenseNumberEntry",
                focus: .field($focusedField, equals: .license),
            )
            .onSubmit { focusNextField($focusedField) }
        }
    }

    /// The personal details section.
    var personalDetailsSection: some View {
        Section {
            PassYPickerRow(
                Localizations.title,
                options: DefaultableType<TitleType>.allCases,
                selection: store.binding(
                    get: \.title,
                    send: AddEditIdentityItemAction.titleChanged,
                ),
                identifier: "IdentityTitlePicker",
            )

            PassYFormField(
                Localizations.firstName,
                text: store.binding(
                    get: \.firstName,
                    send: AddEditIdentityItemAction.firstNameChanged,
                ),
                identifier: "IdentityFirstNameEntry",
                focus: .field($focusedField, equals: .firstName),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.middleName,
                text: store.binding(
                    get: \.middleName,
                    send: AddEditIdentityItemAction.middleNameChanged,
                ),
                identifier: "IdentityMiddleNameEntry",
                focus: .field($focusedField, equals: .middleName),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.lastName,
                text: store.binding(
                    get: \.lastName,
                    send: AddEditIdentityItemAction.lastNameChanged,
                ),
                identifier: "IdentityLastNameEntry",
                focus: .field($focusedField, equals: .lastName),
            )
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.username,
                text: store.binding(
                    get: \.userName,
                    send: AddEditIdentityItemAction.userNameChanged,
                ),
                identifier: "IdentityUsernameEntry",
                focus: .field($focusedField, equals: .username),
            )
            .textFieldConfiguration(.username)
            .onSubmit { focusNextField($focusedField) }

            PassYFormField(
                Localizations.company,
                text: store.binding(
                    get: \.company,
                    send: AddEditIdentityItemAction.companyChanged,
                ),
                identifier: "IdentityCompanyEntry",
                focus: .field($focusedField, equals: .company),
            )
            .onSubmit { focusNextField($focusedField) }
        }
    }
}

// MARK: Previews

#if DEBUG
#Preview("Empty Add Edit Identity State") {
    NavigationView {
        Form {
            Group {
                AddEditIdentityItemView(
                    store: Store(
                        processor: StateProcessor(
                            state: IdentityItemState(),
                        ),
                    ),
                )
            }
        }
    }
}
#endif
