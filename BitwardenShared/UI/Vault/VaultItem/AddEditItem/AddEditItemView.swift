import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - AddEditItemView

/// A view that allows the user to add or edit a new item for a vault.
///
struct AddEditItemView: View {
    // MARK: Private Properties

    /// An object used to open urls in this view.
    @Environment(\.openURL) private var openURL

    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<AddEditItemState, AddEditItemAction, AddEditItemEffect>

    /// Whether to show that a policy is in effect.
    var isPolicyEnabled: Bool {
        store.state.isPersonalOwnershipDisabled && store.state.configuration == .add
    }

    // MARK: View

    var body: some View {
        Group {
            switch store.state.configuration {
            case .add:
                addView
            case .existing:
                existing
            }
        }
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearUrl)
        }
        .navigationTitle(store.state.navigationTitle)
        .task { await store.perform(.appeared) }
        .task { await store.perform(.fetchCipherOptions) }
        .task { await store.perform(.streamCipherDetails) }
        .task { await store.perform(.streamFolders) }
        .toast(store.binding(
            get: \.toast,
            send: AddEditItemAction.toastShown,
        ))
    }

    private var addView: some View {
        content
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismissPressed)
                }

                saveToolbarItem {
                    await store.perform(.savePressed)
                }
            }
    }

    private var content: some View {
        // A native `Form` of PassYDesign rows (Apple Passwords look): the name, where the item goes, the type's
        // fields, then the rarely used options behind "Additional options". The "learn new logins" tour card is
        // Bitwarden onboarding and is no longer shown.
        Form {
            if isPolicyEnabled {
                Section {
                    infoLabel(Localizations.personalOwnershipPolicyInEffect, systemImage: "building.2")
                        .accessibilityIdentifier("PersonalOwnershipPolicyLabel")
                }
            }

            if store.state.shouldDisplayAsArchived {
                Section {
                    infoLabel(store.state.archiveInfoText, systemImage: "archivebox")
                        .accessibilityIdentifier("ArchivedLabel")
                }
            }

            itemDetailsSection
            itemTypeSection.disabled(store.state.isReadOnly)
            additionalOptions.disabled(store.state.isReadOnly)
        }
        .animation(.default, value: store.state.collectionsForOwner)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 30, for: .scrollContent)
        .passYReadableWidth()
    }

    /// A short note at the top of the form (policy, archived).
    private func infoLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
    }

    private var existing: some View {
        content
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismissPressed)
                }

                // Save goes on the right (after the options menu)
                versionDependentOrderingToolbarItemGroup(
                    alfa: {
                        VaultItemManagementMenuView(
                            isArchiveEnabled: store.state.canBeArchived,
                            isCloneEnabled: false,
                            isCollectionsEnabled: store.state.canAssignToCollection,
                            isDeleteEnabled: store.state.canBeDeleted,
                            isMoveToOrganizationEnabled: store.state.canMoveToOrganization,
                            isRestoreEnabled: false,
                            isUnarchiveEnabled: store.state.canBeUnarchived,
                            store: store.child(
                                state: { _ in },
                                mapAction: { .morePressed($0) },
                                mapEffect: { effect in
                                    switch effect {
                                    case .archiveItem:
                                        .archivedPressed
                                    case .deleteItem:
                                        .deletePressed
                                    case .unarchiveItem:
                                        .unarchivePressed
                                    }
                                },
                            ),
                        )
                    },
                    bravo: {
                        saveToolbarButton {
                            await store.perform(.savePressed)
                        }
                    },
                )
            }
    }

    /// The name (with the favorite star), the folder and, for new items of organization members, the owner and
    /// the collections.
    private var itemDetailsSection: some View {
        Group {
            Section {
                PassYFormField(
                    Localizations.itemNameRequired,
                    text: store.binding(
                        get: \.name,
                        send: AddEditItemAction.nameChanged,
                    ),
                    style: .free,
                    identifier: "ItemNameEntry",
                    isReadOnly: store.state.isReadOnly,
                ) {
                    Button {
                        store.send(.favoriteChanged(!store.state.isFavoriteOn))
                    } label: {
                        Image(systemName: store.state.isFavoriteOn ? "star.fill" : "star")
                            .foregroundStyle(store.state.isFavoriteOn ? AnyShapeStyle(.yellow) : AnyShapeStyle(.secondary))
                    }
                    .accessibilityIdentifier("ItemFavoriteButton")
                    .accessibilityLabel(Localizations.favorite)
                    .accessibilityValue(store.state.isFavoriteOn ? Localizations.on : Localizations.off)
                }
                .textInputAutocapitalization(.words)

                PassYPickerRow(
                    store.state.folderTitle,
                    options: store.state.folders,
                    selection: store.binding(
                        get: \.folder,
                        send: AddEditItemAction.folderChanged,
                    ),
                    identifier: "FolderPicker",
                ) {
                    Divider()
                    Button(Localizations.addFolder, systemImage: "folder.badge.plus") {
                        store.send(.addFolder)
                    }
                }
            }

            if store.state.configuration.isAdding, store.state.hasOrganizations, let owner = store.state.owner {
                Section {
                    PassYPickerRow(
                        store.state.ownerFieldTitle,
                        options: store.state.ownershipOptions,
                        selection: store.binding(
                            get: { _ in owner },
                            send: AddEditItemAction.ownerChanged,
                        ),
                        identifier: "ItemOwnershipPicker",
                    )

                    ForEach(store.state.collectionsForOwner, id: \.id) { collection in
                        if let collectionId = collection.id {
                            PassYToggleRow(
                                collection.name,
                                isOn: store.binding(
                                    get: { _ in store.state.collectionIds.contains(collectionId) },
                                    send: { .collectionToggleChanged($0, collectionId: collectionId) },
                                ),
                                identifier: "CollectionItemSwitch",
                            )
                        }
                    }
                }
            }
        }
    }
}

