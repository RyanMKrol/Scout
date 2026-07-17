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
            statusRow(paused: false)
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

            VStack(spacing: 0) {
                footer()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 48)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current speed")
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityValue(
                AccessibilitySummary.value(
                    downloadMbps: session.downloadMbps,
                    uploadMbps: session.uploadMbps,
                    generation: session.generation,
                    quality: session.quality,
                    downloadBytes: session.sessionDownloadBytes,
                    uploadBytes: session.sessionUploadBytes
                )
            )
        }
        .padding(.horizontal, 30)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
                    .accessibilityHidden(true)

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
                    .accessibilityHidden(true)
            }

            HStack(spacing: 6) {
                ArrowGlyph(direction: .up)
                    .frame(width: 11, height: 13)
                    .foregroundStyle(ScoutTheme.uploadText)
                    .accessibilityHidden(true)

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
        VStack(spacing: 0) {
            statusRow(paused: true)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 120)

            SweepDialView(mode: .idle)
                .frame(maxHeight: .infinity, alignment: .center)

            VStack(spacing: 20) {
                pausedFooter()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 48)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Measurement paused")
            .accessibilityValue(pausedAccessibilityValue())
        }
        .padding(.horizontal, 30)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func statusRow(paused: Bool = false) -> some View {
        HStack(spacing: 9) {
            if paused {
                Circle()
                    .fill(ScoutTheme.white(0.28))
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            } else {
                PulsingDot(color: session.quality.color, diameter: 7)
                    .accessibilityHidden(true)
            }

            let text = paused ? "PAUSED" : "SWEEPING"
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(paused ? ScoutTheme.white(0.4) : ScoutTheme.white(0.5))
        }
        .accessibilityIdentifier(!paused ? "measuring.status" : "paused.status")
    }

    private func pausedFooter() -> some View {
        VStack(spacing: 20) {
            if consentGiven {
                noCellularFooter()
            } else {
                idleFooter()
            }
        }
    }

    private func noCellularFooter() -> some View {
        VStack(spacing: 16) {
            Text("No cellular to measure")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ScoutTheme.white(0.82))
                .accessibilityIdentifier("paused.title")

            bodyWithEmphasis(
                baseText: "Scout measures your cellular speed — download and upload. Turn off Airplane Mode or Wi-Fi to start sweeping.",
                emphasizedWord: "cellular"
            )
            .accessibilityIdentifier("paused.body")
        }
    }

    private func idleFooter() -> some View {
        VStack(spacing: 16) {
            Text("Sweeping is off")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ScoutTheme.white(0.82))
                .accessibilityIdentifier("paused.title")

            Text("Scout only measures cellular data when you choose. Start sweeping to measure this spot.")
                .font(.system(size: 15))
                .foregroundStyle(ScoutTheme.white(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .accessibilityIdentifier("paused.body")

            Button(action: onStart) {
                Text("Start sweeping")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ScoutTheme.onAccent)
                    .frame(maxWidth: 240)
                    .frame(height: 50)
                    .background(ScoutTheme.great)
                    .cornerRadius(14)
            }
            .accessibilityIdentifier("paused.startButton")
        }
    }

    private func bodyWithEmphasis(baseText: String, emphasizedWord: String) -> some View {
        let components = baseText.components(separatedBy: emphasizedWord)
        var result: Text?

        for (index, component) in components.enumerated() {
            if index > 0 {
                result = (result ?? Text(""))
                    + Text(emphasizedWord)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ScoutTheme.white(0.7))
            }
            result = (result ?? Text(""))
                + Text(component)
                .font(.system(size: 15))
                .foregroundStyle(ScoutTheme.white(0.5))
        }

        return (result ?? Text(""))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)
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

    private func pausedAccessibilityValue() -> String {
        if consentGiven {
            "No cellular to measure. Scout measures your cellular speed — download and upload. " +
                "Turn off Airplane Mode or Wi-Fi to start sweeping."
        } else {
            "Sweeping is off. Scout only measures cellular data when you choose. " +
                "Start sweeping to measure this spot."
        }
    }
}
