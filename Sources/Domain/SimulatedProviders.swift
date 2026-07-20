import Foundation

public final class SimulatedSampler: ThroughputSampling {
    private let scenario: SimulationScenario

    public init(scenario: SimulationScenario) {
        self.scenario = scenario
    }

    /// How often a download chunk sample is emitted: fast enough to look like a continuous stream
    /// (T045 replaces the old once-per-probe cadence), not tied to the walk's own update pace.
    private static let chunkInterval: Duration = .milliseconds(40)
    /// The download-rate random walk still advances on the old ~240ms cadence; every chunk in
    /// between reuses the current walked value, matching how a real continuous transfer's rate
    /// only meaningfully changes every so often even though bytes arrive every tick.
    private static let downloadWalkEveryNTicks = 6
    /// Periodic upload bursts emit every ~3 seconds (T048), matching the live PeriodicUploadBurster.
    private static let uploadBurstInterval: Duration = .seconds(3)

    public func samples() -> AsyncStream<ThroughputSample> {
        let scenario = scenario
        return AsyncStream { continuation in
            guard scenario != .none else {
                return
            }

            let downloadTask = Task {
                await runDownloadStream(scenario: scenario, continuation: continuation)
            }
            let uploadTask = Task {
                await runPeriodicUploadBursts(scenario: scenario, continuation: continuation)
            }

            continuation.onTermination = { _ in
                downloadTask.cancel()
                uploadTask.cancel()
            }
        }
    }

    private func runDownloadStream(
        scenario: SimulationScenario,
        continuation: AsyncStream<ThroughputSample>.Continuation
    ) async {
        var rng = SystemRandomNumberGenerator()
        var downloadMbps = ScenarioWalk.initialDownloadMbps(scenario)
        var tickIndex = 0

        while !Task.isCancelled {
            try? await ContinuousClock().sleep(for: Self.chunkInterval)
            guard !Task.isCancelled else {
                break
            }

            if tickIndex.isMultiple(of: Self.downloadWalkEveryNTicks) {
                downloadMbps = ScenarioWalk.nextDownloadMbps(
                    previous: downloadMbps, scenario: scenario, using: &rng
                )
            }

            continuation.yield(Self.downloadChunkSample(mbps: downloadMbps))
            tickIndex += 1
        }
    }

    private func runPeriodicUploadBursts(
        scenario: SimulationScenario,
        continuation: AsyncStream<ThroughputSample>.Continuation
    ) async {
        var nextBurstAt = ContinuousClock().now
        var rng = SystemRandomNumberGenerator()

        while !Task.isCancelled {
            let delay = nextBurstAt - ContinuousClock().now
            if delay > .zero {
                try? await ContinuousClock().sleep(for: delay)
            }

            guard !Task.isCancelled else {
                break
            }

            var downloadMbps = ScenarioWalk.initialDownloadMbps(scenario)
            let uploadMbps = ScenarioWalk.uploadMbps(forDownload: downloadMbps, using: &rng)
            continuation.yield(Self.uploadSample(mbps: uploadMbps))

            nextBurstAt = ContinuousClock().now.advanced(by: Self.uploadBurstInterval)
        }
    }

    private static func downloadChunkSample(mbps: Double) -> ThroughputSample {
        let byteCount = max(1, Int(mbps * 1_000_000 * 0.04 / 8))
        return ThroughputSample(
            direction: .download,
            byteCount: byteCount,
            transferDuration: chunkInterval,
            endedAt: ContinuousClock().now
        )
    }

    private static func uploadSample(mbps: Double) -> ThroughputSample {
        ThroughputSample(
            direction: .upload,
            byteCount: Int(mbps * 1_000_000 * 0.18 / 8),
            transferDuration: .milliseconds(180),
            endedAt: ContinuousClock().now
        )
    }
}

public final class SimulatedRadioProvider: RadioInfoProviding {
    private let scenario: SimulationScenario

    public init(scenario: SimulationScenario) {
        self.scenario = scenario
    }

    public func generations() -> AsyncStream<RadioGeneration> {
        let scenario = scenario
        return AsyncStream { continuation in
            continuation.yield(Self.generation(for: scenario))
        }
    }

    private static func generation(for scenario: SimulationScenario) -> RadioGeneration {
        switch scenario {
        case .great, .usable, .live:
            .fiveG
        case .poor:
            .lte
        case .none:
            .unknown
        }
    }
}

public final class SimulatedPathMonitor: CellularPathMonitoring {
    private let scenario: SimulationScenario

    public init(scenario: SimulationScenario) {
        self.scenario = scenario
    }

    public func availability() -> AsyncStream<Bool> {
        let scenario = scenario
        return AsyncStream { continuation in
            continuation.yield(scenario != .none)
        }
    }
}
