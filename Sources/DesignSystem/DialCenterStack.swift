import SwiftUI

struct DialCenterStack: View {
    enum Mode {
        case live(DialContent)
        case idle

        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case let (.live(a), .live(b)):
                a == b
            case (.idle, .idle):
                true
            default:
                false
            }
        }
    }

    let mode: Mode

    var body: some View {
        switch mode {
        case let .live(content):
            liveCenterStack(content: content)
        case .idle:
            idleCenterStack()
        }
    }

    // MARK: - Live Mode

    private func liveCenterStack(content: DialContent) -> some View {
        VStack(spacing: 8) {
            // Generation label (15 pt, weight .medium, tracking 2, white 0.5)
            if !content.generationText.isEmpty {
                Text(content.generationText)
                    .font(.system(size: 15, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(ScoutTheme.white(0.5))
                    .accessibilityIdentifier("measuring.generation")
            }

            // Hero download number (80 pt, weight .semibold, tracking -3)
            HeroText(content.downDisplay, color: content.qualityColor)
                .accessibilityIdentifier("measuring.hero")

            // Down arrow + "Mbps down" row
            HStack(spacing: 6) {
                ArrowGlyph(direction: .down)
                    .foregroundStyle(ScoutTheme.white(0.55))
                    .accessibilityHidden(true)
                Text("Mbps down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ScoutTheme.white(0.55))
            }

            // Up arrow + upload number + "up" row
            HStack(spacing: 4) {
                ArrowGlyph(direction: .up)
                    .foregroundStyle(ScoutTheme.uploadText)
                    .accessibilityHidden(true)

                Text(content.upDisplay)
                    .font(.system(size: 19, weight: .semibold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(ScoutTheme.uploadText)
                    .accessibilityIdentifier("measuring.upload")

                Text("up")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(ScoutTheme.uploadText.opacity(0.7))
            }
        }
    }

    // MARK: - Idle Mode

    private func idleCenterStack() -> some View {
        VStack(spacing: 12) {
            // Em dash (96 pt, weight .semibold, white 0.22)
            Text("—")
                .font(.system(size: 96, weight: .semibold))
                .foregroundStyle(ScoutTheme.white(0.22))

            // "Mbps" (18 pt, medium, white 0.35)
            Text("Mbps")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ScoutTheme.white(0.35))
        }
    }
}

// MARK: - Hero Text Component

private struct HeroText: View {
    @ScaledMetric(relativeTo: .largeTitle)
    private var heroSize: CGFloat = 80

    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: heroSize, weight: .semibold, design: .default))
            .tracking(-3)
            .monospacedDigit()
            .foregroundStyle(color)
            .animation(.easeInOut(duration: ScoutMotion.colorDuration), value: color)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }
}

#Preview("Live - Great") {
    ZStack {
        ScoutTheme.background
        DialCenterStack(
            mode: .live(DialContent(
                downDisplay: "7.4",
                upDisplay: "3.1",
                downFraction: 0.5,
                upFraction: 0.4,
                qualityColor: ScoutTheme.great,
                generationText: "5G"
            ))
        )
    }
}

#Preview("Live - No generation") {
    ZStack {
        ScoutTheme.background
        DialCenterStack(
            mode: .live(DialContent(
                downDisplay: "142",
                upDisplay: "48",
                downFraction: 1.0,
                upFraction: 1.0,
                qualityColor: ScoutTheme.great,
                generationText: ""
            ))
        )
    }
}

#Preview("Idle") {
    ZStack {
        ScoutTheme.background
        DialCenterStack(mode: .idle)
    }
}