private extension AddEditItemView {
    /// Notes (for types other than secure notes), the master password re-prompt and the custom fields behind
    /// one "Additional options" row.
    @ViewBuilder var additionalOptions: some View {
        PassYDisclosureSection(
            Localizations.additionalOptions,
            isExpanded: store.binding(
                get: \.isAdditionalOptionsExpanded,
                send: AddEditItemAction.toggleAdditionalOptionsExpanded,
            ),
        ) {
            if store.state.type != .secureNote {
                Section { notesField }
            }

            if store.state.showMasterPasswordReprompt {
                Section {
                    PassYToggleRow(
                        Localizations.passwordPrompt,
                        isOn: store.binding(
                            get: \.isMasterPasswordRePromptOn,
                            send: AddEditItemAction.masterPasswordRePromptChanged,
                        ),
                        identifier: "MasterPasswordRepromptToggle",
                        accessibilityLabel: Localizations.passwordPrompt,
                        helpURL: ExternalLinksConstants.protectIndividualItems,
                        helpLabel: Localizations.masterPasswordRePromptHelp,
                    )
                }
            }

            customSection
        }
    }

    /// The section containing custom fields.
    private var customSection: some View {
        AddEditCustomFieldsView(
            store: store.child(
                state: { $0.customFieldsState },
                mapAction: { .customField($0) },
                mapEffect: nil,
            ),
        )
        .animation(.easeInOut(duration: 0.2), value: store.state.customFieldsState)
    }

    /// The notes field.
    private var notesField: some View {
        PassYMultilineField(
            Localizations.notes,
            text: store.binding(
                get: \.notes,
                send: AddEditItemAction.notesChanged,
            ),
            identifier: "ItemNotesEntry",
            isEditable: !store.state.isReadOnly,
        )
    }
}

private extension AddEditItemView {
    /// Specific fields for a bank account item.
    @ViewBuilder private var bankAccountItems: some View {
        AddEditBankAccountItemView(
            store: store.child(
                state: { addEditState in
                    addEditState.bankAccountItemState
                },
                mapAction: { action in
                    .bankAccountFieldChanged(action)
                },
                mapEffect: { $0 },
            ),
        )
    }

    /// Specific fields for a card item.
    @ViewBuilder private var cardItems: some View {
        AddEditCardItemView(
            store: store.child(
                state: { addEditState in
                    addEditState.cardItemState
                },
                mapAction: { action in
                    .cardFieldChanged(action)
                },
                mapEffect: { $0 },
            ),
        )
    }

    /// Specific fields for a driver's license item.
    @ViewBuilder private var driversLicenseItems: some View {
        AddEditDriversLicenseItemView(
            store: store.child(
                state: { addEditState in
                    addEditState.driversLicenseItemState
                },
                mapAction: { action in
                    .driversLicenseFieldChanged(action)
                },
                mapEffect: { $0 },
            ),
        )
    }

    /// Specific fields for an identity item.
    @ViewBuilder private var identityItems: some View {
        AddEditIdentityItemView(
            store: store.child(
                state: { addEditState in
                    addEditState.identityState
                },
                mapAction: { action in
                    .identityFieldChanged(action)
                },
                mapEffect: { $0 },
            ),
        )
    }

