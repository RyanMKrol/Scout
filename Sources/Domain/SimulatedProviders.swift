import Foundation

public final class SimulatedSampler: ThroughputSampling {
    private let scenario: SimulationScenario

    public init(scenario: SimulationScenario) {
        self.scenario = scenario
    }

    public func samples() -> AsyncStream<ThroughputSample> {
        let scenario = scenario
        return AsyncStream { continuation in
            guard scenario != .none else {
                return
            }

            let task = Task {
                var rng = SystemRandomNumberGenerator()
                var downloadMbps = ScenarioWalk.initialDownloadMbps(scenario)
                var direction: TransferDirection = .download

                while !Task.isCancelled {
                    try? await ContinuousClock().sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else {
                        break
                    }

                    let mbps: Double
                    switch direction {
                    case .download:
                        downloadMbps = ScenarioWalk.nextDownloadMbps(
                            previous: downloadMbps, scenario: scenario, using: &rng
                        )
                        mbps = downloadMbps
                    case .upload:
                        mbps = ScenarioWalk.uploadMbps(forDownload: downloadMbps, using: &rng)
                    }

                    continuation.yield(Self.sample(direction: direction, mbps: mbps))
                    direction = direction == .download ? .upload : .download
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func sample(direction: TransferDirection, mbps: Double) -> ThroughputSample {
        ThroughputSample(
            direction: direction,
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
