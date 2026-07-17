import SwiftUI

struct SplashStubView: View {
    var body: some View {
        ZStack {
            ScoutTheme.background
                .ignoresSafeArea()
            Text("Scout")
                .font(.largeTitle)
                .foregroundStyle(ScoutTheme.white(1.0))
                .accessibilityIdentifier("splash.wordmark")
        }
    }
}
