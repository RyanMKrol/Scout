import SwiftUI

struct SweepDialView: View {
    enum Mode: Equatable {
        case live(DialContent)
        case idle
    }

    let mode: Mode

    @ScaledMetric(relativeTo: .largeTitle)
    private var dialDiameter: CGFloat = 288

    var body: some View {
        switch mode {
        case let .live(content):
            liveDialView(content: content)
        case .idle:
            idleDialView()
        }
    }

    // MARK: - Live Mode

    private func liveDialView(content: DialContent) -> some View {
        ZStack {
            // Sweep wedge (258 pt diameter, 0.14 opacity, 92°, period 3.4s)
            SweepWedgeView(
                color: content.qualityColor,
                opacity: 0.14,
                wedgeDegrees: 92,
                period: ScoutMotion.dialSweepPeriod,
                rotating: true
            )
            .frame(width: dialDiameter - 30, height: dialDiameter - 30)

            // Download track (264 pt diameter, 7 pt stroke, white 0.07)
            Circle()
                .stroke(ScoutTheme.white(0.07), lineWidth: 7)
                .frame(width: dialDiameter - 24, height: dialDiameter - 24)

            // Download arc (264 pt diameter, 7 pt stroke, quality color)
            Circle()
                .trim(from: 0, to: content.downFraction)
                .stroke(content.qualityColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: dialDiameter - 24, height: dialDiameter - 24)
                .animation(.linear(duration: ScoutMotion.arcDuration), value: content.downFraction)
                .animation(.easeInOut(duration: ScoutMotion.colorDuration), value: content.qualityColor)

            // Upload track (200 pt diameter, 6 pt stroke, white 0.06)
            Circle()
                .stroke(ScoutTheme.white(0.06), lineWidth: 6)
                .frame(width: 200, height: 200)

            // Upload arc (200 pt diameter, 6 pt stroke, uploadArc)
            Circle()
                .trim(from: 0, to: content.upFraction)
                .stroke(ScoutTheme.uploadArc, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 200)
                .animation(.linear(duration: ScoutMotion.arcDuration), value: content.upFraction)

            // Center stack
            DialCenterStack(mode: .live(content))
        }
        .frame(width: dialDiameter, height: dialDiameter)
    }

    // MARK: - Idle Mode

    private func idleDialView() -> some View {
        ZStack {
            // Download track only (264 pt diameter, 7 pt stroke, white 0.06)
            Circle()
                .stroke(ScoutTheme.white(0.06), lineWidth: 7)
                .frame(width: dialDiameter - 24, height: dialDiameter - 24)

            // Center stack
            DialCenterStack(mode: .idle)
        }
        .frame(width: dialDiameter, height: dialDiameter)
    }
}

#Preview("Live - Great") {
    ZStack {
        ScoutTheme.background
        SweepDialView(mode: .live(DialContent(
            downDisplay: "7.4",
            upDisplay: "3.1",
            downFraction: 0.5,
            upFraction: 0.4,
            qualityColor: ScoutTheme.great,
            generationText: "5G"
        )))
    }
}

#Preview("Live - Poor") {
    ZStack {
        ScoutTheme.background
        SweepDialView(mode: .live(DialContent(
            downDisplay: "1.2",
            upDisplay: "0.8",
            downFraction: 0.2,
            upFraction: 0.15,
            qualityColor: ScoutTheme.poor,
            generationText: "LTE"
        )))
    }
}

#Preview("Idle") {
    ZStack {
        ScoutTheme.background
        SweepDialView(mode: .idle)
    }
}
