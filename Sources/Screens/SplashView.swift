import SwiftUI

// MARK: - SplashView

struct SplashView: View {
    var body: some View {
        ZStack {
            ScoutTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    RadarMarkView(style: .splash)
                        .accessibilityHidden(true)
                        .padding(.bottom, 44)

                    Text("Scout")
                        .font(.system(size: 48, weight: .bold))
                        .tracking(-1.5)
                        .foregroundStyle(ScoutTheme.white(1.0))
                        .accessibilityIdentifier("splash.wordmark")

                    Text("Find your signal.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(ScoutTheme.white(0.5))
                        .padding(.top, 12)
                }

                Spacer()

                VStack(spacing: 18) {
                    HStack(spacing: 0) {
                        Capsule()
                            .fill(ScoutTheme.white(0.12))
                            .frame(width: 132, height: 3)

                        Spacer()
                    }
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(ScoutTheme.great)
                            .frame(width: 52.8, height: 3)
                    }
                    .accessibilityHidden(true)

                    Text("Measures real usable speed — not signal bars")
                        .font(.system(size: 12))
                        .foregroundStyle(ScoutTheme.white(0.3))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 64)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    SplashView()
}
