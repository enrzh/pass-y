// MARK: - VaultListItemRowEffect

/// Effects that can be performed from a `VaultListItemRowView`.
enum VaultListItemRowEffect: Equatable {
    /// One of the more-options actions was chosen (context menu, swipe menu or VoiceOver custom action).
    case accessibilityMoreOptionsActionPressed(MoreOptionsActionKind)

    /// The row was pressed to open the item.
    case pressed
}
