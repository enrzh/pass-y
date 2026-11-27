import BitwardenKit
import BitwardenResources
import BitwardenSdk
import Foundation
import Testing

@testable import BitwardenShared

// MARK: - VaultMoveToFolderMenuTests

struct VaultMoveToFolderMenuTests {
    /// Editable, decrypted ciphers outside the trash can be moved.
    @Test
    func folderMoveCipher_movable() throws {
        let item = try #require(VaultListItem(cipherListView: .fixture(id: "1", folderId: "f1", edit: true)))
        #expect(item.folderMoveCipher?.folderId == "f1")
        let shared = try #require(VaultListItem(cipherListView: .fixture(id: "2", organizationId: "o", edit: true)))
        #expect(shared.folderMoveCipher != nil, "an organization item the user may edit")
    }

    /// Read-only (organization) items, items in the trash, decryption failures and group rows have no move.
    @Test
    func folderMoveCipher_notMovable() throws {
        let readOnly = try #require(VaultListItem(cipherListView: .fixture(id: "1", organizationId: "o", edit: false)))
        #expect(readOnly.folderMoveCipher == nil)
        let deleted = try #require(VaultListItem(cipherListView: .fixture(id: "2", edit: true, deletedDate: Date())))
        #expect(deleted.folderMoveCipher == nil)
        let failed = try #require(VaultListItem(cipherListView: .fixture(
            id: "3",
            name: Localizations.errorCannotDecrypt,
            edit: true,
        )))
        #expect(failed.folderMoveCipher == nil)
        let group = VaultListItem(id: "group", itemType: .group(.login, 1))
        #expect(group.folderMoveCipher == nil)
    }
}
