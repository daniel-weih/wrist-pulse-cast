import SwiftUI

struct WatchContentView: View {
    @ObservedObject private var workoutManager = WatchRuntime.shared.workoutManager
    @ObservedObject private var connectivity = WatchRuntime.shared.connectivity

    var body: some View {
        GeometryReader { proxy in
            let buttonHeight: CGFloat = 44
            let buttonBottomInset: CGFloat = -14
            let ringButtonGap: CGFloat = 24
            let buttonCenterY = proxy.size.height - buttonBottomInset - buttonHeight / 2
            let buttonTopY = buttonCenterY - buttonHeight / 2
            let availableRingSize = max(82, buttonTopY - ringButtonGap)
            let ringSize = min(proxy.size.width * 0.92, availableRingSize, 140)

            ZStack {
                WatchHeartRateZoneRing(
                    progress: heartRateZoneProgress,
                    bpmText: currentBPMText,
                    bpmColor: heartRateColor,
                    hasSample: workoutManager.currentBPM != nil
                )
                .frame(width: ringSize, height: ringSize)
                .position(x: proxy.size.width / 2, y: ringSize / 2)

                Button {
                    if workoutManager.isRunning {
                        workoutManager.stopWorkout()
                    } else {
                        workoutManager.startWorkout()
                    }
                } label: {
                    Label(
                        workoutManager.isRunning ? "停止" : "开始",
                        systemImage: workoutManager.isRunning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(workoutManager.isRunning ? .red : .green)
                .frame(maxWidth: 122)
                .position(x: proxy.size.width / 2, y: buttonCenterY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 8)
        .onAppear {
            WatchRuntime.shared.configure()
        }
    }

    private var currentBPMText: String {
        guard let bpm = workoutManager.currentBPM else {
            return "--"
        }
        return "\(bpm)"
    }

    private var heartRateZoneProgress: Double {
        guard let bpm = workoutManager.currentBPM else {
            return 0
        }

        return min(1, max(0, Double(bpm) / Double(connectivity.maxHeartRate)))
    }

    private var heartRateColor: Color {
        guard let bpm = workoutManager.currentBPM else {
            return .secondary
        }

        return WatchHeartRateZone.zone(for: bpm, maxHeartRate: connectivity.maxHeartRate).color
    }
}

private enum WatchTheme {
    static let card = Color.black
    static let separator = Color.primary.opacity(0.08)
    static let heart = Color(red: 0.86, green: 0.12, blue: 0.17)
    static let blue = Color(red: 0.12, green: 0.36, blue: 0.76)
    static let green = Color(red: 0.18, green: 0.58, blue: 0.24)
    static let amber = Color(red: 0.88, green: 0.49, blue: 0.08)
    static let zoneGray = Color(red: 0.48, green: 0.50, blue: 0.54)
}

private enum WatchHeartRateZone {
    case below
    case z1
    case z2
    case z3
    case z4
    case z5

    static func zone(for bpm: Int, maxHeartRate: Int = 190) -> WatchHeartRateZone {
        let percentOfMax = Double(bpm) / Double(max(1, maxHeartRate))

        switch percentOfMax {
        case ..<0.5:
            return .below
        case ..<0.6:
            return .z1
        case ..<0.7:
            return .z2
        case ..<0.8:
            return .z3
        case ..<0.9:
            return .z4
        default:
            return .z5
        }
    }

    var color: Color {
        switch self {
        case .below, .z1:
            return WatchTheme.zoneGray
        case .z2:
            return WatchTheme.blue
        case .z3:
            return WatchTheme.green
        case .z4:
            return WatchTheme.amber
        case .z5:
            return WatchTheme.heart
        }
    }
}

private struct WatchHeartRateZoneRing: View {
    let progress: Double
    let bpmText: String
    let bpmColor: Color
    let hasSample: Bool

    private let segments = [
        WatchZoneRingSegment(start: 0.00, end: 0.50, color: WatchTheme.separator),
        WatchZoneRingSegment(start: 0.50, end: 0.60, color: WatchTheme.zoneGray),
        WatchZoneRingSegment(start: 0.60, end: 0.70, color: WatchTheme.blue),
        WatchZoneRingSegment(start: 0.70, end: 0.80, color: WatchTheme.green),
        WatchZoneRingSegment(start: 0.80, end: 0.90, color: WatchTheme.amber),
        WatchZoneRingSegment(start: 0.90, end: 1.00, color: WatchTheme.heart)
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = size * 10 / 96
            let innerSize = size * 48 / 96
            let markerSize = size * 13 / 96
            let markerOffset = size * 36 / 96

            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Circle()
                        .trim(from: segment.start + 0.006, to: segment.end - 0.006)
                        .stroke(
                            segment.color.opacity(hasSample ? 0.95 : 0.34),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                if hasSample {
                    Image(systemName: "heart.fill")
                        .font(.system(size: markerSize, weight: .bold))
                        .foregroundStyle(WatchTheme.heart)
                        .shadow(color: WatchTheme.card, radius: 0, x: 0, y: 0)
                        .shadow(color: WatchTheme.heart.opacity(0.32), radius: 4, y: 2)
                        .rotationEffect(.degrees(180))
                        .offset(y: -markerOffset)
                        .rotationEffect(.degrees(progress * 360))
                }

                Circle()
                    .fill(WatchTheme.card)
                    .frame(width: innerSize, height: innerSize)

                VStack(spacing: 0) {
                    Text(bpmText)
                        .font(.system(size: size * 0.29, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(bpmColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("BPM")
                        .font(.system(size: size * 0.08, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: innerSize * 0.9)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WatchZoneRingSegment {
    let start: Double
    let end: Double
    let color: Color
}

#Preview {
    WatchContentView()
}
