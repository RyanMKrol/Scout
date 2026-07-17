import Foundation

@MainActor
enum AppEnvironment {
    private static let scenarioDefaultsKey = "ScoutScenario"

    /// Builds the session from the current launch-argument scenario.
    static func makeSession() -> SweepSession {
        let scenario = scenario()
        return SweepSession(
            // LIVE seam: CoreTelephony-backed sampler replaces this line in T017/T019.
            sampler: SimulatedSampler(scenario: scenario),
            // LIVE seam: CoreTelephony-backed radio provider replaces this line in T016.
            radio: SimulatedRadioProvider(scenario: scenario),
            // LIVE seam: NWPathMonitor-backed path monitor replaces this line in T017.
            path: SimulatedPathMonitor(scenario: scenario)
        )
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
