import Foundation

public struct ThroughputWindow: Sendable {
    private struct Sample {
        let byteCount: Int
        let endedAt: ContinuousClock.Instant
    }

    /// Recency window for the live-sweep reading: a true wall-clock rate over the trailing
    /// half-second, so the reading reflects how many bytes actually arrived per second — not the
    /// burst rate of whichever chunk happened to finish fastest.
    public nonisolated static let liveWindow: Duration = .milliseconds(500)

    /// Floor for the elapsed-span divisor so a just-started stream (elapsed ≈ 0) doesn't blow up
    /// toward infinity.
    private nonisolated static let minimumDivisorSeconds: Double = 0.05

    private var samples: [Sample] = []
    private let window: Duration

    public nonisolated init(window: Duration = ThroughputWindow.liveWindow) {
        self.window = window
    }

    public nonisolated mutating func record(
        byteCount: Int, transferDuration _: Duration,
        endedAt: ContinuousClock.Instant
    ) {
        guard byteCount > 0 else {
            return
        }

        let newSample = Sample(byteCount: byteCount, endedAt: endedAt)
        samples.append(newSample)
        evictStalesamples(at: endedAt)
    }

    public nonisolated mutating func megabitsPerSecond(at now: ContinuousClock.Instant) -> Double? {
        evictStalesamples(at: now)

        guard let oldestSampleInstant = samples.map(\.endedAt).min() else {
            return nil
        }

        let totalBytes = samples.reduce(0) { $0 + $1.byteCount }
        let totalBits = Double(totalBytes * 8)
        let megabits = totalBits / 1_000_000

        let windowSeconds = window.timeInterval
        let elapsedSeconds = (now - oldestSampleInstant).timeInterval
        let divisorSeconds = min(windowSeconds, max(elapsedSeconds, Self.minimumDivisorSeconds))

        return megabits / divisorSeconds
    }

    private nonisolated mutating func evictStalesamples(at now: ContinuousClock.Instant) {
        let cutoff = now.advanced(by: window * -1)
        samples.removeAll { $0.endedAt <= cutoff }
    }
}

private extension Duration {
    nonisolated var timeInterval: Double {
        Double(components.seconds) + (Double(components.attoseconds) / 1e18)
    }
}
