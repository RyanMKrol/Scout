@testable import Scout
import XCTest

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class ScenarioWalkTests: XCTestCase {
    private struct BandCase {
        let scenario: SimulationScenario
        let lo: Double
        let hi: Double
    }

    func testBandedScenariosStayInClampRange() {
        let banded: [BandCase] = [
            BandCase(scenario: .great, lo: 6.5, hi: 9.8),
            BandCase(scenario: .usable, lo: 2.4, hi: 5.5),
            BandCase(scenario: .poor, lo: 0.3, hi: 1.4),
        ]

        for band in banded {
            let scenario = band.scenario
            var rng = SplitMix64(seed: 42)
            var value = ScenarioWalk.initialDownloadMbps(scenario)
            let clampLo = band.lo * 0.7
            let clampHi = min(band.hi * 1.12, 10.0)

            for _ in 0 ..< 200 {
                value = ScenarioWalk.nextDownloadMbps(previous: value, scenario: scenario, using: &rng)
                XCTAssertGreaterThanOrEqual(value, clampLo, "\(scenario) fell below clamp")
                XCTAssertLessThanOrEqual(value, clampHi, "\(scenario) exceeded clamp")
            }
        }
    }

    func testGreatScenarioStaysAboveFloor() {
        var rng = SplitMix64(seed: 7)
        var value = ScenarioWalk.initialDownloadMbps(.great)

        for _ in 0 ..< 200 {
            value = ScenarioWalk.nextDownloadMbps(previous: value, scenario: .great, using: &rng)
            XCTAssertGreaterThanOrEqual(value, 4.55)
        }
    }

    func testLiveScenarioStaysWithinRange() {
        var rng = SplitMix64(seed: 99)
        var value = ScenarioWalk.initialDownloadMbps(.live)

        for _ in 0 ..< 200 {
            value = ScenarioWalk.nextDownloadMbps(previous: value, scenario: .live, using: &rng)
            XCTAssertGreaterThanOrEqual(value, 0.2)
            XCTAssertLessThanOrEqual(value, 9.9)
        }
    }

    func testUploadStaysWithinRangeAndScalesWithDownload() {
        var rngLow = SplitMix64(seed: 1)
        var rngHigh = SplitMix64(seed: 2)

        var lowSum = 0.0
        var highSum = 0.0
        let iterations = 50

        for _ in 0 ..< iterations {
            let low = ScenarioWalk.uploadMbps(forDownload: 1, using: &rngLow)
            let high = ScenarioWalk.uploadMbps(forDownload: 8, using: &rngHigh)

            XCTAssertGreaterThanOrEqual(low, 0.1)
            XCTAssertLessThanOrEqual(low, 5.0)
            XCTAssertGreaterThanOrEqual(high, 0.1)
            XCTAssertLessThanOrEqual(high, 5.0)

            lowSum += low
            highSum += high
        }

        XCTAssertGreaterThan(highSum / Double(iterations), lowSum / Double(iterations))
    }
}
