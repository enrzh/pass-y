import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ViewSendItemView

/// A view that allows the user to view the details of a send item.
///
struct ViewSendItemView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ViewSendItemState, ViewSendItemAction, ViewSendItemEffect>

    // MARK: View

    var body: some View {
        content
            .navigationTitle(store.state.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.perform(.loadData) }
            .task { await store.perform(.streamSend) }
            .toast(
                store.binding(
                    get: \.toast,
                    send: ViewSendItemAction.toastShown,
                ),
            )
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismiss)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !store.state.isDisabled {
                        editToolbarButton {
                            store.send(.editItem)
                        }
                    }
                }
            }
    }

    // MARK: Private Views

    /// The button to delete the send.
    private var deleteSendButton: some View {
        PassYInlineButtonRow(
            Localizations.deleteSend,
            systemImage: "trash",
            role: .destructive,
            identifier: "ViewSendDeleteButton",
        ) {
            await store.perform(.deleteSend)
        }
    }

    /// The main content: link, details, options, delete (a native `Form`, Apple Passwords look).
    @ViewBuilder private var content: some View {
        Form {
            restrictionBanner

            if !store.state.isDisabled {
                sendLink
            }

            sendDetailsSection

            additionalOptions

            Section { deleteSendButton }
        }
        .passYReadableWidth()
        .animation(.default, value: store.state.isAdditionalOptionsExpanded)
    }

    /// The access count and the private note behind "Additional options".
    @ViewBuilder private var additionalOptions: some View {
        if store.state.sendView.maxAccessCount != nil || store.state.sendView.notes?.isEmpty == false {
            PassYDisclosureSection(
                Localizations.additionalOptions,
                isExpanded: store.binding(
                    get: \.isAdditionalOptionsExpanded,
                    send: { _ in ViewSendItemAction.toggleAdditionalOptions },
                ),
                identifier: "SendShowHideOptionsButton",
            ) {
                Section {
                    if let maxAccessCount = store.state.sendView.maxAccessCount {
                        PassYCopyRow(
                            Localizations.maximumAccessCount,
                            value: "\(maxAccessCount)",
                            identifier: "SendMaxAccessCountEntry",
                            copy: nil,
                        )
                        PassYCopyRow(
                            Localizations.currentAccessCount,
                            value: "\(store.state.sendView.accessCount)",
                            identifier: "SendCurrentAccessCountEntry",
                            copy: nil,
                        )
                    }

                    if let notes = store.state.sendView.notes, !notes.isEmpty {
                        PassYCopyRow(Localizations.privateNote, value: notes, identifier: "ViewSendNotes", layout: .stacked) {
                            store.send(.copyNotes)
                        }
                    }
                }
            }
        }
    }

    /// Shown when this Send is disabled by a Send Controls policy: the reason and, if allowed, "Make a copy".
    @ViewBuilder private var restrictionBanner: some View {
        if store.state.isDisabled, let message = store.state.restrictionBannerMessage {
            Section {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
                    Label(Localizations.organizationPolicyRestriction, systemImage: "info.circle")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, PassYDesign.Spacing.xSmall)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ViewSendRestrictionBanner")

                if store.state.canMakeCopy {
                    PassYInlineButtonRow(Localizations.makeACopy, systemImage: "plus.square.on.square") {
                        store.send(.makeCopy)
                    }
                }
            }
        }
    }

    /// The send link: tap copies; Copy and Share rows.
    @ViewBuilder private var sendLink: some View {
        Section {
            if let displayShareURL = store.state.displayShareURL {
                PassYCopyRow(Localizations.sendLink, value: displayShareURL, identifier: "ViewSendShareLinkText", layout: .stacked) {
                    store.send(.copyShareURL)
                }
            }

            PassYInlineButtonRow(Localizations.copy, systemImage: "doc.on.doc", identifier: "ViewSendCopyButton") {
                store.send(.copyShareURL)
            }

            PassYInlineButtonRow(Localizations.share, systemImage: "square.and.arrow.up", identifier: "ViewSendShareButton") {
                store.send(.shareSend)
            }
        }
    }

    /// The name, the content (text or file) and the deletion date.
    @ViewBuilder private var sendDetailsSection: some View {
        Section {
            PassYCopyRow(Localizations.name, value: store.state.sendView.name, identifier: "ViewSendNameField", copy: nil)

            switch store.state.sendView.type {
            case .file:
                if let file = store.state.sendView.file {
                    LabeledContent {
                        if let fileSize = file.sizeName {
                            Text(fileSize)
                                .accessibilityIdentifier("ViewSendFileSizeText")
                        }
                    } label: {
                        Label(file.fileName, systemImage: "doc")
                            .accessibilityIdentifier("ViewSendFileNameText")
                    }
                    .frame(minHeight: 44)
                }
            case .text:
                if let text = store.state.sendView.text?.text {
                    PassYCopyRow(
                        Localizations.text,
                        value: text,
                        identifier: "ViewSendContentText",
                        layout: .stacked,
                        copy: nil,
                    )
                }
            // TODO: PM-41094 - Share: Implement Share panel and vault item menu integration.
            case .item:
                EmptyView()
            }

            PassYCopyRow(
                Localizations.deletionDate,
                value: store.state.sendView.deletionDate.dateTimeDisplay,
                identifier: "ViewSendDeletionDateField",
                copy: nil,
            )
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Text") {
    ViewSendItemView(store: Store(processor: StateProcessor(state: ViewSendItemState(
        sendView: .fixture(
            name: "My text send",
            text: .fixture(text: "Some text to send"),
        ),
        shareURL: URL(string: "https://send.bitwarden.com/39ngaol3"),
    ))))
    .navStackWrapped
}

#Preview("File") {
    ViewSendItemView(store: Store(processor: StateProcessor(state: ViewSendItemState(
        sendView: .fixture(type: .file, file: .fixture(fileName: "photo_123.jpg", sizeName: "3.25 MB")),
        shareURL: URL(string: "https://send.bitwarden.com/39ngaol3"),
    ))))
    .navStackWrapped
}
#endif
