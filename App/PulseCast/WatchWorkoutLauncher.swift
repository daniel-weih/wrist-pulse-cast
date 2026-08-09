import Foundation
import HealthKit

final class WatchWorkoutLauncher {
    private static let workoutType = HKObjectType.workoutType()

    private let healthStore = HKHealthStore()

    func startCyclingWorkout(completion: @escaping (Result<Void, Error>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.failure(LauncherError.healthDataUnavailable))
            return
        }

        requestWorkoutAuthorizationIfNeeded { [self] result in
            switch result {
            case .success:
                startWatchCyclingWorkout(completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func requestWorkoutAuthorizationIfNeeded(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        switch healthStore.authorizationStatus(for: Self.workoutType) {
        case .sharingAuthorized:
            completion(.success(()))
        case .sharingDenied:
            completion(.failure(LauncherError.healthAuthorizationDenied))
        case .notDetermined:
            let typesToShare: Set<HKSampleType> = [Self.workoutType]
            healthStore.requestAuthorization(toShare: typesToShare, read: nil) { [weak self] success, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard success,
                      self?.healthStore.authorizationStatus(for: Self.workoutType) == .sharingAuthorized else {
                    completion(.failure(LauncherError.healthAuthorizationDenied))
                    return
                }

                completion(.success(()))
            }
        @unknown default:
            completion(.failure(LauncherError.healthAuthorizationDenied))
        }
    }

    private func startWatchCyclingWorkout(completion: @escaping (Result<Void, Error>) -> Void) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor

        healthStore.startWatchApp(with: configuration) { success, error in
            if let error {
                completion(.failure(error))
            } else if success {
                completion(.success(()))
            } else {
                completion(.failure(LauncherError.launchRejected))
            }
        }
    }

    private enum LauncherError: LocalizedError {
        case healthDataUnavailable
        case healthAuthorizationDenied
        case launchRejected

        var errorDescription: String? {
            switch self {
            case .healthDataUnavailable:
                return "当前设备无法使用 HealthKit"
            case .healthAuthorizationDenied:
                return "未获得 iPhone HealthKit workout 授权，无法唤醒 Apple Watch"
            case .launchRejected:
                return "系统未能唤醒 Apple Watch App"
            }
        }
    }
}
