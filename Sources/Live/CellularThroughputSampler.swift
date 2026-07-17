import Foundation
import Network

/// Live measurement engine: forces every probe over `.cellular` via `NetworkConnection` (the only
/// public API that can pin an interface) and alternates paced download/upload probes against
/// Cloudflare's speed endpoints. Untestable in CI/Simulator (no cellular radio) — see the worklog
/// for what only the device gate can verify.
final class CellularThroughputSampler: ThroughputSampling {
    init() {}

    func samples() -> AsyncStream<ThroughputSample> {
        AsyncStream { continuation in
            let task = Task {
                var connection = Self.makeConnection()
                var direction: TransferDirection = .download
                var lastProbeStartedAt: ContinuousClock.Instant?

                while !Task.isCancelled {
                    let delay = ProbePacer.delayBeforeNextProbe(
                        lastProbeStartedAt: lastProbeStartedAt, now: ContinuousClock().now
                    )
                    if delay > .zero {
                        do {
                            try await ContinuousClock().sleep(for: delay)
                        } catch {
                            break
                        }
                    }
                    guard !Task.isCancelled else { break }

                    lastProbeStartedAt = ContinuousClock().now
                    do {
                        let sample = try await Self.runProbe(direction: direction, on: connection)
                        continuation.yield(sample)
                        direction = direction == .download ? .upload : .download
                    } catch {
                        connection = Self.makeConnection()
                        do {
                            try await ContinuousClock().sleep(for: .seconds(1))
                        } catch {
                            break
                        }
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
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

    private static func runProbe(
        direction: TransferDirection, on connection: NetworkConnection<TLS>
    ) async throws -> ThroughputSample {
        switch direction {
        case .download:
            try await runDownloadProbe(on: connection)
        case .upload:
            try await runUploadProbe(on: connection)
        }
    }

    private static func runDownloadProbe(
        on connection: NetworkConnection<TLS>
    ) async throws -> ThroughputSample {
        let start = ContinuousClock().now
        try await connection.send(HTTPProbeRequest.download())
        let contentLength = try await receiveUntilComplete(on: connection)
        let endedAt = ContinuousClock().now
        return ThroughputSample(
            direction: .download,
            byteCount: contentLength,
            transferDuration: start.duration(to: endedAt),
            endedAt: endedAt
        )
    }

    private static func runUploadProbe(
        on connection: NetworkConnection<TLS>
    ) async throws -> ThroughputSample {
        let start = ContinuousClock().now
        try await connection.send(HTTPProbeRequest.uploadHeader())
        try await connection.send(HTTPProbeRequest.uploadBody())
        _ = try await receiveUntilComplete(on: connection)
        let endedAt = ContinuousClock().now
        return ThroughputSample(
            direction: .upload,
            byteCount: HTTPProbeRequest.probeBytes,
            transferDuration: start.duration(to: endedAt),
            endedAt: endedAt
        )
    }

    private static func receiveUntilComplete(on connection: NetworkConnection<TLS>) async throws -> Int {
        var parser = HTTPResponseParser()
        var contentLength = 0

        while true {
            let msg = try await connection.receive(atLeast: 1, atMost: 262_144)
            let events = try parser.feed(msg.content)
            for event in events {
                switch event {
                case let .headersComplete(_, length):
                    contentLength = length ?? 0
                case .responseComplete:
                    return contentLength
                case .needMoreData, .bodyProgress:
                    break
                }
            }
        }
    }
}
