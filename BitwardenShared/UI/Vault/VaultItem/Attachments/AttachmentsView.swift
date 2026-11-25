import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - AttachmentsView

/// A view that allows the user to view and edit attachments.
///
struct AttachmentsView: View {
    // MARK: Properties

    /// An environment variable used to open URLs.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: Store<AttachmentsState, AttachmentsAction, AttachmentsEffect>

    // MARK: View

    var body: some View {
        Form {
            currentAttachments

            addAttachmentView
        }
        .passYReadableWidth()
        .navigationTitle(Localizations.attachments)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismissPressed)
            }

            saveToolbarItem {
                await store.perform(.save)
            }
        }
        .task {
            await store.perform(.loadPremiumStatus)
        }
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearURL)
        }
        .toast(store.binding(
            get: \.toast,
            send: AttachmentsAction.toastShown,
        ))
    }

    // MARK: Private Views

    /// The file to add: the chosen file name and the "Choose file" row, the size limit as the footer.
    private var addAttachmentView: some View {
        Section {
            if let fileName = store.state.fileName {
                Label(fileName, systemImage: "doc")
                    .foregroundStyle(.primary)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("ChosenFileLabel")
            }

            PassYInlineButtonRow(
                Localizations.chooseFile,
                systemImage: "paperclip",
                identifier: "ChooseFileButton",
            ) {
                store.send(.chooseFilePressed)
            }
        } header: {
            PassYSectionHeader(Localizations.addNewAttachment)
        } footer: {
            PassYSectionFooter(Localizations.maxFileSize)
        }
    }

    /// The current attachments, or a note that there are none.
    @ViewBuilder private var currentAttachments: some View {
        if let attachments = store.state.cipher?.attachments, !attachments.isEmpty {
            Section {
                ForEach(attachments) { attachment in
                    attachmentRow(attachment)
                }
            } header: {
                PassYSectionHeader(Localizations.attachments, count: attachments.count)
            }
        } else {
            Section {
                Text(Localizations.noAttachments)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("NoAttachmentsLabel")
            }
        }
    }

    /// An existing attachment: name, size and a delete button (also on swipe).
    private func attachmentRow(_ attachment: AttachmentView) -> some View {
        HStack(spacing: PassYDesign.Spacing.medium) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(attachment.fileName ?? "")
                .lineLimit(2)
            Spacer(minLength: PassYDesign.Spacing.small)
            if let sizeName = attachment.sizeName {
                Text(sizeName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button(Localizations.delete, systemImage: "trash") {
                store.send(.deletePressed(attachment))
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(.red)
            .buttonStyle(.borderless)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("AttachmentRow")
        .swipeActions {
            Button(Localizations.delete, systemImage: "trash", role: .destructive) {
                store.send(.deletePressed(attachment))
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty Attachments") {
    NavigationView {
        AttachmentsView(store: Store(processor: StateProcessor(state: AttachmentsState())))
    }
}

#Preview("Attachment Selected") {
    NavigationView {
        AttachmentsView(store: Store(processor: StateProcessor(
            state: AttachmentsState(
                fileName: "photo.jpg",
            ),
        )))
    }
}

#Preview("Existing Attachments") {
    NavigationView {
        AttachmentsView(
            store: Store(
                processor: StateProcessor(
                    state: AttachmentsState(
                        cipher: .fixture(
                            attachments: [
                                .fixture(
                                    fileName: "selfieWithACat.png",
                                    id: "1",
                                    sizeName: "10 MB",
                                ),
                                .fixture(
                                    fileName: "selfieWithADog.png",
                                    id: "2",
                                    sizeName: "11.2 MB",
                                ),
                                .fixture(
                                    fileName: "selfieWithAPotato.png",
                                    id: "3",
                                    sizeName: "201.2 MB",
                                ),
                            ],
                        ),
                    ),
                ),
            ),
        )
    }
}
#endif
