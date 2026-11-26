import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ViewItemDetailsView

/// The sections of the item view (Apple Passwords): a centred header (large tile, name, where the item belongs), the
/// type's fields, websites, notes, custom fields, attachments and the dates with the password history link. Every value
/// row copies on tap, secrets have an eye button; no section titles, no copy icons.
struct ViewItemDetailsView: View {
    // MARK: Private Properties

    /// Whether the second item in the collections list is focused. This is used alongside the Show more/less button.
    @AccessibilityFocusState private var isSecondCollectionFocused: Bool

    @Environment(\.openURL) private var openURL

    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ViewVaultItemState, ViewItemAction, ViewItemEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    // MARK: View

    var body: some View {
        itemHeaderSection

        itemInformationSection

        uriSection

        notesSection

        customFieldsSection

        attachmentsSection

        datesSection
    }

    // MARK: Private Views

    /// The attachments: one row per file, tap downloads.
    @ViewBuilder private var attachmentsSection: some View {
        if let attachments = store.state.attachments, !attachments.isEmpty {
            Section {
                ForEach(attachments) { attachment in
                    attachmentRow(attachment)
                }
            } header: {
                PassYSectionHeader(Localizations.attachments, count: attachments.count)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("AttachmentsList")
        }
    }

    /// The custom fields: text and hidden values copy on tap, hidden ones have an eye button.
    @ViewBuilder private var customFieldsSection: some View {
        if !store.state.customFieldsState.customFields.isEmpty {
            Section {
                ForEach(store.state.customFieldsState.customFields, id: \.self) { customField in
                    customFieldRow(customField)
                }
            }
        }
    }

    /// Where the item belongs: organization, collections, folder, archived (small lines under the name).
    @ViewBuilder private var itemHeaderAdditionalDetails: some View {
        VStack(spacing: PassYDesign.Spacing.xSmall) {
            if store.state.shouldDisplayNoFolder {
                belongingView(systemImage: "folder", name: Localizations.folderNone)
                    .accessibilityLabel(store.state.noFolderAccessibilityLabel)
            } else {
                if store.state.shouldDisplayAsArchived {
                    belongingView(systemImage: "archivebox", name: Localizations.archived)
                        .accessibilityLabel(Localizations.archived)
                }

                itemHeaderBelongingToSection

                if store.state.belongsToMultipleCollections {
                    Button(store.state.multipleCollectionsDisplayButtonTitle) {
                        Task { await store.perform(.toggleDisplayMultipleCollections) }
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
                    .accessibilityLabel(store.state.multipleCollectionsDisplayButtonTitle)
                    .accessibilityIdentifier("ToggleDisplayMultipleCollectionsButton")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The organization, the collections and the folder of the item.
    @ViewBuilder private var itemHeaderBelongingToSection: some View {
        if let organizationName = store.state.organizationName,
           let organizationAccessibilityLabel = store.state.organizationAccessibilityLabel {
            belongingView(systemImage: "building.2", name: organizationName)
                .accessibilityLabel(organizationAccessibilityLabel)
                .accessibilityHint(Localizations.itemXOfY(1, store.state.totalHeaderAdditionalItems))
        }

        ForEachIndexed(store.state.cipherCollectionsToDisplay) { index, collection in
            belongingView(systemImage: "square.stack", name: collection.name)
                .accessibilityLabel(store.state.collectionAccessibilityLabel(collection.name))
                .accessibilityHint(Localizations.itemXOfY(index + 2, store.state.totalHeaderAdditionalItems))
                .if(index == 1) { view in
                    view.accessibilityFocused($isSecondCollectionFocused)
                }
        }

        if store.state.shouldDisplayFolder,
           let folderName = store.state.folderName,
           let folderAccessibilityLabel = store.state.folderAccessibilityLabel {
            belongingView(systemImage: "folder", name: folderName)
                .accessibilityLabel(folderAccessibilityLabel)
                .accessibilityHint(
                    Localizations.itemXOfY(
                        store.state.totalHeaderAdditionalItems,
                        store.state.totalHeaderAdditionalItems,
                    ),
                )
        }
    }

    /// The large tile and the name, centred (Apple Passwords).
    private var itemHeaderMainDetails: some View {
        VStack(spacing: PassYDesign.Spacing.medium) {
            ViewItemHeaderTile(
                state: store.state,
                iconBaseURL: store.state.iconBaseURL,
                showWebIcons: store.state.showWebIcons,
            )
            .accessibilityHidden(true)

            Text(store.state.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(store.state.name)
                .accessibilityLabel(Localizations.itemNameX(store.state.name))
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
    }

    /// The header: tile, name and where the item belongs, on the page colour (no card).
    private var itemHeaderSection: some View {
        Section {
            VStack(spacing: PassYDesign.Spacing.small) {
                itemHeaderMainDetails
                itemHeaderAdditionalDetails
            }
            .padding(.vertical, PassYDesign.Spacing.small)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
        .onChange(of: store.state.isShowingMultipleCollections) { _, value in
            if value {
                isSecondCollectionFocused = true
            }
        }
    }

    /// The fields of the item's type.
    @ViewBuilder private var itemInformationSection: some View {
        switch store.state.type {
        case .bankAccount:
            ViewBankAccountItemView(
                store: store.child(
                    state: { _ in store.state.bankAccountItemState },
                    mapAction: { $0 },
                    mapEffect: nil,
                ),
            )
        case .driversLicense:
            ViewDriversLicenseItemView(
                store: store.child(
                    state: { _ in store.state.driversLicenseItemState },
                    mapAction: { $0 },
                    mapEffect: nil,
                ),
            )
        case .passport:
            ViewPassportItemView(
                store: store.child(
                    state: { _ in store.state.passportItemState },
                    mapAction: { $0 },
                    mapEffect: nil,
                ),
            )
        case .card:
            ViewCardItemView(
                store: store.child(
                    state: { _ in store.state.cardItemViewState },
                    mapAction: { $0 },
                    mapEffect: nil,
                ),
            )
        case .identity:
            ViewIdentityItemView(
                store: store.child(
                    state: { _ in store.state.identityState },
                    mapAction: { $0 },
                    mapEffect: nil,
                ),
            )
        case .login:
            ViewLoginItemView(
                store: store.child(
                    state: { _ in store.state.loginState },
                    mapAction: { $0 },
                    mapEffect: { $0 },
                ),
                timeProvider: timeProvider,
            )
        case .secureNote:
            EmptyView()
        case .sshKey:
            ViewSSHKeyItemView(
                showCopyButtons: true,
                store: store.child(
                    state: { _ in store.state.sshKeyState },
                    mapAction: { .sshKeyItemAction($0) },
                    mapEffect: nil,
                ),
            )
        }
    }

    /// The notes (stacked, tap copies).
    @ViewBuilder private var notesSection: some View {
        if !store.state.notes.isEmpty {
            let notes = store.state.notes
            Section {
                PassYCopyRow(Localizations.notes, value: notes, identifier: "CipherNotesLabel", layout: .stacked) {
                    store.send(.copyPressed(value: notes, field: .notes))
                }
            }
        }
    }

    /// Created and edited dates, the password's last change and the password history link.
    private var datesSection: some View {
        Section {
            if store.state.type == .login,
               let passwordHistoryCount = store.state.loginState.passwordHistoryCount, passwordHistoryCount > 0 {
                Button {
                    store.send(.passwordHistoryPressed)
                } label: {
                    HStack {
                        Text(Localizations.passwordHistory)
                            .foregroundStyle(.primary)
                        Spacer(minLength: PassYDesign.Spacing.small)
                        Text("\(passwordHistoryCount)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        PassYDisclosureChevron()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("PasswordHistoryButton")
            }
        } footer: {
            VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                Text(Localizations.created(store.state.cipher.creationDate.dateTimeDisplay))
                Text(Localizations.lastEdited(store.state.updatedDate.dateTimeDisplay))
                if store.state.type == .login, let passwordUpdatedDate = store.state.loginState.passwordUpdatedDate {
                    Text(Localizations.passwordLastUpdated(passwordUpdatedDate.dateTimeDisplay))
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The websites of a login: host shown, tap copies the full URI, the arrow opens it.
    @ViewBuilder private var uriSection: some View {
        if store.state.type == .login, !store.state.loginState.uris.isEmpty {
            Section {
                ForEach(store.state.loginState.uris, id: \.self) { uri in
                    PassYCopyRow(
                        Localizations.websiteURI,
                        value: URL(string: uri.uri)?.host ?? uri.uri,
                        identifier: "LoginUriEntry",
                    ) {
                        if let url = URL(string: uri.uri)?.sanitized, url.hasValidURLComponents {
                            PassYIconButton(Localizations.launch, systemImage: "arrow.up.forward.app") {
                                openURL(url)
                            }
                            .accessibilityIdentifier("LaunchUriButton")
                        }
                    } copy: {
                        store.send(.copyPressed(value: uri.uri, field: .uri))
                    }
                    .accessibilityIdentifier("UriRow")
                }
            }
        }
    }

    // MARK: Private methods

    /// An attachment: file name and size, tap downloads.
    private func attachmentRow(_ attachment: AttachmentView) -> some View {
        Button {
            store.send(.downloadAttachment(attachment))
        } label: {
            HStack(spacing: PassYDesign.Spacing.medium) {
                Image(systemName: "doc")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(attachment.fileName ?? "")
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: PassYDesign.Spacing.small)
                if let sizeName = attachment.sizeName {
                    Text(sizeName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel([attachment.fileName, attachment.sizeName].compactMap(\.self).joined(separator: ", "))
        .accessibilityHint(Localizations.download)
        .accessibilityIdentifier("CipherAttachment")
    }

    /// A line of where the item belongs: symbol and name.
    private func belongingView(systemImage: String, name: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PassYDesign.Spacing.xSmall + 2) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(name)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    /// A custom field row.
    @ViewBuilder
    private func customFieldRow(_ customField: CustomFieldState) -> some View {
        let name = customField.name ?? ""
        switch customField.type {
        case .boolean:
            LabeledContent(name) {
                Image(systemName: customField.booleanValue ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(customField.booleanValue ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .accessibilityLabel(customField.booleanValue ? Localizations.on : Localizations.off)
            }
            .frame(minHeight: 44)
        case .hidden:
            let value = customField.value ?? ""
            PassYCopyRow(
                name,
                value: value,
                secret: .init(
                    isRevealed: customField.isPasswordVisible,
                    revealIdentifier: "HiddenCustomFieldShowValueButton",
                ) {
                    store.send(.customFieldVisibilityPressed(customField))
                },
                identifier: "HiddenCustomFieldValue",
                copy: customField.value == nil ? nil : {
                    store.send(.copyPressed(value: value, field: .customHiddenField))
                },
            )
        case .text:
            let value = customField.value ?? ""
            PassYCopyRow(name, value: value, identifier: "TextCustomFieldValue") {
                store.send(.copyPressed(value: value, field: .customTextField))
            }
        case .linked:
            PassYCopyRow(
                name,
                value: customField.linkedIdType?.localizedName ?? "",
                accessory: {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                },
                copy: nil,
            )
        }
    }
}

// MARK: - ViewItemHeaderTile

/// The large tile of the item view: the website icon or the tinted letter for logins, the category symbol otherwise
/// (the same symbols and colours as the list rows).
private struct ViewItemHeaderTile: View {
    /// The item.
    let state: ViewVaultItemState

    /// The base URL of the website icons.
    let iconBaseURL: URL?

    /// Whether website icons are shown.
    let showWebIcons: Bool

    var body: some View {
        if state.type == .login {
            if showWebIcons, let iconBaseURL, let data = state.cipherDecorativeIconDataView,
               let url = IconImageHelper.getIconImage(for: data, from: iconBaseURL) {
                CipherIconAsyncImage(
                    url: url,
                    uiImageContent: { image in
                        // A dark logo on transparency gets a white tile (see `VaultItemIconTile`).
                        PassYIconTile(
                            style: image.passYIsDarkOnTransparency ? .light : .plain,
                            size: PassYDesign.IconSize.large,
                        ) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding(PassYDesign.Spacing.medium - 2)
                        }
                    },
                    placeholder: { PassYIconTile(letter: state.name, size: PassYDesign.IconSize.large) },
                )
            } else {
                PassYIconTile(letter: state.name, size: PassYDesign.IconSize.large)
            }
        } else {
            let group = VaultListGroup(tileFor: state.type)
            PassYIconTile(systemImage: group.tileSymbol, tint: group.tileColor, size: PassYDesign.IconSize.large)
        }
    }
}
