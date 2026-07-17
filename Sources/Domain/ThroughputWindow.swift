import Foundation

public struct ThroughputWindow: Sendable {
    private struct Sample {
        let byteCount: Int
        let transferDuration: Duration
        let endedAt: ContinuousClock.Instant
    }

    private var samples: [Sample] = []
    private let window: Duration

    public nonisolated init(window: Duration = .seconds(2)) {
        self.window = window
    }

    public nonisolated mutating func record(
        byteCount: Int, transferDuration: Duration,
        endedAt: ContinuousClock.Instant
    ) {
        guard byteCount > 0, transferDuration > .zero else {
            return
        }

        let newSample = Sample(byteCount: byteCount, transferDuration: transferDuration, endedAt: endedAt)
        samples.append(newSample)
        evictStalesamples(at: endedAt)
    }

    public nonisolated mutating func megabitsPerSecond(at now: ContinuousClock.Instant) -> Double? {
        evictStalesamples(at: now)

        guard !samples.isEmpty else {
            return nil
        }

        let totalBytes = samples.reduce(0) { $0 + $1.byteCount }
        let totalDuration = samples.reduce(Duration.zero) { $0 + $1.transferDuration }

        guard totalDuration > .zero else {
            return nil
        }

        let totalBits = Double(totalBytes * 8)
        let totalSeconds = totalDuration.timeInterval
        let megabits = totalBits / 1_000_000

        return megabits / totalSeconds
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
