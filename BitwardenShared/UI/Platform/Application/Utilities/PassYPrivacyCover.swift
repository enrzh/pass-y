import Foundation

// MARK: - PassYPrivacyCover

/// Coordinates the privacy cover (the launch-screen colored splash window the scene shows while the app is not
/// active, so the app switcher never shows vault content) with Face ID / Touch ID unlock.
///
/// The system biometric prompt makes the scene resign active. Covering the screen there brings nothing: what is on
/// screen is the locked unlock page. But it cost a full cover plus its 0.4 s fade-out after the prompt, on top of
/// the unlock: the "black screen after Face ID" (dark mode: the cover is black). While a biometric unlock runs, the
/// scene therefore does not cover on `willResignActive`. It still covers on `didEnterBackground` (the app switcher
/// snapshot). If a failed or cancelled unlock ends while the scene is still inactive, `unlockEnded` covers right away.
///
/// A successful unlock that ends while the scene is still inactive does not cover (device timeline, iPhone Air, cold
/// start: the scene only becomes active once the system Face ID UI is gone, ~1.9 s after the vault was ready; the
/// cover over the finished vault was the black second). The vault the user just unlocked shows under the fading
/// system UI; the app switcher snapshot is still covered by `didEnterBackground`.
@MainActor
public enum PassYPrivacyCover {
    /// Whether a biometric unlock (its system prompt) is in progress.
    public private(set) static var isBiometricUnlockInProgress = false

    /// Called when a biometric unlock ended, with whether it succeeded (set by the scene).
    public static var unlockEnded: ((_ succeeded: Bool) -> Void)?

    /// Marks the start of a biometric unlock.
    static func beginBiometricUnlock() {
        isBiometricUnlockInProgress = true
    }

    /// Marks the end of a biometric unlock (`succeeded`: the vault is unlocked; otherwise cancel or failure).
    static func endBiometricUnlock(succeeded: Bool = false) {
        guard isBiometricUnlockInProgress else { return }
        isBiometricUnlockInProgress = false
        unlockEnded?(succeeded)
    }
}
