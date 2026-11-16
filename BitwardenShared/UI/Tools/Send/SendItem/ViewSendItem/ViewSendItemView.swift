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
            .navigationBar(title: store.state.navigationTitle, titleDisplayMode: .inline)
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
        AsyncButton {
            await store.perform(.deleteSend)
        } label: {
            Label(Localizations.deleteSend, image: SharedAsset.Icons.trash16.swiftUIImage, scaleImageDimension: 16)
        }
        .foregroundStyle(SharedAsset.Colors.error.swiftUIColor)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("ViewSendDeleteButton")
    }

    /// The main content of the view.
    @ViewBuilder private var content: some View {
        // Native `Form` (Apple Passwords look).
        Form {
            restrictionBanner

            if !store.state.isDisabled {
                sendLink
            }

            sendDetailsSection

            additionalOptions

            Section { deleteSendButton }
        }
        .nativeFormRows()
        .readOnlyFieldStyle()
        .animation(.default, value: store.state.isAdditionalOptionsExpanded)
    }

    /// The expandable additional options section.
    @ViewBuilder private var additionalOptions: some View {
        if store.state.sendView.maxAccessCount != nil || store.state.sendView.notes?.isEmpty == false {
            ExpandableContent(
                title: Localizations.additionalOptions,
                isExpanded: store.binding(
                    get: \.isAdditionalOptionsExpanded,
                    send: { _ in ViewSendItemAction.toggleAdditionalOptions },
                ),
                buttonAccessibilityIdentifier: "SendShowHideOptionsButton",
            ) {
                if let maxAccessCount = store.state.sendView.maxAccessCount {
                    Section {
                        SendItemAccessCountStepper(
                            currentAccessCount: Int(store.state.sendView.accessCount),
                            displayInfoText: false,
                            maximumAccessCount: .constant(Int(maxAccessCount)),
                        )
                        .disabled(true)
                    }
                }

                if let notes = store.state.sendView.notes, !notes.isEmpty {
                    Section {
                    BitwardenTextValueField(
                        title: Localizations.privateNote,
                        value: notes,
                        useUIKitTextView: true,
                        copyButtonAccessibilityIdentifier: "CopyNotesButton",
                        copyButtonAction: {
                            store.send(.copyNotes)
                        },
                    )
                    .accessibilityIdentifier("ViewSendNotes")
                    }
                }
            }
        }
    }

    /// The banner shown when this Send is disabled due to a Send Controls policy violation.
    @ViewBuilder private var restrictionBanner: some View {
        if store.state.isDisabled, let message = store.state.restrictionBannerMessage {
            ActionCard(
                title: Localizations.organizationPolicyRestriction,
                message: message,
                actionButtonState: store.state.canMakeCopy
                    ? ActionCard.ButtonState(title: Localizations.makeACopy) {
                        store.send(.makeCopy)
                    }
                    : nil,
            ) {
                SharedAsset.Icons.informationCircle24.swiftUIImage
                    .foregroundStyle(SharedAsset.Colors.iconSecondary.swiftUIColor)
            }
            .accessibilityIdentifier("ViewSendRestrictionBanner")
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    /// The send link with copy and share rows.
    @ViewBuilder private var sendLink: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(Localizations.sendLink)
                    .font(.headline)

                if let displayShareURL = store.state.displayShareURL {
                    Text(displayShareURL)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("ViewSendShareLinkText")
                }
            }

            Button {
                store.send(.copyShareURL)
            } label: {
                Label(Localizations.copy, systemImage: "doc.on.doc")
            }
            .accessibilityIdentifier("ViewSendCopyButton")

            Button {
                store.send(.shareSend)
            } label: {
                Label(Localizations.share, systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("ViewSendShareButton")
        }
    }

    /// The send details section, containing the send's name, content, and deletion date.
    @ViewBuilder private var sendDetailsSection: some View {
        SectionView(Localizations.sendDetails, contentSpacing: 8) {
            BitwardenTextValueField(
                title: Localizations.sendNameRequired,
                value: store.state.sendView.name,
                valueAccessibilityIdentifier: "ViewSendNameField",
            )

            switch store.state.sendView.type {
            case .file:
                if let file = store.state.sendView.file {
                    BitwardenField {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(file.fileName)
                                .styleGuide(.body)
                                .foregroundStyle(SharedAsset.Colors.textPrimary.swiftUIColor)
                                .accessibilityIdentifier("ViewSendFileNameText")

                            if let fileSize = file.sizeName {
                                Text(fileSize)
                                    .styleGuide(.footnote)
                                    .foregroundStyle(SharedAsset.Colors.textSecondary.swiftUIColor)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .multilineTextAlignment(.trailing)
                                    .accessibilityIdentifier("ViewSendFileSizeText")
                            }
                        }
                    }
                }
            case .text:
                if let text = store.state.sendView.text?.text {
                    BitwardenTextValueField(
                        title: Localizations.textToShareRequired,
                        value: text,
                        valueAccessibilityIdentifier: "ViewSendContentText",
                    )
                }
            // TODO: PM-41094 - Share: Implement Share panel and vault item menu integration.
            case .item:
                EmptyView()
            }

            BitwardenTextValueField(
                title: Localizations.deletionDate,
                value: store.state.sendView.deletionDate.dateTimeDisplay,
                valueAccessibilityIdentifier: "ViewSendDeletionDateField",
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
