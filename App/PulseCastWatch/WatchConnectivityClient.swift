import Foundation
import WatchConnectivity

final class WatchConnectivityClient: NSObject, ObservableObject {
    @Published private(set) var statusText = "等待 iPhone"
    @Published private(set) var maxHeartRate = 190
    private(set) var latestHeartRateCollectionRequest: WatchControlCommand.CollectionRequest?

    var onHeartRateCollectionCommand: ((Bool) -> Void)?

    private var session: WCSession?

    func activate() {
        guard WCSession.isSupported() else {
            statusText = "当前设备不支持连接 iPhone"
            return
        }

        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
        statusText = "正在连接 iPhone"
    }

    func send(_ sample: HeartRateSample) {
        guard let session, session.activationState == .activated else {
            statusText = "iPhone 未连接"
            return
        }

        let payload = sample.payload

        do {
            try session.updateApplicationContext(payload)
        } catch {
            DispatchQueue.main.async {
                self.statusText = "发送失败：\(error.localizedDescription)"
            }
        }

        guard session.isReachable else {
            DispatchQueue.main.async {
                self.statusText = "等待 iPhone 前台"
            }
            return
        }

        session.sendMessage(payload, replyHandler: nil) { [weak self] error in
            DispatchQueue.main.async {
                self?.statusText = "发送失败：\(error.localizedDescription)"
            }
        }

        statusText = "已发送"
    }

    func sendCollectionStatus(isRunning: Bool, statusText: String) {
        guard let session, session.activationState == .activated else {
            return
        }

        let payload = WatchControlCommand.statusPayload(
            isRunning: isRunning,
            statusText: statusText
        )

        do {
            try session.updateApplicationContext(payload)
        } catch {
            return
        }

        guard session.isReachable else {
            return
        }

        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    @discardableResult
    private func handleCommand(_ payload: [String: Any]) -> Bool {
        guard let request = WatchControlCommand.collectionRequest(from: payload) else {
            return false
        }

        let applyCommand = {
            self.latestHeartRateCollectionRequest = request
            if let maxHeartRate = request.maxHeartRate {
                self.maxHeartRate = maxHeartRate
            }
            self.statusText = request.enabled ? "iPhone 请求开始采集" : "iPhone 请求停止采集"
            self.onHeartRateCollectionCommand?(request.enabled)
        }

        if Thread.isMainThread {
            applyCommand()
        } else {
            DispatchQueue.main.async(execute: applyCommand)
        }

        return true
    }
}

extension WatchConnectivityClient: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error {
                self.statusText = "连接失败：\(error.localizedDescription)"
                return
            }

            switch activationState {
            case .activated:
                self.statusText = "iPhone 已连接"
                self.handleCommand(session.receivedApplicationContext)
            case .inactive:
                self.statusText = "iPhone 连接未激活"
            case .notActivated:
                self.statusText = "iPhone 未连接"
            @unknown default:
                self.statusText = "未知连接状态"
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleCommand(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let accepted = handleCommand(message)
        if let enabled = WatchControlCommand.heartRateCollectionEnabled(from: message), accepted {
            replyHandler(WatchControlCommand.payload(heartRateCollectionEnabled: enabled))
        } else {
            replyHandler(["accepted": false])
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handleCommand(applicationContext)
    }
}
