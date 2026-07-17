import SwiftUI

struct RootView: View {
    @AppStorage("firstRunConsentGiven") private var consentGiven = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var router: AppRouter
    @State private var session: SweepSession
    @State private var forceIdle: Bool

    init() {
        let initialConsent = UserDefaults.standard.bool(forKey: "firstRunConsentGiven")
        let forceIdle = UserDefaults.standard.bool(forKey: "ScoutForceIdle")
        let holdSplash = UserDefaults.standard.bool(forKey: "ScoutHoldSplash")

        // When forceIdle is set, pretend consent is given so splashFinished() lands on measuring
        let router = AppRouter(
            consentGiven: initialConsent || forceIdle,
            holdSplash: holdSplash
        )

        _router = State(wrappedValue: router)
        _session = State(wrappedValue: AppEnvironment.makeSession())
        _forceIdle = State(wrappedValue: forceIdle)
    }

    var body: some View {
        ZStack {
            switch router.phase {
            case .splash:
                SplashView()
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
                    consentGiven: router.consentGiven && !forceIdle,
                    onStart: {
                        router.startSweeping()
                        session.start()
                    }
                )
            }

            if router.phase == .splash {
                SplashView()
                    .zIndex(1)
                    .transition(.opacity)
            }
        }
        .onChange(of: router.consentGiven) { _, newValue in
            consentGiven = newValue
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .inactive, .background:
                // P0 rule: no data transfer outside the foreground, ever
                session.stop()
            case .active:
                if router.phase == .measuring, router.consentGiven {
                    session.start()
                }
            @unknown default:
                break
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.easeOut(duration: 0.4)) {
                router.splashFinished()
                if forceIdle {
                    consentGiven = false
                } else if router.phase == .measuring, router.consentGiven {
                    session.start()
                }
            }
        }
        .environment(session)
    }
}
