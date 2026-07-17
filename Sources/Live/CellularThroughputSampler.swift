import Foundation
import Network

/// Download-biased probe direction sequence: 3 download probes per 1 upload probe (every 4th
/// probe is upload), so the hero download reading refreshes far more often than the upload figure.
enum ProbeSchedule {
    static func direction(forProbeIndex index: Int) -> TransferDirection {
        (index + 1).isMultiple(of: 4) ? .upload : .download
    }
}

/// Live measurement engine: forces every probe over `.cellular` via `NetworkConnection` (the only
/// public API that can pin an interface) and runs a download-biased schedule of paced probes
/// against Cloudflare's speed endpoints. Untestable in CI/Simulator (no cellular radio) — see the
/// worklog for what only the device gate can verify.
final class CellularThroughputSampler: ThroughputSampling {
    init() {}

    func samples() -> AsyncStream<ThroughputSample> {
        AsyncStream { continuation in
            let task = Task {
                var connection = Self.makeConnection()
                var probeIndex = 0
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
                    let direction = ProbeSchedule.direction(forProbeIndex: probeIndex)
                    do {
                        let sample = try await Self.runProbe(direction: direction, on: connection)
                        continuation.yield(sample)
                        probeIndex += 1
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
