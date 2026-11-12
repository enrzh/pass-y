import Foundation

/// App-wide commands triggered from the menu bar / keyboard shortcuts (iPad hardware keyboard, Mac).
/// The menu (in the app target) only posts these notifications; processors that can handle a command observe them.
public extension Notification.Name {
    /// Create a new login (Cmd+N).
    static let passyNewLogin = Notification.Name("de.aiity.passy.command.newLogin")

    /// Lock the vault (Cmd+L).
    static let passyLockVault = Notification.Name("de.aiity.passy.command.lockVault")

    /// Copy the password of the item that is currently displayed (Cmd+Shift+C).
    static let passyCopyPassword = Notification.Name("de.aiity.passy.command.copyPassword")

    /// Copy the verification (TOTP) code of the item that is currently displayed (Cmd+Option+C).
    static let passyCopyCode = Notification.Name("de.aiity.passy.command.copyCode")
}
