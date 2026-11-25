import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - AddEditCustomFieldsView

/// A custom fields view for displaying custom fields for vault items.
struct AddEditCustomFieldsView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<AddEditCustomFieldsState, AddEditCustomFieldsAction, Void>

    var body: some View {
        Section {
            ForEachIndexed(store.state.customFields) { index, field in
                switch field.type {
                case .text:
                    PassYFormField(
                        field.name ?? "",
                        text: store.binding(
                            get: { _ in field.value ?? "" },
                            send: { .customFieldChanged($0, index: index) },
                        ),
                    ) {
                        menuOptions(index: index)
                    }
                case .hidden:
                    PassYSecureField(
                        field.name ?? "",
                        text: store.binding(
                            get: { _ in field.value ?? "" },
                            send: { .customFieldChanged($0, index: index) },
                        ),
                        isRevealed: store.binding(
                            get: { _ in field.isPasswordVisible },
                            send: { flag in
                                AddEditCustomFieldsAction.togglePasswordVisibilityChanged(flag, index)
                            },
                        ),
                        revealIdentifier: "HiddenCustomFieldShowValueButton",
                    ) {
                        menuOptions(index: index)
                    }
                    .textFieldConfiguration(.password)
                case .boolean:
                    HStack(spacing: PassYDesign.Spacing.small) {
                        PassYToggleRow(
                            field.name ?? "",
                            isOn: store.binding(
                                get: { _ in field.booleanValue },
                                send: { flag in
                                    AddEditCustomFieldsAction.booleanFieldChanged(flag, index)
                                },
                            ),
                        )
                        menuOptions(index: index)
                    }
                case .linked:
                    HStack(spacing: PassYDesign.Spacing.small) {
                        PassYPickerRow(
                            field.name ?? "",
                            options: LinkedIdType.getLinkedIdType(for: store.state.cipherType),
                            selection: store.binding(
                                get: { state in
                                    if let idType = field.linkedIdType ??
                                        LinkedIdType.getLinkedIdType(for: state.cipherType).first {
                                        return idType
                                    } else {
                                        assertionFailure("The default LinkedIdType for the customField " +
                                            "should have been set when the user creates linked custom fields.")
                                        return .cardBrand
                                    }
                                },
                                send: { idType in
                                    AddEditCustomFieldsAction.selectedLinkedIdType(index, idType)
                                },
                            ),
                            optionTitle: \.localizedName,
                        )
                        menuOptions(index: index)
                    }
                }
            }

            PassYInlineButtonRow(
                Localizations.newCustomField,
                systemImage: "plus",
                identifier: "NewCustomFieldButton",
            ) {
                store.send(.newCustomFieldPressed)
            }
        }
    }

    /// The options of a field: rename, move up/down, remove.
    func menuOptions(index: Int) -> some View {
        Menu {
            Button(Localizations.edit, systemImage: "pencil") {
                store.send(.editCustomFieldNamePressed(index: index))
            }

            Button(Localizations.moveUp, systemImage: "arrow.up") {
                store.send(.moveUpCustomFieldPressed(index: index))
            }

            Button(Localizations.moveDown, systemImage: "arrow.down") {
                store.send(.moveDownCustomFieldPressed(index: index))
            }

            Button(Localizations.remove, systemImage: "trash", role: .destructive) {
                store.send(.removeCustomFieldPressed(index: index))
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.tint)
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Localizations.options)
    }
}

#if DEBUG
#Preview {
    Form {
    AddEditCustomFieldsView(
        store: Store(
            processor: StateProcessor(
                state: AddEditCustomFieldsState(
                    cipherType: .identity,
                    customFields: [
                        CustomFieldState(
                            linkedIdType: nil,
                            name: "Custom text",
                            type: .text,
                            value: "value goes here",
                        ),
                        CustomFieldState(
                            linkedIdType: nil,
                            name: "Custom text",
                            type: .hidden,
                            value: "value goes here",
                        ),
                        CustomFieldState(
                            linkedIdType: nil,
                            name: "Custom boolean",
                            type: .boolean,
                        ),
                        CustomFieldState(
                            linkedIdType: .identityFirstName,
                            name: "Custom linked field",
                            type: .linked,
                        ),
                    ],
                ),
            ),
        ),
    )
    }
}
#endif
