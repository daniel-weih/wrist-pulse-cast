import CoreBluetooth
import Foundation
import OSLog

final class BLEHeartRatePeripheral: NSObject, ObservableObject {
    enum PeripheralState: Equatable {
        case idle
        case preparing
        case advertising
        case connected(Int)
        case poweredOff
        case unauthorized
        case unsupported
        case resetting
        case error(String)

        var label: String {
            switch self {
            case .idle:
                return "未广播"
            case .preparing:
                return "准备中"
            case .advertising:
                return "正在广播"
            case .connected(let count):
                return count > 1 ? "已连接 \(count) 个设备" : "已连接码表"
            case .poweredOff:
                return "蓝牙未开启"
            case .unauthorized:
                return "缺少蓝牙权限"
            case .unsupported:
                return "设备不支持 BLE Peripheral"
            case .resetting:
                return "蓝牙重置中"
            case .error(let message):
                return message
            }
        }
    }

    private static let heartRateServiceUUID = CBUUID(string: "180D")
    private static let heartRateMeasurementUUID = CBUUID(string: "2A37")
    private static let bodySensorLocationUUID = CBUUID(string: "2A38")
    private static let advertisedName = "PulseCast HR"
    private static let logger = Logger(subsystem: "com.hongwei.wrist-pulse-cast", category: "BLE")

    @Published private(set) var state: PeripheralState = .idle
    @Published private(set) var isAdvertisingRequested = false
    @Published private(set) var latestBroadcastBPM: Int?
    @Published private(set) var diagnosticText = "等待蓝牙"

    var advertisedName: String {
        Self.advertisedName
    }

