import SwiftUI

struct ConsentStubView: View {
    let onStart: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ZStack {
            ScoutTheme.background
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Scout measures live cellular throughput")
                    .font(.title2)
                    .foregroundStyle(ScoutTheme.white(1.0))
                    .multilineTextAlignment(.center)

                Button("Start sweeping", action: onStart)
                    .accessibilityIdentifier("consent.start")

                Button("Not now", action: onNotNow)
                    .accessibilityIdentifier("consent.notNow")
            }
            .padding()
        }
    }
}
