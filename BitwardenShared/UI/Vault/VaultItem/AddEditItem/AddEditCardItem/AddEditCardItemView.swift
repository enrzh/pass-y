import BitwardenKit
import BitwardenResources
import SwiftUI
import VisionKit

// MARK: - AddEditCardItemView

/// A view that allows the user to add or edit a card item for a vault.
///
struct AddEditCardItemView: View {
    // MARK: Type

    /// The focusable fields in identity view.
    enum FocusedField: Int, Hashable {
        case cardholderName
        case number
        case expirationYear
        case securityCode
    }

    // MARK: Properties

    /// The currently focused field.
    @FocusState private var focusedField: FocusedField?

    /// Pre-warmed scanner created the moment the button is tapped so hardware init
    /// overlaps the sheet presentation animation rather than happening after it.
    /// Typed as `AnyObject?` to avoid placing `@available` on a stored property.
    @SwiftUI.State private var preWarmedScanner: AnyObject?

    /// The `Store` for this view.
    @ObservedObject var store: Store<any AddEditCardItemState, AddEditCardItemAction, AddEditItemEffect>

    var body: some View {
        Section {
            PassYFormField(
                Localizations.cardholderName,
                text: store.binding(
                    get: \.cardholderName,
                    send: AddEditCardItemAction.cardholderNameChanged,
                ),
                identifier: "CardholderNameEntry",
                focus: .field($focusedField, equals: .cardholderName),
            )
            .textContentType(.creditCardNameOrName)
            .textInputAutocapitalization(.words)
            .onSubmit { focusNextField($focusedField) }

            PassYSecureField(
                Localizations.number,
                text: store.binding(
                    get: \.formattedCardNumber,
                    send: AddEditCardItemAction.cardNumberChanged,
                ),
                isRevealed: store.binding(
                    get: \.isNumberVisible,
                    send: AddEditCardItemAction.toggleNumberVisibilityChanged,
                ),
                identifier: "CardNumberEntry",
                revealIdentifier: "ShowCardNumberButton",
                revealSpokenName: Localizations.number,
                focus: .field($focusedField, equals: .number),
            )
            .textFieldConfiguration(.numeric(.creditCardNumber))
            .onSubmit { focusNextField($focusedField) }

            PassYPickerRow(
                Localizations.brand,
                options: DefaultableType<CardComponent.Brand>.allCases,
                selection: store.binding(
                    get: \.brand,
                    send: AddEditCardItemAction.brandChanged,
                ),
                identifier: "CardBrandPicker",
            )

            PassYPickerRow(
                Localizations.expirationMonth,
                options: DefaultableType<CardComponent.Month>.allCases,
                selection: store.binding(
                    get: \.expirationMonth,
                    send: AddEditCardItemAction.expirationMonthChanged,
                ),
                identifier: "CardExpirationMonthPicker",
            )

            PassYFormField(
                Localizations.expirationYear,
                text: store.binding(
                    get: \.expirationYear,
                    send: AddEditCardItemAction.expirationYearChanged,
                ),
                prompt: "YYYY",
                identifier: "CardExpirationYearEntry",
                focus: .field($focusedField, equals: .expirationYear),
            )
            .textFieldConfiguration(.numeric(.creditCardExpirationYearOrDateTime))
            .onSubmit { focusNextField($focusedField) }

            PassYSecureField(
                Localizations.securityCode,
                text: store.binding(
                    get: \.cardSecurityCode,
                    send: AddEditCardItemAction.cardSecurityCodeChanged,
                ),
                isRevealed: store.binding(
                    get: \.isCodeVisible,
                    send: AddEditCardItemAction.toggleCodeVisibilityChanged,
                ),
                identifier: "CardSecurityCodeEntry",
                revealIdentifier: "CardShowSecurityCodeButton",
                revealSpokenName: Localizations.securityCode,
                focus: .field($focusedField, equals: .securityCode),
            )
            .textFieldConfiguration(.numeric(.creditCardSecurityCodeOrPassword))
            .onSubmit { focusNextField($focusedField) }

            scanCardButton
        }
        .sheet(
            isPresented: Binding(
                get: { store.state.isCardScannerPresented },
                set: { _ in
                    preWarmedScanner = nil
                    store.send(.cardScannerDismissed)
                },
            ),
        ) {
            if let scanner = preWarmedScanner as? DataScannerViewController {
                CardScannerWrapperView(scanner: scanner) { lines in
                    store.send(.cardScannerLinesUpdated(lines))
                }
            }
        }
        .onChange(of: store.state.shouldFocusCardholderNameAfterScan) { shouldFocus in
            guard shouldFocus else { return }
            focusedField = .cardholderName
        }
        .onChange(of: store.state.isCardScannerPresented) { isPresented in
            if !isPresented {
                preWarmedScanner = nil
            }
        }
    }

    // MARK: Private Views

    /// A row that opens the card scanner. Only shown on devices with camera support and
    /// ``FeatureFlag.cardScanner`` enabled.
    @ViewBuilder private var scanCardButton: some View {
        if DataScannerViewController.isSupported, store.state.cardScannerEnabled {
            PassYInlineButtonRow(Localizations.scanCard, systemImage: "camera", identifier: "ScanCardButton") {
                preWarmedScanner = CardScannerView.makeScanner()
                await store.perform(.scanCardButtonTapped)
            }
        }
    }
}

#if DEBUG
#Preview("Empty Add Edit State") {
    NavigationView {
        Form {
            AddEditCardItemView(
                store: Store(
                    processor: StateProcessor(
                        state: CardItemState() as (any AddEditCardItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Empty Add Edit State")
    }
}

#Preview("Hidden Add Edit State") {
    NavigationView {
        Form {
            AddEditCardItemView(
                store: Store(
                    processor: StateProcessor(
                        state: {
                            var state = CardItemState()
                            state.brand = .custom(.visa)
                            state.cardNumber = "4400123456789"
                            state.cardSecurityCode = "123"
                            state.cardholderName = "Bitwarden User"
                            state.expirationMonth = .custom(.aug)
                            state.expirationYear = "1989"
                            return state
                        }() as (any AddEditCardItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Hidden Add Edit State")
    }
}

#Preview("Visible Add Edit State") {
    NavigationView {
        Form {
            AddEditCardItemView(
                store: Store(
                    processor: StateProcessor(
                        state: {
                            var state = CardItemState()
                            state.brand = .custom(.visa)
                            state.cardNumber = "4400123456789"
                            state.cardSecurityCode = "123"
                            state.cardholderName = "Bitwarden User"
                            state.expirationMonth = .custom(.aug)
                            state.expirationYear = "1989"
                            state.isCodeVisible = true
                            state.isNumberVisible = true
                            return state
                        }() as (any AddEditCardItemState),
                    ),
                ),
            )
        }
        .navigationTitle("Visible Add Edit State")
    }
}
#endif
