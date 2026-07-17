public enum TransferDirection: Sendable, Equatable {
    case download, upload
}

public struct ThroughputSample: Sendable, Equatable {
    public let direction: TransferDirection
    public let byteCount: Int
    public let transferDuration: Duration
    public let endedAt: ContinuousClock.Instant

    public init(
        direction: TransferDirection, byteCount: Int, transferDuration: Duration,
        endedAt: ContinuousClock.Instant
    ) {
        self.direction = direction
        self.byteCount = byteCount
        self.transferDuration = transferDuration
        self.endedAt = endedAt
    }
}

public protocol ThroughputSampling: Sendable {
    func samples() -> AsyncStream<ThroughputSample>
}

public protocol RadioInfoProviding: Sendable {
    func generations() -> AsyncStream<RadioGeneration>
}

public protocol CellularPathMonitoring: Sendable {
    func availability() -> AsyncStream<Bool>
}
