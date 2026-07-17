import SwiftUI

struct RadarMarkView: View {
    enum Style { case splash, consent }

    let style: Style

    var body: some View {
        switch style {
        case .splash:
            splashVariant
                .frame(width: 196, height: 196)
        case .consent:
            consentVariant
                .frame(width: 76, height: 76)
        }
    }

    private var splashVariant: some View {
        ZStack {
            SweepWedgeView(
                color: ScoutTheme.great,
                opacity: 0.18,
                wedgeDegrees: 98,
                period: ScoutMotion.splashSweepPeriod,
                rotating: true
            )

            rings(radii: [92, 62, 32], opacities: [0.09, 0.11, 0.13])

            Circle()
                .fill(ScoutTheme.great)
                .frame(width: 12, height: 12)
        }
    }

    private var consentVariant: some View {
        ZStack {
            SweepWedgeView(
                color: ScoutTheme.great,
                opacity: 0.20,
                wedgeDegrees: 92,
                period: ScoutMotion.splashSweepPeriod,
                rotating: false
            )

            rings(radii: [35, 22], opacities: [0.10, 0.12])

            Circle()
                .fill(ScoutTheme.great)
                .frame(width: 9, height: 9)
        }
    }

    private func rings(radii: [Double], opacities: [Double]) -> some View {
        ZStack {
            ForEach(Array(zip(radii, opacities)), id: \.0) { radius, opacity in
                Circle()
                    .stroke(ScoutTheme.white(opacity), lineWidth: 1.5)
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        ZStack {
            ScoutTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Splash (196×196)")
                    .foregroundStyle(.white)
                RadarMarkView(style: .splash)
            }
        }

        ZStack {
            ScoutTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Consent (76×76)")
                    .foregroundStyle(.white)
                RadarMarkView(style: .consent)
            }
        }
    }
}
