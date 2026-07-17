import SwiftUI

/// A pulsing status dot — a leaf view isolated so parent state churn never resets animation.
struct PulsingDot: View {
    let color: Color
    let diameter: CGFloat

    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .opacity(pulsing ? 1 : 0.3)
            .scaleEffect(pulsing ? 1 : 0.8)
            .animation(
                !reduceMotion
                    ? .easeInOut(duration: ScoutMotion.pulsePeriod / 2)
                    .repeatForever(autoreverses: true)
                    : nil,
                value: pulsing
            )
            .onAppear {
                if !reduceMotion {
                    pulsing = true
                }
            }
    }
}

#Preview {
    ZStack {
        ScoutTheme.background
            .ignoresSafeArea()

        PulsingDot(color: ScoutTheme.great, diameter: 7)
    }
}
