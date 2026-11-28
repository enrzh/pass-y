import SwiftUI

@main
struct BitwardenWatchAp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var delegate

    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                CipherListView()
            }
        }
    }
}
