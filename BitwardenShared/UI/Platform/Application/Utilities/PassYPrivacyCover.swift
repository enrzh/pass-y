import Foundation

// MARK: - PassYPrivacyCover

/// Coordinates the privacy cover (the launch-screen colored splash window the scene shows while the app is not
/// active, so the app switcher never shows vault content) with Face ID / Touch ID unlock.
///
/// The system biometric prompt makes the scene resign active. Covering the screen there brings nothing: what is on
/// screen is the locked unlock page. But it cost a full cover plus its 0.4 s fade-out after the prompt, on top of
/// the unlock: the "black screen after Face ID" (dark mode: the cover is black). While a biometric unlock runs, the
/// scene therefore does not cover on `willResignActive`. It still covers on `didEnterBackground` (the app switcher
/// snapshot), and if the unlock ends while the scene is still inactive, `unlockEnded` covers right away, before any
/// vault content can show.
@MainActor
public enum PassYPrivacyCover {
    /// Whether a biometric unlock (its system prompt) is in progress.
    public private(set) static var isBiometricUnlockInProgress = false

    /// Called when a biometric unlock ended (set by the scene; covers if the scene is still inactive).
    public static var unlockEnded: (() -> Void)?

    /// Marks the start of a biometric unlock.
    static func beginBiometricUnlock() {
        isBiometricUnlockInProgress = true
    }

    /// Marks the end of a biometric unlock (success, cancel or failure).
    static func endBiometricUnlock() {
        guard isBiometricUnlockInProgress else { return }
        isBiometricUnlockInProgress = false
        unlockEnded?()
    }
}
