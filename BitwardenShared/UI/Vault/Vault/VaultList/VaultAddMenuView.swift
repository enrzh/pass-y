import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - VaultAddMenuView

/// The "new item" control for the bottom bar: a plus button that opens a tidy native menu with an SF Symbol
/// per item type and the folder entry.
///
struct VaultAddMenuView: View {
    // MARK: Properties

    /// Called when the user adds a folder.
    let addFolder: () -> Void

    /// Called with the chosen item type.
    let addItem: (CipherType) -> Void

    /// The item types the user can create.
    let availableItemTypes: [CipherType]

    // MARK: View

    var body: some View {
        Menu {
            ForEach(availableItemTypes, id: \.hashValue) { type in
                Button {
                    addItem(type)
                } label: {
                    Label(type.localizedName, systemImage: type.addMenuSymbol)
                }
            }
            Divider()
            Button(action: addFolder) {
                Label(Localizations.folder, systemImage: "folder")
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel(Localizations.add)
        .accessibilityIdentifier("AddItemFloatingActionButton")
    }

    // MARK: Initialization

    init(availableItemTypes: [CipherType], addItem: @escaping (CipherType) -> Void, addFolder: @escaping () -> Void) {
        self.addFolder = addFolder
        self.addItem = addItem
        self.availableItemTypes = availableItemTypes
    }
}

private extension CipherType {
    /// The SF Symbol used for this type in the add menu.
    var addMenuSymbol: String {
        switch self {
        case .login: "key"
        case .card: "creditcard"
        case .identity: "person.text.rectangle"
        case .secureNote: "note.text"
        case .sshKey: "terminal"
        case .bankAccount: "building.columns"
        case .driversLicense: "car"
        case .passport: "airplane"
        }
    }
}