    /// The specific fields for the type of item being created or updated.
    @ViewBuilder private var itemTypeSection: some View {
        switch store.state.type {
        case .bankAccount:
            bankAccountItems
        case .driversLicense:
            driversLicenseItems
        case .passport:
            passportItems
        case .card:
            cardItems
        case .login:
            loginItems
        case .secureNote:
            Section { notesField }
        case .identity:
            identityItems
        case .sshKey:
            sshKeyItems
        }
    }

    /// Specific fields for a login item.
    @ViewBuilder private var loginItems: some View {
        AddEditLoginItemView(
            store: store.child(
                state: { addEditState in
                    addEditState.loginState
                },
                mapAction: { $0 },
                mapEffect: { $0 },
            ),
            didRenderFrame: { step, frame in
                let enlargedFrame = frame.enlarged(by: 8)
                store.send(
                    .guidedTourViewAction(.didRenderViewToSpotlight(
                        frame: enlargedFrame,
                        step: step,
                    )),
                )
            },
        )
    }

    /// Specific fields for a passport item.
    @ViewBuilder private var passportItems: some View {
        AddEditPassportItemView(
            store: store.child(
                state: { addEditState in
                    addEditState.passportItemState
                },
                mapAction: { action in
                    .passportFieldChanged(action)
                },
                mapEffect: { $0 },
            ),
        )
    }

    /// Specific fields for a SSK key item.
    @ViewBuilder private var sshKeyItems: some View {
        ViewSSHKeyItemView(
            showCopyButtons: false,
            store: store.child(
                state: { _ in store.state.sshKeyState },
                mapAction: { .sshKeyItemAction($0) },
                mapEffect: nil,
            ),
        )
    }
}

#if DEBUG
private enum AddEditItemPreviewData {
    static var cipherState: CipherItemState {
        var state = CipherItemState(
            existing: .fixture(
                favorite: true,
                login: .fixture(
                    fido2Credentials: [
                        .fixture(
                            creationDate: Date(timeIntervalSince1970: 1_710_494_110),
                        ),
                    ],
                    password: "changerdanger",
                    uris: [
                        .fixture(uri: "yahoo.com"),
                        .fixture(uri: "account.yahoo.com"),
                    ],
                    username: "EddyEddity",
                ),
                name: "Edit Em",
                type: .login,
            ),
            hasPremium: true,
        )!
        state.ownershipOptions = [.personal(displayName: "user@bitwarden.com")]
        return state
    }
}

#Preview("Empty Add") {
    NavigationView {
        AddEditItemView(
            store: Store(
                processor: StateProcessor(
                    state: CipherItemState(
                        hasPremium: true,
                    ).addEditState,
                ),
            ),
        )
    }
}

#Preview("Edit Notes") {
    NavigationView {
        AddEditItemView(
            store: Store(
                processor: StateProcessor(
                    state: {
                        var state = AddEditItemPreviewData.cipherState
                        state.notes = "This is a nice note"
                        return state
                    }(),
                ),
            ),
        )
    }
}

#Preview("Add Card") {
    NavigationView {
        AddEditItemView(
            store: Store(
                processor: StateProcessor(
                    state: CipherItemState(
                        addItem: .card,
                        hasPremium: true,
                    )
                    .addEditState,
                ),
            ),
        )
    }
}

#Preview("Edit Card") {
    NavigationView {
        AddEditItemView(
            store: Store(
                processor: StateProcessor(
                    state: {
                        var copy = AddEditItemPreviewData.cipherState
                        copy.name = "Sample Card"
                        copy.type = .card
                        copy.cardItemState = .init(
                            brand: .custom(.americanExpress),
                            cardholderName: "Bitwarden User",
                            cardNumber: "123456789012345",
                            cardSecurityCode: "123",
                            expirationMonth: .custom(.feb),
                            expirationYear: "3009",
                        )
                        copy.folderId = "1"
                        copy.folders = [
                            .custom(FolderView(id: "1", name: "Financials", revisionDate: Date())),
                        ]
                        copy.isFavoriteOn = false
                        copy.isMasterPasswordRePromptOn = true
                        copy.owner = .personal(displayName: "security@bitwarden.com")
                        return copy.addEditState
                    }(),
                ),
            ),
        )
    }
}

#Preview("Edit Login") {
    NavigationView {
        AddEditItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditItemPreviewData.cipherState.addEditState,
                ),
            ),
        )
    }
}

#Preview("Edit Login: Key Added") {
    NavigationView {
        AddEditItemView(
            store: Store(
                processor: StateProcessor(
                    state: {
                        var state = AddEditItemPreviewData.cipherState
                        state.loginState.totpState = .init("JBSWY3DPEHPK3PXP")
                        state.toast = Toast(title: "Authenticator key added.")
                        return state
                    }(),
                ),
            ),
        )
    }
}
#endif // swiftlint:disable:this file_length
