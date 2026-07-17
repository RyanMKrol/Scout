import Foundation

enum ProbePacer {
    static let interval: Duration = .milliseconds(500)

    static func delayBeforeNextProbe(
        lastProbeStartedAt: ContinuousClock.Instant?,
        now: ContinuousClock.Instant
    ) -> Duration {
        guard let lastProbeStartedAt else {
            return .zero
        }

        let elapsed = lastProbeStartedAt.duration(to: now)
        let remaining = interval - elapsed
        return remaining > .zero ? remaining : .zero
    }
}
