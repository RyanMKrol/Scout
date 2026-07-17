import Foundation

@MainActor
enum AppEnvironment {
    private static let scenarioDefaultsKey = "ScoutScenario"

    /// Builds the session from the current launch-argument scenario.
    static func makeSession() -> SweepSession {
        let scenario = scenario()
        return SweepSession(
            sampler: sampler(scenario: scenario),
            radio: radioProvider(scenario: scenario),
            path: pathProvider(scenario: scenario)
        )
    }

    private static func sampler(scenario: SimulationScenario) -> ThroughputSampling {
        #if !targetEnvironment(simulator)
            if scenario == .live {
                return CellularThroughputSampler()
            }
        #endif
        return SimulatedSampler(scenario: scenario)
    }

    private static func radioProvider(scenario: SimulationScenario) -> RadioInfoProviding {
        #if !targetEnvironment(simulator)
            if scenario == .live {
                return CoreTelephonyRadioProvider()
            }
        #endif
        return SimulatedRadioProvider(scenario: scenario)
    }

    private static func pathProvider(scenario: SimulationScenario) -> CellularPathMonitoring {
        #if !targetEnvironment(simulator)
            if scenario == .live {
                return CellularPathMonitor()
            }
        #endif
        return SimulatedPathMonitor(scenario: scenario)
    }

    /// Parses UserDefaults "ScoutScenario" (auto-populated by a `-ScoutScenario <value>` launch
    /// argument — iOS puts dash-prefixed launch arguments into the UserDefaults argument domain).
    static func scenario() -> SimulationScenario {
        guard let raw = UserDefaults.standard.string(forKey: scenarioDefaultsKey),
              let scenario = SimulationScenario(rawValue: raw)
        else {
            return .live
        }
        return scenario
    }
}
