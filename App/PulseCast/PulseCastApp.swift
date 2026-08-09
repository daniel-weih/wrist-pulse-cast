import SwiftUI
import UIKit

final class PulseCastAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = AppModel.shared
        return true
    }
}

@main
struct PulseCastApp: App {
    @UIApplicationDelegateAdaptor(PulseCastAppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .onAppear {
                    appModel.start()
                }
        }
    }
}
