import Foundation

struct HeartRateSample: Equatable {
    static let bpmKey = "bpm"
    static let timestampKey = "timestamp"

    let bpm: Int
    let date: Date

    init(bpm: Int, date: Date = Date()) {
        self.bpm = max(0, min(255, bpm))
        self.date = date
    }

    var payload: [String: Any] {
        [
            Self.bpmKey: bpm,
            Self.timestampKey: date.timeIntervalSince1970
        ]
    }

    static func fromPayload(_ payload: [String: Any]) -> HeartRateSample? {
        guard let bpm = intValue(payload[Self.bpmKey]), bpm > 0 else {
            return nil
        }

        let timestamp = doubleValue(payload[Self.timestampKey]) ?? Date().timeIntervalSince1970
        return HeartRateSample(bpm: bpm, date: Date(timeIntervalSince1970: timestamp))
    }

    var workoutMirrorData: Data? {
        let payload = WorkoutMirrorPayload(
            version: 1,
            bpm: bpm,
            timestamp: date.timeIntervalSince1970
        )
        return try? JSONEncoder().encode(payload)
    }

    static func fromWorkoutMirrorData(_ data: Data) -> HeartRateSample? {
        guard let payload = try? JSONDecoder().decode(WorkoutMirrorPayload.self, from: data),
              payload.version == 1,
              payload.bpm > 0 else {
            return nil
        }

        return HeartRateSample(
            bpm: payload.bpm,
            date: Date(timeIntervalSince1970: payload.timestamp)
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as Double:
            return Int(value.rounded())
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
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
}

private struct WorkoutMirrorPayload: Codable {
    let version: Int
    let bpm: Int
    let timestamp: TimeInterval
}
