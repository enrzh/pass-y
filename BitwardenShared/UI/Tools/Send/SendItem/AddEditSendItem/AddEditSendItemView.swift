import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - AddEditSendItemView

/// A view that allows the user to add or edit a send item.
///
struct AddEditSendItemView: View { // swiftlint:disable:this type_body_length
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<AddEditSendItemState, AddEditSendItemAction, AddEditSendItemEffect>

    /// A state variable to track whether the TextField is focused
    @FocusState private var isMaxAccessCountFocused: Bool

    /// Tracks which recipient email field is focused.
    @FocusState private var focusedRecipientEmailIndex: Int?

    /// The environment's openURL action for opening URLs.
    @Environment(\.openURL) var openURL

    var body: some View {
        ZStack {
            // Native `Form` (Apple Passwords look): sections and rows come from the system.
            Form {
                if store.state.isSendDisabled {
                    Section {
                        infoLabel(Localizations.sendDisabledWarning)
                            .accessibilityIdentifier("DisabledSendPolicyLabel")
                    }
                } else if store.state.shouldShowHideEmailPolicyBanner {
                    Section {
                        infoLabel(Localizations.sendOptionsPolicyInEffect)
                            .accessibilityIdentifier("HideEmailAddressPolicyLabel")
                    }
                }

                sendDetails

                deletionDate

                whoCanView

                additionalOptions

                if store.state.mode == .edit {
                    Section { deleteSendButton }
                }
            }
            .disabled(store.state.isSendDisabled)
            .passYReadableWidth()

            profileSwitcher
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(store.state.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                cancelToolbarButton {
                    store.send(.dismissPressed)
                }

                switch store.state.mode {
                case .add,
                     .edit:
                    EmptyView()
                case let .shareExtension(profileSwitcherState):
                    ProfileSwitcherToolbarView(
                        store: store.child(
                            state: { _ in
                                profileSwitcherState
                            },
                            mapAction: { action in
                                .profileSwitcher(action)
                            },
                            mapEffect: { effect in
                                .profileSwitcher(effect)
                            },
                        ),
                    )
                }
            }

            // Save goes on the right (after the options menu)
            versionDependentOrderingToolbarItemGroup(
                alfa: {
                    if store.state.mode == .edit {
                        optionsToolbarMenu {
                            if !store.state.isSendDisabled {
                                if store.state.originalSendView?.hasPassword ?? false,
                                   !store.state.isAccessTypeEnforcedByPolicy {
                                    AsyncButton(Localizations.removePassword) {
                                        await store.perform(.removePassword)
                                    }
                                }
                                AsyncButton(Localizations.copyLink) {
                                    await store.perform(.copyLinkPressed)
                                }
                                AsyncButton(Localizations.shareLink) {
                                    await store.perform(.shareLinkPressed)
                                }
                            }
                        }
                    }
                },
                bravo: {
                    saveToolbarButton {
                        await store.perform(.savePressed)
                    }
                    .disabled(store.state.isSendDisabled)
                },
            )
        }
        .toast(store.binding(
            get: \.toast,
            send: AddEditSendItemAction.toastShown,
        ))
        .animation(.easeInOut(duration: 0.2), value: store.state.type)
        .animation(.default, value: store.state.isOptionsExpanded)
        .task {
            await store.perform(.loadData)
        }
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearURL)
        }
        .onChange(of: store.state.focusedRecipientEmailIndex) { newValue in
            guard focusedRecipientEmailIndex != newValue else { return }
            focusedRecipientEmailIndex = newValue
        }
        .onChange(of: focusedRecipientEmailIndex) { newValue in
            guard store.state.focusedRecipientEmailIndex != newValue else { return }
            store.send(.focusedRecipientEmailIndexChanged(newValue))
        }
    }

    /// A short policy note at the top of the form.
    private func infoLabel(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
    }

    /// The maximum access count, hide email and the private note behind "Additional options".
    @ViewBuilder private var additionalOptions: some View {
        PassYDisclosureSection(
            Localizations.additionalOptions,
            isExpanded: store.binding(
                get: \.isOptionsExpanded,
                send: { _ in AddEditSendItemAction.optionsPressed },
            ),
            identifier: "SendShowHideOptionsButton",
        ) {
            SendItemAccessCountStepper(
                currentAccessCount: store.state.currentAccessCount,
                maximumAccessCount: store.binding(
                    get: \.maximumAccessCount,
                    send: AddEditSendItemAction.maximumAccessCountStepperChanged,
                ),
            )

            if store.state.shouldShowHideEmailField {
                Section {
                    PassYToggleRow(
                        Localizations.hideEmail,
                        isOn: store.binding(
                            get: \.isHideMyEmailOn,
                            send: AddEditSendItemAction.hideMyEmailChanged,
                        ),
                        identifier: "SendHideEmailSwitch",
                    )
                    .disabled(!store.state.isHideMyEmailOn && store.state.isSendHideEmailDisabled)
                }
            }

            Section {
                PassYMultilineField(
                    Localizations.privateNote,
                    text: store.binding(
                        get: \.notes,
                        send: AddEditSendItemAction.notesChanged,
                    ),
                    identifier: "SendNotesEntry",
                )
            }
        }
    }

    /// The button to delete the send.
    private var deleteSendButton: some View {
        PassYInlineButtonRow(
            Localizations.deleteSend,
            systemImage: "trash",
            role: .destructive,
            identifier: "SendDeleteButton",
        ) {
            await store.perform(.deletePressed)
        }
    }

    /// The deletion date with its explanation.
    @ViewBuilder private var deletionDate: some View {
        Section {
            PassYPickerRow(
                Localizations.deletionDate,
                options: store.state.availableDeletionDateTypes,
                selection: store.binding(
                    get: \.deletionDate,
                    send: AddEditSendItemAction.deletionDateChanged,
                ),
                identifier: "SendDeletionOptionsPicker",
            )
            .disabled(store.state.isDeletionDateEnforcedByPolicy)
        } footer: {
            PassYSectionFooter(
                store.state.isDeletionDateEnforcedByPolicy
                    ? Localizations.thisDateIsEnforcedByYourOrganization
                    : Localizations.deletionDateInfo,
            )
        }
    }

    /// The file of a file send: the chosen file and "Choose file" (add), name and size (edit).
    @ViewBuilder private var fileSendAttributes: some View {
        switch store.state.mode {
        case .add, .shareExtension:
            if let fileName = store.state.fileName {
                Label(fileName, systemImage: "doc")
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("SendCurrentFileNameLabel")
            }

            if store.state.mode == .add {
                PassYInlineButtonRow(
                    Localizations.chooseFile,
                    systemImage: "paperclip",
                    identifier: "SendChooseFileButton",
                ) {
                    store.send(.chooseFilePressed)
                }
            }

        case .edit:
            LabeledContent {
                if let fileSize = store.state.fileSize {
                    Text(fileSize)
                }
            } label: {
                Label(store.state.fileName ?? "", systemImage: "doc")
            }
            .frame(minHeight: 44)
        }
    }

    /// The maximum file size note of a file send.
    private var fileSizeFooter: String {
        Localizations.requiredMaximumFileSizeIsX(
            ByteCountFormatter.string(fromByteCount: Int64(Constants.maxFileSizeBytes), countStyle: .binary),
        )
    }

    /// The name field.
    @ViewBuilder private var nameField: some View {
        PassYFormField(
            Localizations.sendNameRequired,
            text: store.binding(
                get: \.name,
                send: AddEditSendItemAction.nameChanged,
            ),
            style: .free,
            identifier: "SendNameEntry",
        )
        .textInputAutocapitalization(.sentences)
    }

    /// A view that displays the ability to add or switch between account profiles
    @ViewBuilder private var profileSwitcher: some View {
        switch store.state.mode {
        case let .shareExtension(profileSwitcherState):
            ProfileSwitcherView(
                store: store.child(
                    state: { _ in
                        profileSwitcherState
                    },
                    mapAction: { action in
                        .profileSwitcher(action)
                    },
                    mapEffect: { profileEffect in
                        .profileSwitcher(profileEffect)
                    },
                ),
            )
        default: EmptyView()
        }
    }

    /// The name and the content: the text (with "hide text by default") or the file.
    @ViewBuilder private var sendDetails: some View {
        Section {
            nameField

            switch store.state.type {
            case .text:
                textSendAttributes
                PassYToggleRow(
                    Localizations.hideTextByDefault,
                    isOn: store.binding(
                        get: \.isHideTextByDefaultOn,
                        send: AddEditSendItemAction.hideTextByDefaultChanged,
                    ),
                    identifier: "SendHideTextByDefaultToggle",
                )
            case .file:
                fileSendAttributes
            case .unknown:
                EmptyView()
            }
        } footer: {
            if store.state.type == .file, store.state.mode != .edit {
                PassYSectionFooter(fileSizeFooter)
            }
        }
    }

    /// "Who can view": the access type and, by type, the recipients or the password.
    @ViewBuilder private var whoCanView: some View {
        Section {
            // When the access type is enforced by policy, the picker shows the enforced selection but is disabled.
            PassYPickerRow(
                Localizations.whoCanView,
                options: SendAccessType.allCases,
                selection: store.binding(
                    get: \.accessType,
                    send: AddEditSendItemAction.accessTypeChanged,
                ),
                identifier: "SendAccessTypePicker",
            )
            .disabled(store.state.isAccessTypeEnforcedByPolicy)

            whoCanViewContent
        } footer: {
            if let footer = store.state.whoCanViewFooter {
                PassYSectionFooter(footer)
            }
        }
        .animation(.default, value: store.state.accessType)
    }

    /// The content displayed based on the selected access type.
    @ViewBuilder private var whoCanViewContent: some View {
        switch store.state.accessType {
        case .anyoneWithLink:
            EmptyView()
        case .specificPeople:
            recipientEmailsList
        case .anyoneWithPassword:
            if store.state.isPasswordFieldDisabled {
                // An existing Send's password can't be viewed or changed: a masked placeholder shows that the Send
                // is protected by a password.
                PassYCopyRow(
                    Localizations.password,
                    value: "",
                    secret: .init(isRevealed: false, canReveal: false) {},
                    identifier: "SendPasswordEntry",
                    copy: nil,
                )
            } else {
                PassYSecureField(
                    Localizations.password,
                    text: store.binding(
                        get: \.password,
                        send: AddEditSendItemAction.passwordChanged,
                    ),
                    isRevealed: store.binding(
                        get: \.isPasswordVisible,
                        send: AddEditSendItemAction.passwordVisibleChanged,
                    ),
                    identifier: "SendPasswordEntry",
                ) {
                    PassYIconButton(Localizations.generatePassword, systemImage: "arrow.trianglehead.2.clockwise") {
                        store.send(.generatePasswordPressed)
                    }
                    .accessibilityIdentifier("GenerateSendPasswordButton")

                    if !store.state.password.isEmpty {
                        PassYIconButton(Localizations.copyPassword, systemImage: "doc.on.doc") {
                            Task { await store.perform(.copyPasswordPressed) }
                        }
                        .accessibilityIdentifier("CopySendPasswordButton")
                    }
                }
                .textFieldConfiguration(.password)
            }
        }
    }

    /// The recipient e-mails of "Specific people", then "Add email".
    @ViewBuilder private var recipientEmailsList: some View {
        ForEach(store.state.recipientEmails.indices, id: \.self) { index in
            PassYFormField(
                Localizations.email,
                text: store.binding(
                    get: { state in
                        guard index < state.recipientEmails.count else { return "" }
                        return state.recipientEmails[index]
                    },
                    send: { .recipientEmailChanged(index: index, value: $0) },
                ),
                prompt: "name@example.com",
                identifier: "SendRecipientEmailEntry",
                focus: .field($focusedRecipientEmailIndex, equals: index),
            ) {
                if store.state.shouldShowTrashIcon(for: index) {
                    PassYIconButton(Localizations.delete, systemImage: "minus.circle.fill", role: .destructive) {
                        store.send(.removeRecipientEmail(index: index))
                    }
                    .accessibilityIdentifier("RemoveRecipientEmailButton")
                }
            }
            .textFieldConfiguration(.email)
            .accessibilityIdentifier("EmailRecipientCell")
        }

        PassYInlineButtonRow(Localizations.addEmail, systemImage: "plus", identifier: "AddRecipientEmailButton") {
            store.send(.addRecipientEmail)
        }
    }

    /// The text of a text send.
    @ViewBuilder private var textSendAttributes: some View {
        PassYMultilineField(
            Localizations.textToShareRequired,
            text: store.binding(
                get: \.text,
                send: AddEditSendItemAction.textChanged,
            ),
            identifier: "SendTextContentEntry",
        )
    }
}

