public enum SimulationScenario: String, Sendable, Equatable {
    case live = "Live", great = "Great", usable = "Usable", poor = "Poor", none = "None"
}

public enum ScenarioWalk {
    private struct Band {
        let lo: Double
        let hi: Double
        let initial: Double
    }

    private nonisolated static let bands: [SimulationScenario: Band] = [
        .great: Band(lo: 6.5, hi: 9.8, initial: 8.15),
        .usable: Band(lo: 2.4, hi: 5.5, initial: 3.95),
        .poor: Band(lo: 0.3, hi: 1.4, initial: 0.85),
    ]

    public nonisolated static func initialDownloadMbps(_ scenario: SimulationScenario) -> Double {
        switch scenario {
        case .great, .usable, .poor:
            bands[scenario]?.initial ?? 0
        case .live:
            4.0
        case .none:
            0
        }
    }

    public nonisolated static func nextDownloadMbps(
        previous: Double, scenario: SimulationScenario,
        using rng: inout some RandomNumberGenerator
    ) -> Double {
        switch scenario {
        case .great, .usable, .poor:
            guard let band = bands[scenario] else { return previous }
            let center = (band.lo + band.hi) / 2
            let rand01 = Double.random(in: 0 ..< 1, using: &rng)
            let next = previous + (center - previous) * 0.28 + (rand01 - 0.5) * (band.hi - band.lo) * 0.4
            return min(max(next, band.lo * 0.7), min(band.hi * 1.12, 10.0))
        case .live:
            let rand01 = Double.random(in: 0 ..< 1, using: &rng)
            var next = previous + (rand01 - 0.5) * 1.3
            if Double.random(in: 0 ..< 1, using: &rng) < 0.06 {
                let burst = Double.random(in: 0 ..< 1, using: &rng)
                next += (burst - 0.4) * 4.3
            }
            return min(max(next, 0.2), 9.9)
        case .none:
            return 0
        }
    }

    public nonisolated static func uploadMbps(
        forDownload down: Double, using rng: inout some RandomNumberGenerator
    ) -> Double {
        let rand01 = Double.random(in: 0 ..< 1, using: &rng)
        let next = down * 0.45 + (rand01 - 0.5) * 0.6
        return min(max(next, 0.1), 5.0)
    }
}
