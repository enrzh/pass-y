// MARK: - VaultItemManagementMenuAction

/// Actions that can be handled by an `AddEditItemProcessor` and  `ViewItemProcessor`.
enum VaultItemManagementMenuAction: Equatable {
    /// The attachments option was tapped.
    case attachments

    /// The clone option was tapped.
    case clone

    /// The collections option was tapped.
    case editCollections

    /// The move to organization option was tapped.
    case moveToOrganization

    /// A folder was chosen in "Move to folder" (`nil`: no folder).
    case moveToFolder(String?)

    /// "New folder…" was chosen in "Move to folder".
    case moveToNewFolder

    /// The restore option was tapped.
    case restore
}
