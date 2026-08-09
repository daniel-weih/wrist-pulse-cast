import Foundation

enum HeartRateMeasurement {
    static func data(for bpm: Int) -> Data {
        let clampedBPM = UInt8(clamping: bpm)
        return Data([0x00, clampedBPM])
    }
}
