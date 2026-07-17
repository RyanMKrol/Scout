import SwiftUI

struct ConsentView: View {
    let onStart: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ZStack {
            ScoutTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        RadarMarkView(style: .consent)
                            .accessibilityHidden(true)

                        VStack(spacing: 16) {
                            Text("Scout uses cellular data to measure")
                                .font(.system(size: 30, weight: .bold, design: .default))
                                .tracking(-0.6)
                                .foregroundStyle(ScoutTheme.white(1.0))
                                .lineLimit(nil)
                                .accessibilityIdentifier("consent.title")

                            Text(
                                "To read real, usable speed — both download and upload — Scout " +
                                    "transfers a little data over your cellular connection while " +
                                    "it's running."
                            )
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundStyle(ScoutTheme.white(0.6))
                            .lineSpacing(((16 * 1.55) - 16) / 2)
                        }

                        VStack(spacing: 18) {
                            bulletPoint(
                                text: attributedBulletText(
                                    normal: "Roughly ",
                                    bold: "10–40 MB per minute",
                                    normalEnd: ", always shown on screen."
                                )
                            )

                            bulletPoint(
                                text: Text("Only while the screen is on and you're looking — never in the background.")
                            )

                            bulletPoint(
                                text: Text("On a metered or low-data plan? Keep sessions short.")
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 132)
                    .padding(.bottom, 32)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button(action: onStart) {
                        Text("Start sweeping")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundStyle(ScoutTheme.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(ScoutTheme.great)
                            .cornerRadius(16)
                    }
                    .accessibilityIdentifier("consent.start")

                    Button(action: onNotNow) {
                        Text("Not now")
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundStyle(ScoutTheme.white(0.5))
                            .frame(height: 44)
                    }
                    .accessibilityIdentifier("consent.notNow")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }

    private func bulletPoint(text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            Circle()
                .fill(ScoutTheme.great)
                .frame(width: 6, height: 6)
                .padding(.top, 2)

            text
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(ScoutTheme.white(0.72))
                .lineLimit(nil)
        }
    }

    private func attributedBulletText(normal: String, bold: String, normalEnd: String) -> Text {
        Text(normal)
            + Text(bold)
            .fontWeight(.semibold)
            .monospacedDigit()
            + Text(normalEnd)
    }
}

#Preview {
    ZStack {
        ScoutTheme.background
            .ignoresSafeArea()

        ConsentView(
            onStart: {},
            onNotNow: {}
        )
    }
}
