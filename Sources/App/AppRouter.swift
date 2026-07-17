import Foundation

@MainActor @Observable
final class AppRouter {
    enum Phase: Equatable {
        case splash
        case consent
        case measuring
    }

    private(set) var phase: Phase
    private(set) var consentGiven: Bool
    private let holdSplash: Bool

    init(consentGiven: Bool, holdSplash: Bool = false) {
        self.consentGiven = consentGiven
        self.holdSplash = holdSplash
        phase = .splash
    }

    func splashFinished() {
        guard phase == .splash else { return }
        guard !holdSplash else { return }
        phase = consentGiven ? .measuring : .consent
    }

    func startSweeping() {
        consentGiven = true
        phase = .measuring
    }

    func declineConsent() {
        guard phase == .consent else { return }
        phase = .measuring
    }
}