// MARK: Previews

#if DEBUG
#Preview("Empty") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(),
                ),
            ),
        )
    }
}

#Preview("File") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(
                        fileName: "Example File",
                        isHideTextByDefaultOn: true,
                        name: "Sendy",
                        type: .file,
                    ),
                ),
            ),
        )
    }
}

#Preview("Text") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(
                        isHideTextByDefaultOn: true,
                        name: "Sendy",
                        text: "Example text",
                        type: .text,
                    ),
                ),
            ),
        )
    }
}

#Preview("Options") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(
                        isOptionsExpanded: true,
                    ),
                ),
            ),
        )
    }
}

#Preview("Text - Edit") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(
                        currentAccessCount: 42,
                        customDeletionDate: Date(),
                        deletionDate: .custom(.now),
                        isHideTextByDefaultOn: true,
                        isOptionsExpanded: true,
                        mode: .edit,
                        name: "Sendy",
                        text: "Example text",
                        type: .text,
                    ),
                ),
            ),
        )
    }
}

#Preview("File - Edit") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(
                        currentAccessCount: 42,
                        customDeletionDate: Date(),
                        deletionDate: .custom(.now),
                        fileName: "example.txt",
                        fileSize: "420.42 KB",
                        isHideTextByDefaultOn: true,
                        isOptionsExpanded: true,
                        mode: .edit,
                        name: "Sendy",
                        type: .file,
                    ),
                ),
            ),
        )
    }
}

#Preview("Text - Share") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(
                        currentAccessCount: 42,
                        customDeletionDate: Date(),
                        deletionDate: .custom(.now),
                        isHideTextByDefaultOn: true,
                        isOptionsExpanded: true,
                        mode: .shareExtension(.singleAccount),
                        name: "Sendy",
                        text: "Example text",
                        type: .text,
                    ),
                ),
            ),
        )
    }
}

#Preview("Specific People") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(
                        accessType: .specificPeople,
                        hasPremium: true,
                        name: "Sendy",
                        recipientEmails: ["test@example.com", ""],
                        text: "Example text",
                        type: .text,
                    ),
                ),
            ),
        )
    }
}

#Preview("Anyone with Password") {
    NavigationView {
        AddEditSendItemView(
            store: Store(
                processor: StateProcessor(
                    state: AddEditSendItemState(
                        accessType: .anyoneWithPassword,
                        name: "Sendy",
                        password: "secret123",
                        text: "Example text",
                        type: .text,
                    ),
                ),
            ),
        )
    }
}

#endif // swiftlint:disable:this file_length
