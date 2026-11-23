import UIKit
#if DEBUG
import BitwardenShared
#endif

/// Determine the app delegate class that should be used during this launch of the app. If the `TestingAppDelegate`
/// can be found, the app was launched in a test environment, and we should use the `TestingAppDelegate` for
/// handling all app lifecycle events.
private let appDelegateClass: AnyClass = NSClassFromString("BitwardenTests.TestingAppDelegate") ?? AppDelegate.self

#if DEBUG
// Mirror XCUITest's animation idle counter from the very first animation on (PassYAnimationDump); not in unit tests.
if NSClassFromString("BitwardenTests.TestingAppDelegate") == nil { PassYAnimationTracker.install() }
#endif

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(appDelegateClass))