    private var peripheralManager: CBPeripheralManager!
    private var measurementCharacteristic: CBMutableCharacteristic?
    private var serviceConfigured = false
    private var serviceAddInFlight = false
    private var subscribedCentralIDs = Set<UUID>()
    private var pendingMeasurement: Data?
    private var measurementRepeatTimer: Timer?
    private var idleAdvertisingRefreshTimer: Timer?
    private var pendingAdvertisingRestart: DispatchWorkItem?

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [CBPeripheralManagerOptionShowPowerAlertKey: true]
        )
    }

    func setAdvertising(_ enabled: Bool) {
        isAdvertisingRequested = enabled
        Self.logger.info("setAdvertising requested=\(enabled, privacy: .public)")
        diagnosticText = enabled ? "请求开始广播" : "已停止广播"

        if enabled {
            if latestBroadcastBPM == nil {
                latestBroadcastBPM = 72
                pendingMeasurement = HeartRateMeasurement.data(for: 72)
            }
            startAdvertising()
            startMeasurementRepeatTimer()
        } else {
            stopAdvertising()
        }
    }

    func updateHeartRate(_ bpm: Int) {
        latestBroadcastBPM = bpm
        Self.logger.debug("updateHeartRate bpm=\(bpm, privacy: .public)")
        notifyHeartRate(HeartRateMeasurement.data(for: bpm))
    }

    func refreshAdvertising() {
        restartAdvertisingForReconnect(
            reason: "app requested refresh",
            diagnostic: "刷新蓝牙广播"
        )
    }

    private func startAdvertising() {
        Self.logger.info("startAdvertising managerState=\(String(describing: self.peripheralManager.state), privacy: .public) configured=\(self.serviceConfigured, privacy: .public) isAdvertising=\(self.peripheralManager.isAdvertising, privacy: .public)")
        diagnosticText = "准备广播"
        guard peripheralManager.state == .poweredOn else {
            updateStateForBluetoothPower()
            return
        }

        guard serviceConfigured else {
            configureHeartRateService()
            return
        }

        guard !peripheralManager.isAdvertising else {
            updateRunningState()
            return
        }

        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.heartRateServiceUUID],
            CBAdvertisementDataLocalNameKey: Self.advertisedName
        ])
        updateRunningState()
    }

    private func stopAdvertising() {
        cancelPendingAdvertisingRestart()
        peripheralManager.stopAdvertising()
        pendingMeasurement = nil
        stopMeasurementRepeatTimer()
        cancelIdleAdvertisingRefresh()
        diagnosticText = "已停止广播"
        state = .idle
    }

    private func configureHeartRateService() {
        guard !serviceConfigured, !serviceAddInFlight else {
            return
        }

        state = .preparing
        Self.logger.info("configuring GATT services")
        diagnosticText = "配置蓝牙服务"
        serviceAddInFlight = true

        let measurement = CBMutableCharacteristic(
            type: Self.heartRateMeasurementUUID,
            properties: [.notify],
            value: nil,
            permissions: []
        )

        let bodyLocation = CBMutableCharacteristic(
            type: Self.bodySensorLocationUUID,
            properties: [.read],
            value: Data([0x02]),
            permissions: [.readable]
        )

        let heartRateService = CBMutableService(type: Self.heartRateServiceUUID, primary: true)
        heartRateService.characteristics = [measurement, bodyLocation]

        measurementCharacteristic = measurement
        peripheralManager.removeAllServices()
        peripheralManager.add(heartRateService)
    }

    private func notifyHeartRate(_ measurement: Data) {
        guard let characteristic = measurementCharacteristic, !subscribedCentralIDs.isEmpty else {
            pendingMeasurement = measurement
            Self.logger.debug("queued heart rate measurement; subscribed centrals=\(self.subscribedCentralIDs.count, privacy: .public)")
            return
        }

        let didSend = peripheralManager.updateValue(
            measurement,
            for: characteristic,
            onSubscribedCentrals: nil
        )

        Self.logger.debug("sent heart rate measurement didSend=\(didSend, privacy: .public)")
        pendingMeasurement = didSend ? nil : measurement
    }

    private func startMeasurementRepeatTimer() {
        guard measurementRepeatTimer == nil else {
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.repeatLatestHeartRate()
        }
        timer.tolerance = 0.2
        measurementRepeatTimer = timer
    }

    private func stopMeasurementRepeatTimer() {
        measurementRepeatTimer?.invalidate()
        measurementRepeatTimer = nil
    }

    private func scheduleIdleAdvertisingRefreshIfNeeded() {
        guard idleAdvertisingRefreshTimer == nil,
              isAdvertisingRequested,
              subscribedCentralIDs.isEmpty else {
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.refreshIdleAdvertising()
        }
        timer.tolerance = 0.3
        idleAdvertisingRefreshTimer = timer
    }

    private func cancelIdleAdvertisingRefresh() {
        idleAdvertisingRefreshTimer?.invalidate()
        idleAdvertisingRefreshTimer = nil
    }

    private func cancelPendingAdvertisingRestart() {
        pendingAdvertisingRestart?.cancel()
        pendingAdvertisingRestart = nil
    }

    private func refreshIdleAdvertising() {
        idleAdvertisingRefreshTimer = nil

        restartAdvertisingForReconnect(
            reason: "idle scanner compatibility refresh",
            diagnostic: "刷新蓝牙广播"
        )
    }

    private func restartAdvertisingForReconnect(reason: String, diagnostic: String) {
        guard isAdvertisingRequested else {
            updateRunningState()
            return
        }

        guard peripheralManager.state == .poweredOn else {
            updateStateForBluetoothPower()
            return
        }

        guard subscribedCentralIDs.isEmpty else {
            updateRunningState()
            return
        }

        cancelIdleAdvertisingRefresh()
        cancelPendingAdvertisingRestart()

        diagnosticText = diagnostic
        Self.logger.info("restarting advertising reason=\(reason, privacy: .public) isAdvertising=\(self.peripheralManager.isAdvertising, privacy: .public)")

        peripheralManager.stopAdvertising()
        updateRunningState()

        let restart = DispatchWorkItem { [weak self] in
            guard let self,
                  self.isAdvertisingRequested,
                  self.subscribedCentralIDs.isEmpty else {
                return
            }

            self.pendingAdvertisingRestart = nil
            self.startAdvertising()
        }

        pendingAdvertisingRestart = restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: restart)
    }

    private func repeatLatestHeartRate() {
        guard isAdvertisingRequested, !subscribedCentralIDs.isEmpty else {
            return
        }

        notifyHeartRate(HeartRateMeasurement.data(for: latestBroadcastBPM ?? 72))
    }

    private func updateStateForBluetoothPower() {
        Self.logger.info("bluetooth state=\(String(describing: self.peripheralManager.state), privacy: .public)")
        switch peripheralManager.state {
        case .unknown:
            state = .preparing
        case .resetting:
            state = .resetting
        case .unsupported:
            state = .unsupported
        case .unauthorized:
            state = .unauthorized
        case .poweredOff:
            state = .poweredOff
        case .poweredOn:
            updateRunningState()
        @unknown default:
            state = .error("未知蓝牙状态")
        }
    }

    private func updateRunningState() {
        guard isAdvertisingRequested else {
            state = .idle
            return
        }

        if !subscribedCentralIDs.isEmpty {
            state = .connected(subscribedCentralIDs.count)
        } else if peripheralManager.isAdvertising {
            state = .advertising
        } else {
            state = .preparing
        }
    }
}

