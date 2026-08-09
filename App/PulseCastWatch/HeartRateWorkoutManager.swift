import Foundation
import HealthKit

final class HeartRateWorkoutManager: NSObject, ObservableObject {
    private static let workoutType = HKObjectType.workoutType()
    private static let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
    private static let mirroringRetryInterval: TimeInterval = 5

    @Published private(set) var currentBPM: Int?
    @Published private(set) var isRunning = false {
        didSet {
            notifyStatusChange()
        }
    }
    @Published private(set) var statusText = "等待 HealthKit 授权" {
        didSet {
            notifyStatusChange()
        }
    }

    var onHeartRate: ((HeartRateSample) -> Void)?
    var onStatusChange: ((Bool, String) -> Void)?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var authorizationCompleted = false
    private var authorizationRequested = false
    private var authorizationInFlight = false
    private var isEndingWorkout = false
    private var shouldStartAfterAuthorization = false
    private var pendingWorkoutConfiguration: HKWorkoutConfiguration?
    private var mirroringStarted = false
    private var mirroringStartInFlight = false
    private var lastMirroringStartAttempt: Date?

    func requestAuthorization() {
        guard !authorizationCompleted, !authorizationInFlight else {
            return
        }

        authorizationRequested = true
        authorizationInFlight = true

        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = Self.heartRateType else {
            authorizationInFlight = false
            statusText = "当前手表无法读取心率"
            return
        }

        let typesToRead: Set<HKObjectType> = [heartRateType]
        let typesToShare: Set<HKSampleType> = [Self.workoutType]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.authorizationInFlight = false

                if let error {
                    self.statusText = "授权失败：\(error.localizedDescription)"
                    return
                }

                let authorized = success &&
                    self.healthStore.authorizationStatus(for: Self.workoutType) == .sharingAuthorized
                self.authorizationCompleted = authorized
                self.statusText = authorized ? "授权请求完成" : "未获得 HealthKit 授权"

                if authorized, self.shouldStartAfterAuthorization {
                    let configuration = self.pendingWorkoutConfiguration
                    self.shouldStartAfterAuthorization = false
                    self.pendingWorkoutConfiguration = nil
                    if let configuration {
                        self.startWorkout(configuration: configuration)
                    } else {
                        self.startWorkout()
                    }
                }
            }
        }
    }

    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor

        startWorkout(configuration: configuration)
    }

    func startWorkout(configuration: HKWorkoutConfiguration) {
        guard authorizationCompleted else {
            shouldStartAfterAuthorization = true
            pendingWorkoutConfiguration = configuration
            statusText = "需要 HealthKit 授权"
            requestAuthorization()
            return
        }

        guard !isRunning, session == nil, builder == nil else {
            return
        }

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()

            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            builder.delegate = self
            session.delegate = self

            self.session = session
            self.builder = builder
            isEndingWorkout = false
            statusText = "启动中"

            startMirroringIfNeeded(for: session)

            let startDate = Date()
            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { [weak self] success, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.resetFailedStart(status: "启动失败：\(error.localizedDescription)")
                    } else if success {
                        self?.isRunning = true
                        self?.statusText = "采集中"
                    } else {
                        self?.resetFailedStart(status: "未能开始采集")
                    }
                }
            }
        } catch {
            statusText = "启动失败：\(error.localizedDescription)"
        }
    }

    func sendHeartRateToCompanion(
        _ sample: HeartRateSample,
        fallback: @escaping () -> Void
    ) {
        guard let session else {
            fallback()
            return
        }

        guard mirroringStarted,
              let data = sample.workoutMirrorData else {
            startMirroringIfNeeded(for: session)
            fallback()
            return
        }

        session.sendToRemoteWorkoutSession(data: data) { [weak self] success, _ in
            guard !success else {
                return
            }

            DispatchQueue.main.async {
                guard let self, self.session === session else {
                    return
                }

                fallback()
            }
        }
    }

    func stopWorkout() {
        shouldStartAfterAuthorization = false
        pendingWorkoutConfiguration = nil

        guard session != nil || builder != nil else {
            isRunning = false
            statusText = "已停止"
            return
        }

        finishWorkoutCollection()
    }

    private func finishWorkoutCollection() {
        guard !isEndingWorkout else {
            return
        }

        isEndingWorkout = true
        isRunning = false
        statusText = "停止中"

        let endDate = Date()
        session?.end()

        guard let builder else {
            resetWorkoutObjects(status: "已停止")
            return
        }

        builder.endCollection(withEnd: endDate) { [weak self] _, error in
            builder.discardWorkout()

            DispatchQueue.main.async {
                if let error {
                    self?.resetWorkoutObjects(status: "停止失败：\(error.localizedDescription)")
                } else {
                    self?.resetWorkoutObjects(status: "已停止")
                }
            }
        }
    }

    private func startMirroringIfNeeded(for session: HKWorkoutSession) {
        guard self.session === session,
              !isEndingWorkout,
              !mirroringStarted,
              !mirroringStartInFlight else {
            return
        }

        let now = Date()
        if let lastMirroringStartAttempt,
           now.timeIntervalSince(lastMirroringStartAttempt) < Self.mirroringRetryInterval {
            return
        }

        lastMirroringStartAttempt = now
        mirroringStartInFlight = true

        session.startMirroringToCompanionDevice { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self, self.session === session else {
                    return
                }

                self.mirroringStartInFlight = false
                self.mirroringStarted = success
            }
        }
    }

    private func resetMirroringState() {
        mirroringStarted = false
        mirroringStartInFlight = false
        lastMirroringStartAttempt = nil
    }

    private func resetWorkoutObjects(status: String) {
        session = nil
        builder = nil
        isEndingWorkout = false
        resetMirroringState()
        statusText = status
    }

    private func resetFailedStart(status: String) {
        let failedSession = session
        session = nil
        builder = nil
        isEndingWorkout = false
        isRunning = false
        resetMirroringState()
        statusText = status
        failedSession?.end()
    }
}

extension HeartRateWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard let heartRateType = Self.heartRateType,
              collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity() else {
            return
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = Int(quantity.doubleValue(for: unit).rounded())
        let sample = HeartRateSample(bpm: bpm)

        DispatchQueue.main.async {
            self.currentBPM = sample.bpm
            self.statusText = "采集中"
            self.onHeartRate?(sample)
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension HeartRateWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            guard let session = self.session, workoutSession === session else {
                return
            }

            switch toState {
            case .running:
                self.isRunning = true
                self.statusText = "采集中"
            case .ended:
                self.isRunning = false
                if !self.isEndingWorkout {
                    self.finishWorkoutCollection()
                }
            case .paused:
                self.statusText = "已暂停"
            case .prepared:
                self.statusText = "准备中"
            case .notStarted:
                self.statusText = "未开始"
            case .stopped:
                self.isRunning = false
                self.statusText = "已停止"
            @unknown default:
                self.statusText = "未知 workout 状态"
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            guard let session = self.session, workoutSession === session else {
                return
            }

            self.isRunning = false
            self.statusText = "Workout 失败：\(error.localizedDescription)"
            self.resetWorkoutObjects(status: self.statusText)
        }
    }

    private func notifyStatusChange() {
        onStatusChange?(isRunning, statusText)
    }
}
