import Foundation
import WatchConnectivity

final class PhoneConnectivitySession: NSObject, ObservableObject {
    @Published private(set) var statusText = "未连接"
    @Published private(set) var lastReceivedAt: Date?

    var onHeartRate: ((HeartRateSample) -> Void)?

    private var session: WCSession?
    private var desiredHeartRateCollectionEnabled: Bool?
    private var desiredMaxHeartRate: Int?
    private var isWatchCollectionRunning = false
    private var hasReceivedHeartRate = false

    func activate() {
        guard WCSession.isSupported() else {
            statusText = "当前设备不支持 WatchConnectivity"
            return
        }

        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
        statusText = "正在连接手表"
    }

    func noteWatchLaunchRequested() {
        setStatusText("正在唤醒手表并启动采集", preservingActiveCollection: true)
    }

    func noteWatchLaunchSucceeded() {
        setStatusText("已请求系统唤醒手表，等待采集", preservingActiveCollection: true)
    }

    func noteWatchLaunchFailed(_ message: String) {
        setStatusText("唤醒失败：\(message)", preservingActiveCollection: true)
    }

    func setHeartRateCollectionEnabled(_ enabled: Bool, maxHeartRate: Int? = nil) {
        desiredHeartRateCollectionEnabled = enabled
        desiredMaxHeartRate = maxHeartRate
        if !enabled {
            isWatchCollectionRunning = false
            hasReceivedHeartRate = false
        }
        sendDesiredHeartRateCollectionState()
    }

    private func sendDesiredHeartRateCollectionState() {
        guard let enabled = desiredHeartRateCollectionEnabled else {
            return
        }

        guard let session else {
            setStatusText("正在连接手表", preservingActiveCollection: enabled)
            activate()
            return
        }

        guard session.activationState == .activated else {
            setStatusText("手表连接未激活", preservingActiveCollection: enabled)
            return
        }

        guard session.isWatchAppInstalled else {
            setStatusText("未安装手表应用", preservingActiveCollection: enabled)
            return
        }

        let payload = WatchControlCommand.payload(
            heartRateCollectionEnabled: enabled,
            maxHeartRate: desiredMaxHeartRate
        )

        do {
            try session.updateApplicationContext(payload)
        } catch {
            setStatusText("同步指令失败：\(error.localizedDescription)", preservingActiveCollection: enabled)
        }

        guard session.isReachable else {
            let message = enabled ? "已同步开始指令，正在唤醒手表" : "停止指令已同步"
            setStatusText(message, preservingActiveCollection: enabled)
            return
        }

        setStatusText(
            enabled ? "正在请求手表开始采集" : "正在请求手表停止采集",
            preservingActiveCollection: enabled
        )
        session.sendMessage(payload) { [weak self] reply in
            DispatchQueue.main.async {
                let accepted = WatchControlCommand.heartRateCollectionEnabled(from: reply) != nil
                guard accepted else {
                    self?.setStatusText("手表未识别采集指令", preservingActiveCollection: enabled)
                    return
                }

                self?.setStatusText(
                    enabled ? "手表已收到开始请求" : "手表已收到停止请求",
                    preservingActiveCollection: enabled
                )
            }
        } errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                let message: String
                if enabled {
                    message = "手表未实时响应，已同步开始指令：\(error.localizedDescription)"
                } else {
                    message = "手表未实时响应，停止指令已同步：\(error.localizedDescription)"
                }
                self?.setStatusText(message, preservingActiveCollection: enabled)
            }
        }
    }

    private func handlePayload(_ payload: [String: Any]) {
        if let status = WatchControlCommand.collectionStatus(from: payload) {
            DispatchQueue.main.async {
                self.isWatchCollectionRunning = status.isRunning
                self.statusText = status.isRunning ? "手表采集中" : status.statusText
            }
            return
        }

        guard let sample = HeartRateSample.fromPayload(payload) else {
            return
        }

        DispatchQueue.main.async {
            self.isWatchCollectionRunning = true
            self.hasReceivedHeartRate = true
            self.lastReceivedAt = Date()
            self.statusText = "已收到手表心率"
            self.onHeartRate?(sample)
        }
    }

    private func setStatusText(_ message: String, preservingActiveCollection: Bool = false) {
        if preservingActiveCollection,
           desiredHeartRateCollectionEnabled == true,
           (isWatchCollectionRunning || hasReceivedHeartRate) {
            return
        }

        statusText = message
    }
}

extension PhoneConnectivitySession: WCSessionDelegate {
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
                self.statusText = session.isWatchAppInstalled ? "手表已连接" : "未安装手表应用"
                self.sendDesiredHeartRateCollectionState()
            case .inactive:
                self.statusText = "手表连接未激活"
            case .notActivated:
                self.statusText = "手表未连接"
            @unknown default:
                self.statusText = "未知手表状态"
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.statusText = "手表连接暂停"
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        DispatchQueue.main.async {
            self.statusText = "正在重新连接手表"
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.statusText = session.isWatchAppInstalled ? "手表已连接" : "未安装手表应用"
            self.sendDesiredHeartRateCollectionState()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handlePayload(message)
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handlePayload(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handlePayload(userInfo)
    }
}