extension BLEHeartRatePeripheral: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        cancelIdleAdvertisingRefresh()
        cancelPendingAdvertisingRestart()
        serviceConfigured = false
        serviceAddInFlight = false
        measurementCharacteristic = nil
        subscribedCentralIDs.removeAll()
        Self.logger.info("peripheralManagerDidUpdateState state=\(String(describing: peripheral.state), privacy: .public)")

        if peripheral.state == .poweredOn {
            configureHeartRateService()
        } else {
            updateStateForBluetoothPower()
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        serviceAddInFlight = false

        if let error {
            Self.logger.error("didAdd service=\(service.uuid.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            diagnosticText = "心率服务添加失败"
            state = .error("添加心率服务失败：\(error.localizedDescription)")
            return
        }

        Self.logger.info("didAdd service=\(service.uuid.uuidString, privacy: .public)")
        serviceConfigured = true

        if isAdvertisingRequested {
            startAdvertising()
        } else {
            state = .idle
        }
    }

    func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: Error?
    ) {
        if let error {
            Self.logger.error("didStartAdvertising error=\(error.localizedDescription, privacy: .public)")
            diagnosticText = "广播失败"
            state = .error("广播失败：\(error.localizedDescription)")
        } else {
            Self.logger.info("didStartAdvertising success")
            diagnosticText = "广播已启动"
            updateRunningState()
            scheduleIdleAdvertisingRefreshIfNeeded()
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        Self.logger.info("didSubscribe central=\(central.identifier.uuidString, privacy: .public) uuid=\(characteristic.uuid.uuidString, privacy: .public)")
        diagnosticText = "Garmin 已订阅心率"
        subscribedCentralIDs.insert(central.identifier)
        cancelIdleAdvertisingRefresh()
        cancelPendingAdvertisingRestart()
        startMeasurementRepeatTimer()
        updateRunningState()

        if isAdvertisingRequested, !peripheral.isAdvertising {
            Self.logger.info("restarting advertising after subscription for additional scanners")
            startAdvertising()
        }

        if let latestBroadcastBPM {
            notifyHeartRate(HeartRateMeasurement.data(for: latestBroadcastBPM))
        } else if let pendingMeasurement {
            notifyHeartRate(pendingMeasurement)
        } else {
            notifyHeartRate(HeartRateMeasurement.data(for: 72))
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        Self.logger.info("didUnsubscribe central=\(central.identifier.uuidString, privacy: .public) uuid=\(characteristic.uuid.uuidString, privacy: .public)")
        subscribedCentralIDs.remove(central.identifier)

        if isAdvertisingRequested, subscribedCentralIDs.isEmpty {
            restartAdvertisingForReconnect(
                reason: "central unsubscribed",
                diagnostic: "Garmin 已断开，重启广播"
            )
        } else {
            diagnosticText = "Garmin 取消订阅"
            updateRunningState()
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        Self.logger.info("peripheralManagerIsReady")
        guard let pendingMeasurement else {
            return
        }

        notifyHeartRate(pendingMeasurement)
    }
}
