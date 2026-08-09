import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    topBar
                    heartRatePanel
                    broadcastControl
                    statusGrid
                    detailPanel
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appModel.appBecameActive()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.heart.opacity(0.14))
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.heart)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("PulseCast")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(connectionSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            StatusDot(color: broadcastColor)
        }
    }

    private var heartRatePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("实时心率")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currentBPMText)
                            .font(.system(size: 76, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(heartRateColor)
                            .minimumScaleFactor(0.48)

                        Text("BPM")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 10)

                HeartRateZoneRing(
                    progress: heartRateZoneProgress,
                    hasSample: appModel.latestSample != nil
                )
                .frame(width: 96, height: 96)
            }

            HStack(spacing: 10) {
                InfoChip(
                    title: "采样",
                    value: sampleTimeText,
                    systemImage: "clock",
                    color: AppTheme.blue
                )
                InfoChip(
                    title: "发送",
                    value: latestBroadcastText,
                    systemImage: "heart.text.square",
                    color: AppTheme.heart
                )
            }
        }
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.separator, lineWidth: 1)
        )
    }

    private var broadcastControl: some View {
        Button {
            appModel.setBroadcasting(!appModel.isBroadcastingRequested)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                    Image(systemName: appModel.isBroadcastingRequested ? "pause.fill" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .bold))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appModel.isBroadcastingRequested ? "停止广播" : "开始广播")
                        .font(.headline.weight(.bold))
                    Text(appModel.broadcastStatusText)
                        .font(.caption.weight(.medium))
                        .opacity(0.82)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Image(systemName: broadcastControlIcon)
                    .font(.system(size: 24, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(broadcastColor, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var statusGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(
                title: "Apple Watch",
                value: appModel.watchSession.statusText,
                systemImage: "applewatch",
                color: watchColor
            )
            MetricTile(
                title: "Garmin",
                value: appModel.broadcastStatusText,
                systemImage: "bicycle",
                color: broadcastColor
            )
        }
    }

    private var detailPanel: some View {
        VStack(spacing: 0) {
            DetailRow(
                title: "蓝牙服务",
                value: "Heart Rate 180D",
                systemImage: "dot.radiowaves.left.and.right",
                color: AppTheme.teal
            )
            Divider()
                .padding(.leading, 48)
            DetailRow(
                title: "设备名称",
                value: appModel.bluetooth.advertisedName,
                systemImage: "tag",
                color: AppTheme.blue
            )
            Divider()
                .padding(.leading, 48)
            DetailRow(
                title: "连接事件",
                value: appModel.bluetooth.diagnosticText,
                systemImage: "wave.3.right",
                color: AppTheme.teal
            )
            Divider()
                .padding(.leading, 48)
            DetailRow(
                title: "最新时间",
                value: sampleTimeText,
                systemImage: "clock.arrow.circlepath",
                color: AppTheme.amber
            )
        }
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.separator, lineWidth: 1)
        )
    }

    private var connectionSummary: String {
        appModel.broadcastStatusText
    }

    private var broadcastControlIcon: String {
        if appModel.isWaitingForHeartRateBeforeBroadcast {
            return "hourglass"
        }

        return appModel.isBroadcastingRequested ? "checkmark.circle.fill" : "play.circle.fill"
    }

    private var currentBPMText: String {
        guard let bpm = appModel.latestSample?.bpm else {
            return "--"
        }
        return "\(bpm)"
    }

    private var latestBroadcastText: String {
        guard let bpm = appModel.bluetooth.latestBroadcastBPM else {
            return "等待"
        }
        return "\(bpm)"
    }

    private var sampleTimeText: String {
        guard let date = appModel.latestSample?.date else {
            return "等待"
        }

        let age = Date().timeIntervalSince(date)
        if age < 12 {
            return "刚刚"
        }

        return date.formatted(date: .omitted, time: .standard)
    }

    private var heartRateZoneProgress: Double {
        guard let bpm = appModel.latestSample?.bpm else {
            return 0
        }

        let maxRate = Double(maxHeartRate ?? 190)
        let percentOfMax = Double(bpm) / maxRate
        return min(1, max(0, percentOfMax))
    }

    private var heartRateColor: Color {
        guard let currentHeartRateZone else {
            return .secondary
        }

        return currentHeartRateZone.color
    }

    private var currentHeartRateZone: HeartRateZone? {
        guard let bpm = appModel.latestSample?.bpm,
              let age = appModel.healthProfile.age else {
            return nil
        }

        return HeartRateZone.zone(for: bpm, age: age)
    }

    private var maxHeartRate: Int? {
        guard let age = appModel.healthProfile.age,
              age > 0,
              age < 130 else {
            return nil
        }

        return 220 - age
    }

    private var watchColor: Color {
        let text = appModel.watchSession.statusText
        if text.contains("失败") || text.contains("未") {
            return AppTheme.heart
        }
        if text.contains("收到") || text.contains("已") {
            return AppTheme.teal
        }
        return AppTheme.amber
    }

    private var broadcastColor: Color {
        if appModel.isWaitingForHeartRateBeforeBroadcast {
            return AppTheme.amber
        }

        if !appModel.isBroadcastingRequested {
            return .secondary
        }

        switch appModel.bluetooth.state {
        case .connected(_):
            return AppTheme.teal
        case .advertising, .preparing:
            return AppTheme.amber
        case .idle:
            return AppTheme.amber
        case .poweredOff, .unauthorized, .unsupported, .resetting, .error(_):
            return AppTheme.heart
        }
    }

}

