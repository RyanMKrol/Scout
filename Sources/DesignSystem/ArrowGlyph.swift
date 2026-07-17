import SwiftUI

struct ArrowGlyph: View {
    enum Direction {
        case down
        case up
    }

    let direction: Direction

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let scale = size.width / 11.0

            switch direction {
            case .down:
                // Vertical shaft: x=6.5 from y=1 to y=10
                path.move(to: CGPoint(x: 6.5 * scale, y: 1 * scale))
                path.addLine(to: CGPoint(x: 6.5 * scale, y: 10 * scale))

                // Left head stroke: from (6.5, 10.5) to (3, 7)
                path.move(to: CGPoint(x: 6.5 * scale, y: 10.5 * scale))
                path.addLine(to: CGPoint(x: 3 * scale, y: 7 * scale))

                // Right head stroke: from (6.5, 10.5) to (10, 7)
                path.move(to: CGPoint(x: 6.5 * scale, y: 10.5 * scale))
                path.addLine(to: CGPoint(x: 10 * scale, y: 7 * scale))

            case .up:
                // Flip vertically: mirror around y=7 (middle of viewBox)
                let flipY: (CGFloat) -> CGFloat = { y in 14 - y }

                // Vertical shaft: from y=4 to y=13 (flipped)
                path.move(to: CGPoint(x: 6.5 * scale, y: flipY(1) * scale))
                path.addLine(to: CGPoint(x: 6.5 * scale, y: flipY(10) * scale))

                // Left head stroke: from (6.5, 3.5) to (3, 7)
                path.move(to: CGPoint(x: 6.5 * scale, y: flipY(10.5) * scale))
                path.addLine(to: CGPoint(x: 3 * scale, y: flipY(7) * scale))

                // Right head stroke: from (6.5, 3.5) to (10, 7)
                path.move(to: CGPoint(x: 6.5 * scale, y: flipY(10.5) * scale))
                path.addLine(to: CGPoint(x: 10 * scale, y: flipY(7) * scale))
            }

            let stroke = StrokeStyle(
                lineWidth: 1.5,
                lineCap: .round,
                lineJoin: .round
            )
            context.stroke(path, with: .foreground, style: stroke)
        }
        .frame(width: 11, height: 13)
    }
}

#Preview {
    VStack(spacing: 16) {
        ArrowGlyph(direction: .down)
            .foregroundStyle(.blue)
        ArrowGlyph(direction: .up)
            .foregroundStyle(.green)
    }
    .padding()
    .background(Color.black)
}
