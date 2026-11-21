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
                    Label(type.localizedName, systemImage: type.passYAddMenuSymbol)
                }
            }
            Divider()
            Button(action: addFolder) {
                Label(Localizations.folder, systemImage: "folder")
            }
        } label: {
            // The whole 44 pt circle is the tap target (the symbol alone is only ~18 pt, taps fell through to the list).
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
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

extension CipherType {
    /// The SF Symbol used for this type in the add menu.
    var passYAddMenuSymbol: String {
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

extension Array where Element == CipherType {
    /// The types in the order the bottom "+" menu lists them, nearest to the button first: Login, Card, Identity,
    /// Secure note, then the new types. The system menu opens upwards, so with accessibility text sizes the far end is
    /// cut off and scrolls; the most used types must be the ones that stay reachable.
    var passYAddMenuOrdered: [CipherType] {
        let priority: [CipherType] = [.login, .card, .identity, .secureNote, .bankAccount, .driversLicense, .passport, .sshKey]
        return sorted { (priority.firstIndex(of: $0) ?? 99) < (priority.firstIndex(of: $1) ?? 99) }
    }
}
