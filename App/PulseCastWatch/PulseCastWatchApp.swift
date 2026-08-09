import SwiftUI

@main
struct PulseCastWatchApp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) private var extensionDelegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}
