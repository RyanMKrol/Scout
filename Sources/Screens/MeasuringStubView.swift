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
                Text(ScoutMeter.downloadDisplay(session.downloadMbps))
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(ScoutTheme.white(1.0))
                    .accessibilityIdentifier("measuring.hero")
            } else {
                VStack(spacing: 24) {
                    Text("PAUSED")
                        .font(.title)
                        .foregroundStyle(ScoutTheme.white(1.0))
                        .accessibilityIdentifier("paused.title")

                    if !consentGiven {
                        Button("Start sweeping", action: onStart)
                            .accessibilityIdentifier("paused.startButton")
                    }
                }
            }
        }
    }
}
