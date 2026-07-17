import SwiftUI

/// A rotating angular-gradient sweep wedge — a leaf view isolated so parent state churn never resets animation.
struct SweepWedgeView: View {
    let color: Color
    let opacity: Double
    let wedgeDegrees: Double
    let period: Double
    let rotating: Bool

    @State private var isRotating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        let stops: [Gradient.Stop] = [
            .init(color: color.opacity(0), location: 0),
            .init(color: color, location: wedgeDegrees / 360),
            .init(color: color.opacity(0), location: wedgeDegrees / 360 + 0.0001),
            .init(color: color.opacity(0), location: 1),
        ]
        let gradient = AngularGradient(stops: stops, center: .center)
        let shouldAnimate = rotating && !reduceMotion
        let animation: Animation? = shouldAnimate
            ? .linear(duration: period).repeatForever(autoreverses: false)
            : nil

        return Circle()
            .fill(gradient)
            .opacity(opacity)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(animation, value: isRotating)
            .onAppear {
                if rotating, !reduceMotion {
                    isRotating = true
                }
            }
    }
}

#Preview {
    ZStack {
        ScoutTheme.background
            .ignoresSafeArea()

        SweepWedgeView(
            color: ScoutTheme.great,
            opacity: 0.18,
            wedgeDegrees: 98,
            period: 3.2,
            rotating: true
        )
        .frame(width: 196, height: 196)
    }
}
