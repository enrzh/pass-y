import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ViewDriversLicenseItemView

/// The license details: tap-to-copy rows; the license number masked with an eye button and read character by
/// character by VoiceOver. No section title.
struct ViewDriversLicenseItemView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<DriversLicenseItemState, ViewItemAction, Void>

    var body: some View {
        if !store.state.isLicenseDetailsSectionEmpty {
            Section {
                row(Localizations.firstName, store.state.firstName, "DriversLicenseFirstNameEntry", .firstName)
                row(Localizations.middleName, store.state.middleName, "DriversLicenseMiddleNameEntry", .middleName)
                row(Localizations.lastName, store.state.lastName, "DriversLicenseLastNameEntry", .lastName)
                licenseNumberItem
                dateRow(Localizations.dateOfBirth, store.state.dateOfBirth)
                row(Localizations.issuingCountry, store.state.issuingCountry, "DriversLicenseIssuingCountryEntry", nil)
                row(Localizations.issuingStateProvince, store.state.issuingState, "DriversLicenseIssuingStateEntry", nil)
                row(Localizations.issuingAuthority, store.state.issuingAuthority, "DriversLicenseIssuingAuthorityEntry", nil)
                dateRow(Localizations.issueDate, store.state.issueDate)
                dateRow(Localizations.expirationDate, store.state.expirationDate)
                row(Localizations.licenseClass, store.state.licenseClass, "DriversLicenseClassEntry", nil)
            }
        }
    }

    // MARK: Private Views

    /// The license number, masked with an eye button, copies on tap.
    @ViewBuilder private var licenseNumberItem: some View {
        let licenseNumber = store.state.licenseNumber
        if !licenseNumber.isEmpty {
            PassYCopyRow(
                Localizations.licenseNumber,
                value: licenseNumber,
                secret: .init(
                    isRevealed: store.state.isLicenseNumberVisible,
                    revealIdentifier: "ShowDriversLicenseNumberButton",
                    tintsCharacters: false,
                    spokenName: Localizations.licenseNumber,
                ) {
                    store.send(.driversLicenseItemAction(.toggleLicenseNumberVisibilityChanged))
                },
                identifier: "DriversLicenseNumberEntry",
                spellsOut: true,
            ) {
                store.send(.copyPressed(value: licenseNumber, field: .licenseNumber))
            }
        }
    }

    // MARK: Private Methods

    /// A value row (copies on tap when `field` is set), nothing for an empty value.
    @ViewBuilder
    private func row(_ title: String, _ value: String, _ identifier: String, _ field: CopyableField?) -> some View {
        if !value.isEmpty {
            PassYCopyRow(
                title,
                value: value,
                identifier: identifier,
                copy: field.map { field in { store.send(.copyPressed(value: value, field: field)) } },
            )
        }
    }

    /// A long date, nothing when unset.
    @ViewBuilder
    private func dateRow(_ title: String, _ value: Date?) -> some View {
        if let value {
            PassYCopyRow(title, value: value.longCalendarDateDisplay, copy: nil)
        }
    }
}

// MARK: - DriversLicenseItemState

extension DriversLicenseItemState {
    /// Whether the license details section has no values to display.
    var isLicenseDetailsSectionEmpty: Bool {
        [
            firstName,
            middleName,
            lastName,
            licenseNumber,
            issuingCountry,
            issuingState,
            issuingAuthority,
            licenseClass,
        ].allSatisfy(\.isEmpty)
            && dateOfBirth == nil
            && issueDate == nil
            && expirationDate == nil
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty View State") {
    NavigationView {
        Form {
            Group {
                ViewDriversLicenseItemView(
                    store: Store(
                        processor: StateProcessor(state: DriversLicenseItemState()),
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
                ViewDriversLicenseItemView(
                    store: Store(
                        processor: StateProcessor(
                            state: DriversLicenseItemState(
                                dateOfBirth: Date(year: 2025, month: 4, day: 20),
                                expirationDate: Date(year: 2026, month: 8, day: 10),
                                firstName: "Mitchell",
                                issueDate: Date(year: 2021, month: 8, day: 10),
                                issuingAuthority: "DMV",
                                issuingCountry: "United States",
                                issuingState: "Wisconsin",
                                lastName: "Johnson",
                                licenseClass: "D",
                                licenseNumber: "1234567890",
                                middleName: "Allen",
                            ),
                        ),
                    ),
                )
            }
        }
    }
}
#endif
