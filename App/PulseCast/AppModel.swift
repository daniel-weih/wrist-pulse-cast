import Combine
import Foundation
import HealthKit

final class AppModel: ObservableObject {
    static let shared = AppModel()

    private static let broadcastingRequestedKey = "PulseCast.isBroadcastingRequested"

    let bluetooth = BLEHeartRatePeripheral()
    let healthProfile = HealthProfileStore()
    let watchSession = PhoneConnectivitySession()
    private let watchWorkoutLauncher = WatchWorkoutLauncher()
    private let workoutMirror = WorkoutMirrorReceiver.shared

    @Published private(set) var latestSample: HeartRateSample?
    @Published private(set) var isBroadcastingRequested: Bool

    private var cancellables = Set<AnyCancellable>()
    private var didStart = false

    private init() {
        isBroadcastingRequested = UserDefaults.standard.bool(forKey: Self.broadcastingRequestedKey)

        workoutMirror.setHandlers(
            onSessionStarted: { [weak self] in
                DispatchQueue.main.async {
                    self?.mirroredWorkoutStarted()
                }
            },
            onHeartRate: { [weak self] sample in
                DispatchQueue.main.async {
                    self?.receive(sample)
                }
            }
        )
        workoutMirror.activate()

        bluetooth.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        watchSession.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        healthProfile.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        healthProfile.$age
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isBroadcastingRequested else {
                    return
                }

                self.watchSession.setHeartRateCollectionEnabled(
                    true,
                    maxHeartRate: self.currentMaxHeartRate
                )
            }
            .store(in: &cancellables)

        watchSession.onHeartRate = { [weak self] sample in
            DispatchQueue.main.async {
                self?.receive(sample)
            }
        }
    }

    func start() {
        guard !didStart else {
            return
        }

        didStart = true
        watchSession.activate()
        healthProfile.requestAgeAuthorization()

        if isBroadcastingRequested, workoutMirror.hasActiveSession {
            watchSession.setHeartRateCollectionEnabled(true, maxHeartRate: currentMaxHeartRate)
            bluetooth.setAdvertising(true)
        } else if isBroadcastingRequested {
            startBroadcasting()
        }
    }

    func setBroadcasting(_ enabled: Bool) {
        isBroadcastingRequested = enabled
        UserDefaults.standard.set(enabled, forKey: Self.broadcastingRequestedKey)

        if enabled {
            startBroadcasting()
        } else {
            watchSession.setHeartRateCollectionEnabled(false)
            bluetooth.setAdvertising(false)
        }
    }

    func appBecameActive() {
        guard isBroadcastingRequested else {
            return
        }

        bluetooth.refreshAdvertising()
    }

    private func startBroadcasting() {
        watchSession.setHeartRateCollectionEnabled(true, maxHeartRate: currentMaxHeartRate)
        bluetooth.setAdvertising(true)

        watchSession.noteWatchLaunchRequested()
        watchWorkoutLauncher.startCyclingWorkout { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.watchSession.noteWatchLaunchSucceeded()
                case .failure(let error):
                    self?.watchSession.noteWatchLaunchFailed(error.localizedDescription)
                }
            }
        }
    }

    private func mirroredWorkoutStarted() {
        watchSession.activate()

        guard isBroadcastingRequested else {
            return
        }

        bluetooth.setAdvertising(true)
    }

    private func receive(_ sample: HeartRateSample) {
        if let latestSample, sample.date <= latestSample.date {
            return
        }

        latestSample = sample
        bluetooth.updateHeartRate(sample.bpm)

        if isBroadcastingRequested, !bluetooth.isAdvertisingRequested {
            bluetooth.setAdvertising(true)
            bluetooth.updateHeartRate(sample.bpm)
        }
    }

    var broadcastStatusText: String {
        guard isBroadcastingRequested else {
            return "广播未开启"
        }

        return bluetooth.state.label
    }

    var isWaitingForHeartRateBeforeBroadcast: Bool {
        false
    }

    private var currentMaxHeartRate: Int? {
        guard let age = healthProfile.age,
              age > 0,
              age < 130 else {
            return nil
        }

        return 220 - age
    }
}

final class WorkoutMirrorReceiver: NSObject {
    static let shared = WorkoutMirrorReceiver()

    private let healthStore = HKHealthStore()
    private let stateLock = NSLock()
    private var isActivated = false
    private var mirroredSession: HKWorkoutSession?
    private var sessionStartedHandler: (() -> Void)?
    private var heartRateHandler: ((HeartRateSample) -> Void)?
    private var latestSample: HeartRateSample?

    var hasActiveSession: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return mirroredSession != nil
    }

    private override init() {
        super.init()
    }

    func setHandlers(
        onSessionStarted: @escaping () -> Void,
        onHeartRate: @escaping (HeartRateSample) -> Void
    ) {
        stateLock.lock()
        sessionStartedHandler = onSessionStarted
        heartRateHandler = onHeartRate
        let pendingSample = latestSample
        stateLock.unlock()

        if let pendingSample {
            onHeartRate(pendingSample)
        }
    }

    func activate() {
        stateLock.lock()
        guard !isActivated else {
            stateLock.unlock()
            return
        }

        isActivated = true
        stateLock.unlock()

        healthStore.workoutSessionMirroringStartHandler = { [weak self] session in
            self?.accept(session)
        }
    }

    private func accept(_ session: HKWorkoutSession) {
        session.delegate = self

        stateLock.lock()
        mirroredSession = session
        let handler = sessionStartedHandler
        stateLock.unlock()

        handler?()
    }

    private func emit(_ sample: HeartRateSample) {
        stateLock.lock()
        if let latestSample, sample.date <= latestSample.date {
            stateLock.unlock()
            return
        }

        latestSample = sample
        let handler = heartRateHandler
        stateLock.unlock()

        handler?(sample)
    }

    private func clear(_ session: HKWorkoutSession) {
        stateLock.lock()
        if mirroredSession === session {
            mirroredSession = nil
        }
        stateLock.unlock()
    }
}

extension WorkoutMirrorReceiver: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        if toState == .ended || toState == .stopped {
            clear(workoutSession)
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        clear(workoutSession)
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        data
            .compactMap(HeartRateSample.fromWorkoutMirrorData)
            .sorted { $0.date < $1.date }
            .forEach(emit)
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        clear(workoutSession)
    }
}
