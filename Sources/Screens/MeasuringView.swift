import Observation
import SwiftUI

struct MeasuringView: View {
    let session: SweepSession
    let consentGiven: Bool
    let onStart: () -> Void

    var body: some View {
        ZStack {
            ScoutTheme.background
                .ignoresSafeArea()

            if consentGiven, session.cellularAvailable {
                measuringContent()
            } else {
                pausedContent()
            }
        }
    }

    private func measuringContent() -> some View {
        VStack(spacing: 0) {
            statusRow()
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 120)

            SweepDialView(mode: .live(DialContent(
                downDisplay: ScoutMeter.downloadDisplay(session.downloadMbps),
                upDisplay: ScoutMeter.uploadDisplay(session.uploadMbps),
                downFraction: ScoutMeter.downloadArcFraction(session.downloadMbps),
                upFraction: ScoutMeter.uploadArcFraction(session.uploadMbps),
                qualityColor: session.quality.color,
                generationText: session.generation.rawValue
            )))
            .frame(maxHeight: .infinity, alignment: .center)

            footer()
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 48)
        }
        .padding(.horizontal, 30)
    }

    private func statusRow() -> some View {
        HStack(spacing: 9) {
            PulsingDot(color: session.quality.color, diameter: 7)

            Text("SWEEPING")
                .font(.system(size: 14, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(ScoutTheme.white(0.5))
        }
        .accessibilityIdentifier("measuring.status")
    }

    private func footer() -> some View {
        VStack(spacing: 14) {
            qualityWord()

            counterRow()

            Text("used this session")
                .font(.system(size: 12))
                .foregroundStyle(ScoutTheme.white(0.32))
        }
    }

    private func qualityWord() -> some View {
        let qualityText = qualityLabel(session.quality)
        return Text(qualityText)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(session.quality.color)
            .animation(.easeInOut(duration: ScoutMotion.colorDuration), value: session.quality)
            .accessibilityIdentifier("measuring.quality")
    }

    private func counterRow() -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                ArrowGlyph(direction: .down)
                    .frame(width: 11, height: 13)
                    .foregroundStyle(ScoutTheme.white(0.72))

                Text(ScoutMeter.megabytesDisplay(bytes: session.sessionDownloadBytes))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(ScoutTheme.white(0.72))

                Text("down")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(ScoutTheme.white(0.72))
            }
            .accessibilityIdentifier("measuring.dataDown")

            HStack(spacing: 0) {
                Text(" · ")
                    .font(.system(size: 14))
                    .foregroundStyle(ScoutTheme.white(0.3))
            }

            HStack(spacing: 6) {
                ArrowGlyph(direction: .up)
                    .frame(width: 11, height: 13)
                    .foregroundStyle(ScoutTheme.uploadText)

                Text(ScoutMeter.megabytesDisplay(bytes: session.sessionUploadBytes))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(ScoutTheme.uploadText)

                Text("up")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(ScoutTheme.uploadText)
            }
            .accessibilityIdentifier("measuring.dataUp")
        }
    }

    private func pausedContent() -> some View {
        VStack(spacing: 24) {
            Text("PAUSED")
                .font(.title)
                .foregroundStyle(ScoutTheme.white(1.0))
                .accessibilityIdentifier("paused.title")

            SweepDialView(mode: .idle)

            if !consentGiven {
                Button("Start sweeping", action: onStart)
                    .accessibilityIdentifier("paused.startButton")
            }
        }
    }

    private func qualityLabel(_ quality: SignalQuality) -> String {
        switch quality {
        case .great:
            "Great"
        case .usable:
            "Usable"
        case .poor:
            "Poor"
        }
    }
}
