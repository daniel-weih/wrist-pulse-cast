import Foundation
import HealthKit

final class WatchRuntime {
    static let shared = WatchRuntime()

    let workoutManager = HeartRateWorkoutManager()
    let connectivity = WatchConnectivityClient()

    private var isConfigured = false

    private init() {}

    func configure() {
        guard !isConfigured else {
            return
        }

        isConfigured = true
        connectivity.onHeartRateCollectionCommand = { [weak self] enabled in
            if enabled {
                self?.workoutManager.startWorkout()
            } else {
                self?.workoutManager.stopWorkout()
            }
        }
        workoutManager.onHeartRate = { [weak self] sample in
            guard let self else {
                return
            }

            self.workoutManager.sendHeartRateToCompanion(sample) { [weak self] in
                self?.connectivity.send(sample)
            }
        }
        workoutManager.onStatusChange = { [weak self] isRunning, statusText in
            self?.connectivity.sendCollectionStatus(
                isRunning: isRunning,
                statusText: statusText
            )
        }
        workoutManager.requestAuthorization()
        connectivity.activate()
    }

    func handleWorkoutConfiguration(_ configuration: HKWorkoutConfiguration) {
        configure()

        if connectivity.latestHeartRateCollectionRequest?.enabled == false {
            workoutManager.stopWorkout()
            return
        }

        workoutManager.startWorkout(configuration: configuration)
    }
}
