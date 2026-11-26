import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AddEditFolderView

/// A view that allows users to add a new folder or edit an existing one.
///
struct AddEditFolderView: View {
    // MARK: Properties

    /// The store that renders the view.
    @ObservedObject var store: Store<AddEditFolderState, AddEditFolderAction, AddEditFolderEffect>

    /// Whether the name field has the keyboard focus (set when a new folder opens).
    @FocusState private var focusedField: Bool?

    // MARK: View

    var body: some View {
        switch store.state.mode {
        case .add:
            addView
        case .edit:
            editView
        }
    }

    // MARK: Private views

    /// The view to add a new folder.
    private var addView: some View {
        content
            .navigationTitle(Localizations.addFolder)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismiss)
                }

                saveToolbarItem {
                    await store.perform(.saveTapped)
                }
            }
    }

    /// The view to edit an existing folder.
    private var editView: some View {
        content
            .navigationTitle(Localizations.editFolder)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismiss)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    saveToolbarButton {
                        await store.perform(.saveTapped)
                    }

                    optionsToolbarMenu {
                        AsyncButton(Localizations.delete, role: .destructive) {
                            await store.perform(.deleteTapped)
                        }
                    }
                }
            }
    }

    /// The content of the view in either mode: the name as a free field, focused for a new folder; Return saves.
    private var content: some View {
        Form {
            Section {
                nameEntryTextField
            }
        }
        .passYReadableWidth()
        .onAppear {
            if store.state.mode == .add { focusedField = true }
        }
    }

    /// The name entry text field.
    private var nameEntryTextField: some View {
        PassYFormField(
            Localizations.name,
            text: store.binding(
                get: \.folderName,
                send: AddEditFolderAction.folderNameTextChanged,
            ),
            style: .free,
            identifier: "FolderNameField",
            focus: .field($focusedField, equals: true),
        )
        .textInputAutocapitalization(.words)
        .submitLabel(.done)
        .onSubmit {
            Task { await store.perform(.saveTapped) }
        }
    }
}
