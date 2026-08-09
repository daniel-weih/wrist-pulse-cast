import HealthKit
import WatchKit

final class ExtensionDelegate: NSObject, WKExtensionDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        DispatchQueue.main.async {
            WatchRuntime.shared.handleWorkoutConfiguration(workoutConfiguration)
        }
    }
}
