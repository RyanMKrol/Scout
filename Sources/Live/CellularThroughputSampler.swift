import Foundation
import Network

/// Live measurement engine: forces the transfer over `.cellular` via `NetworkConnection` (the only
/// public API that can pin an interface) and runs ONE continuous, unbounded download stream against
/// Cloudflare's speed endpoint — emitting a `ThroughputSample` per received chunk so a rolling window
/// can compute a true wall-clock rate, rather than pacing discrete request/response probes with gaps
/// between them. Upload is not sampled here (see T048). Untestable in CI/Simulator (no cellular
/// radio) — see the worklog for what only the device gate can verify.
final class CellularThroughputSampler: ThroughputSampling {
    init() {}

    func samples() -> AsyncStream<ThroughputSample> {
        AsyncStream { continuation in
            let task = Task {
                await Self.runContinuousDownloadLoop(continuation: continuation)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static let receiveChunkCap = 262_144

    private static func runContinuousDownloadLoop(
        continuation: AsyncStream<ThroughputSample>.Continuation
    ) async {
        var connection = makeConnection()

        while !Task.isCancelled {
            do {
                try await streamDownload(on: connection, continuation: continuation)
            } catch {
                guard !Task.isCancelled else {
                    break
                }
                connection = makeConnection()
                do {
                    try await ContinuousClock().sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }
    }

    /// Streams a single HTTP body to completion, yielding one `ThroughputSample` per received
    /// chunk. If the fixed-size body ends before the caller stops consuming, transparently issues
    /// another request on the same connection so the overall stream is effectively unbounded.
    private static func streamDownload(
        on connection: NetworkConnection<TLS>,
        continuation: AsyncStream<ThroughputSample>.Continuation
    ) async throws {
        var parser = HTTPResponseParser()
        var lastChunkAt = ContinuousClock().now

        try await connection.send(HTTPProbeRequest.download())

        while !Task.isCancelled {
            let msg = try await connection.receive(atLeast: 1, atMost: receiveChunkCap)
            let events = try parser.feed(msg.content)

            for event in events {
                switch event {
                case .headersComplete, .needMoreData:
                    break
                case let .bodyProgress(newBodyBytes):
                    let now = ContinuousClock().now
                    continuation.yield(ThroughputSample(
                        direction: .download,
                        byteCount: newBodyBytes,
                        transferDuration: lastChunkAt.duration(to: now),
                        endedAt: now
                    ))
                    lastChunkAt = now
                case .responseComplete:
                    try await connection.send(HTTPProbeRequest.download())
                    parser = HTTPResponseParser()
                }
            }
        }
    }

    private static func makeConnection() -> NetworkConnection<TLS> {
        NetworkConnection(
            to: .hostPort(host: NWEndpoint.Host(HTTPProbeRequest.host), port: 443),
            using: .parameters { TLS() }
                .requiredInterfaceType(.cellular)
                .multipathServiceType(.disabled)
        )
    }
}
