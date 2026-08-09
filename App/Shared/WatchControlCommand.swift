import Foundation

enum WatchControlCommand {
    static let commandKey = "watchCommand"
    static let enabledKey = "heartRateCollectionEnabled"
    static let requestedAtKey = "requestedAt"
    static let isRunningKey = "isRunning"
    static let statusTextKey = "statusText"
    static let maxHeartRateKey = "maxHeartRate"

    private static let heartRateCollectionCommand = "heartRateCollection"
    private static let heartRateCollectionStatusCommand = "heartRateCollectionStatus"

    struct CollectionRequest {
        let enabled: Bool
        let requestedAt: Date
        let maxHeartRate: Int?
    }

    struct CollectionStatus {
        let isRunning: Bool
        let statusText: String
        let reportedAt: Date
    }

    static func payload(heartRateCollectionEnabled enabled: Bool, maxHeartRate: Int? = nil) -> [String: Any] {
        var payload: [String: Any] = [
            commandKey: heartRateCollectionCommand,
            enabledKey: enabled,
            requestedAtKey: Date().timeIntervalSince1970
        ]

        if let maxHeartRate {
            payload[maxHeartRateKey] = maxHeartRate
        }

        return payload
    }

    static func heartRateCollectionEnabled(from payload: [String: Any]) -> Bool? {
        collectionRequest(from: payload)?.enabled
    }

    static func collectionRequest(from payload: [String: Any]) -> CollectionRequest? {
        guard payload[commandKey] as? String == heartRateCollectionCommand else {
            return nil
        }

        guard let enabled = boolValue(payload[enabledKey]) else {
            return nil
        }

        let requestedAt = doubleValue(payload[requestedAtKey]) ?? Date().timeIntervalSince1970
        return CollectionRequest(
            enabled: enabled,
            requestedAt: Date(timeIntervalSince1970: requestedAt),
            maxHeartRate: intValue(payload[maxHeartRateKey])
        )
    }

    static func statusPayload(isRunning: Bool, statusText: String) -> [String: Any] {
        [
            commandKey: heartRateCollectionStatusCommand,
            isRunningKey: isRunning,
            statusTextKey: statusText,
            requestedAtKey: Date().timeIntervalSince1970
        ]
    }

    static func collectionStatus(from payload: [String: Any]) -> CollectionStatus? {
        guard payload[commandKey] as? String == heartRateCollectionStatusCommand,
              let isRunning = boolValue(payload[isRunningKey]),
              let statusText = payload[statusTextKey] as? String else {
            return nil
        }

        let reportedAt = doubleValue(payload[requestedAtKey]) ?? Date().timeIntervalSince1970
        return CollectionStatus(
            isRunning: isRunning,
            statusText: statusText,
            reportedAt: Date(timeIntervalSince1970: reportedAt)
        )
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as String:
            switch value.lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }
}
