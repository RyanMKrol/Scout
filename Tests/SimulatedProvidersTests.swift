@testable import Scout
import XCTest

@MainActor
final class SimulatedProvidersTests: XCTestCase {
    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: Duration = .seconds(3)
    ) async {
        let deadline = ContinuousClock().now.advanced(by: timeout)
        while !condition(), ContinuousClock().now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testGreatScenarioEmitsAlternatingSamples() async {
        let sampler = SimulatedSampler(scenario: .great)
        var collected: [ThroughputSample] = []

        let task = Task { @MainActor in
            for await sample in sampler.samples() {
                collected.append(sample)
                if collected.count >= 4 {
                    break
                }
            }
        }

        await waitUntil { collected.count >= 4 }
        task.cancel()

        XCTAssertEqual(collected.count, 4)
        XCTAssertEqual(collected[0].direction, .download)
        XCTAssertEqual(collected[1].direction, .upload)
        XCTAssertEqual(collected[2].direction, .download)
        XCTAssertEqual(collected[3].direction, .upload)
        for sample in collected {
            XCTAssertGreaterThan(sample.byteCount, 0)
            XCTAssertEqual(sample.transferDuration, .milliseconds(180))
        }
    }

    func testNoneScenarioYieldsNoSamples() async {
        let sampler = SimulatedSampler(scenario: .none)
        var collected: [ThroughputSample] = []

        let task = Task { @MainActor in
            for await sample in sampler.samples() {
                collected.append(sample)
            }
        }

        try? await Task.sleep(for: .milliseconds(400))
        task.cancel()

        XCTAssertTrue(collected.isEmpty)
    }

    func testRadioProviderYieldsExpectedGenerationPerScenario() async {
        let cases: [(SimulationScenario, RadioGeneration)] = [
            (.great, .fiveG),
            (.usable, .fiveG),
            (.poor, .lte),
            (.live, .fiveG),
            (.none, .unknown),
        ]

        for (scenario, expected) in cases {
            let provider = SimulatedRadioProvider(scenario: scenario)
            var iterator = provider.generations().makeAsyncIterator()
            let first = await iterator.next()
            XCTAssertEqual(first, expected, "scenario \(scenario) expected \(expected)")
        }
    }

    func testPathMonitorYieldsAvailabilityPerScenario() async {
        let noneMonitor = SimulatedPathMonitor(scenario: .none)
        var noneIterator = noneMonitor.availability().makeAsyncIterator()
        let noneFirst = await noneIterator.next()
        XCTAssertEqual(noneFirst, false)

        let greatMonitor = SimulatedPathMonitor(scenario: .great)
        var greatIterator = greatMonitor.availability().makeAsyncIterator()
        let greatFirst = await greatIterator.next()
        XCTAssertEqual(greatFirst, true)
    }

    func testCancellingConsumerTaskStopsFurtherEmission() async {
        let sampler = SimulatedSampler(scenario: .great)
        var collected: [ThroughputSample] = []

        let task = Task { @MainActor in
            for await sample in sampler.samples() {
                collected.append(sample)
            }
        }

        await waitUntil { collected.count >= 1 }
        task.cancel()

        let countAtCancel = collected.count
        try? await Task.sleep(for: .milliseconds(600))
        let countAfterGrace = collected.count

        XCTAssertEqual(countAtCancel, countAfterGrace)
    }
}
