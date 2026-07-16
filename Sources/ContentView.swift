import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Placeholder scaffold screen (T001). Deliberately NOT pure black so the
            // full-screen check can distinguish app pixels from letterbox bars.
            Color(red: 0.06, green: 0.06, blue: 0.08)
                .ignoresSafeArea()
            Text("Hello, Scout")
                .font(.title)
                .foregroundStyle(.white)
        }
    }
}