private enum AppTheme {
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let separator = Color.primary.opacity(0.08)
    static let heart = Color(red: 0.86, green: 0.12, blue: 0.17)
    static let teal = Color(red: 0.05, green: 0.56, blue: 0.48)
    static let blue = Color(red: 0.12, green: 0.36, blue: 0.76)
    static let green = Color(red: 0.18, green: 0.58, blue: 0.24)
    static let amber = Color(red: 0.88, green: 0.49, blue: 0.08)
    static let zoneGray = Color(red: 0.48, green: 0.50, blue: 0.54)
}

private enum HeartRateZone {
    case below
    case z1
    case z2
    case z3
    case z4
    case z5

    static func zone(for bpm: Int, age: Int) -> HeartRateZone {
        let maxHeartRate = max(1, 220 - age)
        let percentOfMax = Double(bpm) / Double(maxHeartRate)

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
            return AppTheme.zoneGray
        case .z2:
            return AppTheme.blue
        case .z3:
            return AppTheme.green
        case .z4:
            return AppTheme.amber
        case .z5:
            return AppTheme.heart
        }
    }
}

private struct HeartRateZoneRing: View {
    let progress: Double
    let hasSample: Bool

    private let segments = [
        ZoneRingSegment(start: 0.00, end: 0.50, color: AppTheme.separator),
        ZoneRingSegment(start: 0.50, end: 0.60, color: AppTheme.zoneGray),
        ZoneRingSegment(start: 0.60, end: 0.70, color: AppTheme.blue),
        ZoneRingSegment(start: 0.70, end: 0.80, color: AppTheme.green),
        ZoneRingSegment(start: 0.80, end: 0.90, color: AppTheme.amber),
        ZoneRingSegment(start: 0.90, end: 1.00, color: AppTheme.heart)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.start + 0.006, to: segment.end - 0.006)
                    .stroke(
                        segment.color.opacity(hasSample ? 0.95 : 0.34),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            if hasSample {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.heart)
                    .shadow(color: AppTheme.card, radius: 0, x: 0, y: 0)
                    .shadow(color: AppTheme.heart.opacity(0.32), radius: 4, y: 2)
                    .rotationEffect(.degrees(180))
                    .offset(y: -36)
                    .rotationEffect(.degrees(progress * 360))
            }

            Circle()
                .fill(AppTheme.card)
                .frame(width: 48, height: 48)

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.heart)
        }
    }
}

private struct ZoneRingSegment {
    let start: Double
    let end: Double
    let color: Color
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .stroke(color.opacity(0.25), lineWidth: 8)
            }
            .frame(width: 30, height: 30)
    }
}

private struct InfoChip: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                StatusDot(color: color)
                    .scaleEffect(0.72)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .frame(minHeight: 34, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.separator, lineWidth: 1)
        )
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel.shared)
}
