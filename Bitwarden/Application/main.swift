import UIKit
#if DEBUG
import BitwardenShared
#endif

/// Determine the app delegate class that should be used during this launch of the app. If the `TestingAppDelegate`
/// can be found, the app was launched in a test environment, and we should use the `TestingAppDelegate` for
/// handling all app lifecycle events.
private let appDelegateClass: AnyClass = NSClassFromString("BitwardenTests.TestingAppDelegate") ?? AppDelegate.self

#if DEBUG
// `PASSY_TRACKER=early`: mirror XCUITest's animation idle counter from the very first animation on (PassYAnimationDump);
// not in unit tests. The default (`late`) installs it in `AppProcessor.start`.
if NSClassFromString("BitwardenTests.TestingAppDelegate") == nil, PassYAnimationTracker.mode == "early" {
    PassYAnimationTracker.install()
}
#endif

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(appDelegateClass))
