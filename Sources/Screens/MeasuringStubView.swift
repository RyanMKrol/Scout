import SwiftUI

struct MeasuringStubView: View {
    let session: SweepSession
    let consentGiven: Bool
    let onStart: () -> Void

    var body: some View {
        ZStack {
            ScoutTheme.background
                .ignoresSafeArea()

            if consentGiven, session.cellularAvailable {
                let content = DialContent(
                    downDisplay: ScoutMeter.downloadDisplay(session.downloadMbps),
                    upDisplay: ScoutMeter.uploadDisplay(session.uploadMbps),
                    downFraction: ScoutMeter.downloadArcFraction(session.downloadMbps),
                    upFraction: ScoutMeter.uploadArcFraction(session.uploadMbps),
                    qualityColor: session.quality.color,
                    generationText: session.generation.rawValue
                )
                DialCenterStack(mode: .live(content))
            } else {
                VStack(spacing: 24) {
                    Text("PAUSED")
                        .font(.title)
                        .foregroundStyle(ScoutTheme.white(1.0))
                        .accessibilityIdentifier("paused.title")

                    DialCenterStack(mode: .idle)

                    if !consentGiven {
                        Button("Start sweeping", action: onStart)
                            .accessibilityIdentifier("paused.startButton")
                    }
                }
            }
        }
    }
}
