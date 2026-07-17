import SwiftUI

struct RootView: View {
    @AppStorage("firstRunConsentGiven") private var consentGiven = false
    @State private var router: AppRouter
    @State private var session: SweepSession

    init() {
        let initialConsent = UserDefaults.standard.bool(forKey: "firstRunConsentGiven")
        _router = State(
            wrappedValue: AppRouter(
                consentGiven: initialConsent,
                holdSplash: UserDefaults.standard.bool(forKey: "ScoutHoldSplash")
            )
        )
        _session = State(wrappedValue: AppEnvironment.makeSession())
    }

    var body: some View {
        ZStack {
            switch router.phase {
            case .splash:
                SplashStubView()
            case .consent:
                ConsentStubView(
                    onStart: {
                        router.startSweeping()
                        session.start()
                    },
                    onNotNow: {
                        router.declineConsent()
                    }
                )
            case .measuring:
                MeasuringStubView(
                    session: session,
                    consentGiven: router.consentGiven,
                    onStart: {
                        router.startSweeping()
                        session.start()
                    }
                )
            }

            if router.phase == .splash {
                SplashStubView()
                    .zIndex(1)
                    .transition(.opacity)
            }
        }
        .onChange(of: router.consentGiven) { _, newValue in
            consentGiven = newValue
        }
        .task {
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.easeOut(duration: 0.4)) {
                router.splashFinished()
                if router.phase == .measuring, router.consentGiven {
                    session.start()
                }
            }
        }
        .environment(session)
    }
}
