import Foundation
import Network

/// Measures upload via periodic bursts on a separate cellular-bound connection.
/// Runs independently of the continuous download stream, yielding upload samples
/// on a configured interval to feed the existing upload window.
final class PeriodicUploadBurster {
    /// Interval between burst starts: every ~3 seconds. A single named constant for ease
    /// of tuning based on empirical data use targets (keep upload as minor fraction of total).
    private static let burstInterval: Duration = .seconds(3)

    private let now: @Sendable () -> ContinuousClock.Instant

    init(now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now }) {
        self.now = now
    }

    func samples() -> AsyncStream<ThroughputSample> {
        AsyncStream { continuation in
            let task = Task {
                await runPeriodicBurstLoop(continuation: continuation)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func runPeriodicBurstLoop(
        continuation: AsyncStream<ThroughputSample>.Continuation
    ) async {
        var nextBurstAt = now()

        while !Task.isCancelled {
            let delay = nextBurstAt - now()
            if delay > .zero {
                do {
                    try await ContinuousClock().sleep(for: delay)
                } catch {
                    break
                }
            }

            guard !Task.isCancelled else {
                break
            }

            do {
                let sample = try await performUploadBurst()
                continuation.yield(sample)
            } catch {
                // Burst failed; continue attempting on schedule.
            }

            nextBurstAt = now().advanced(by: Self.burstInterval)
        }
    }

    /// Performs a single upload burst: opens a separate `.cellular` connection,
    /// sends the full request+body, times the transfer, and returns a sample.
    private func performUploadBurst() async throws -> ThroughputSample {
        let connection = NetworkConnection(
            to: .hostPort(host: NWEndpoint.Host(HTTPProbeRequest.host), port: 443),
            using: .parameters { TLS() }
                .requiredInterfaceType(.cellular)
                .multipathServiceType(.disabled)
        )

        let startTime = now()
        let header = HTTPProbeRequest.uploadHeader()
        let body = HTTPProbeRequest.uploadBody()

        try await connection.send(header)
        try await connection.send(body)

        let burningRead = try await connection.receive(atLeast: 1, atMost: 100)
        _ = burningRead

        let endTime = now()
        let duration = startTime.duration(to: endTime)

        return ThroughputSample(
            direction: .upload,
            byteCount: header.count + body.count,
            transferDuration: duration,
            endedAt: endTime
        )
    }
}
