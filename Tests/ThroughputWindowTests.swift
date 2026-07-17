@testable import Scout
import XCTest

final class ThroughputWindowTests: XCTestCase {
    func testSingleSample250kB200ms() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let endTime = base.advanced(by: .milliseconds(200))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: endTime)

        let mbps = window.megabitsPerSecond(at: endTime)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 10.0, accuracy: 0.001)
        }
    }

    func testTwoSamplesWeightedByTransferTime() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .milliseconds(200))
        window.record(
            byteCount: 250_000, transferDuration: .milliseconds(200),
            endedAt: time1
        )

        let time2 = base.advanced(by: .milliseconds(400))
        window.record(
            byteCount: 125_000, transferDuration: .milliseconds(200),
            endedAt: time2
        )

        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 7.5, accuracy: 0.001)
        }
    }

    func testSampleEviction() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let oldTime = base.advanced(by: .seconds(-3))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: oldTime)

        let freshTime = base
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: freshTime)

        let mbps = window.megabitsPerSecond(at: freshTime)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 10.0, accuracy: 0.001)
        }
    }

    func testAllSamplesStale() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let sampleTime = base.advanced(by: .seconds(-3))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: sampleTime)

        let queryTime = base
        let mbps = window.megabitsPerSecond(at: queryTime)
        XCTAssertNil(mbps)
    }

    func testIgnoreZeroByteCount() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .milliseconds(200))
        window.record(byteCount: 0, transferDuration: .milliseconds(200), endedAt: time1)

        let time2 = base.advanced(by: .milliseconds(400))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: time2)

        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 10.0, accuracy: 0.001)
        }
    }

    func testIgnoreNegativeByteCount() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .milliseconds(200))
        window.record(byteCount: -100, transferDuration: .milliseconds(200), endedAt: time1)

        let time2 = base.advanced(by: .milliseconds(400))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: time2)

        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 10.0, accuracy: 0.001)
        }
    }

    func testIgnoreZeroDuration() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .milliseconds(200))
        window.record(byteCount: 250_000, transferDuration: .zero, endedAt: time1)

        let time2 = base.advanced(by: .milliseconds(400))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: time2)

        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 10.0, accuracy: 0.001)
        }
    }

    func testIgnoreNegativeDuration() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .milliseconds(200))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(-100), endedAt: time1)

        let time2 = base.advanced(by: .milliseconds(400))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: time2)

        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 10.0, accuracy: 0.001)
        }
    }

    func testPacedPattern() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let bytesPerSample = 256_000
        let durationPerSample = Duration.milliseconds(100)
        let spacingBetweenSamples = Duration.milliseconds(500)

        for i in 0 ..< 4 {
            let endTime = base.advanced(by: spacingBetweenSamples * i)
            window.record(
                byteCount: bytesPerSample, transferDuration: durationPerSample,
                endedAt: endTime
            )
        }

        let queryTime = base.advanced(by: spacingBetweenSamples * 3)
        let mbps = window.megabitsPerSecond(at: queryTime)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 20.48, accuracy: 0.01)
        }
    }

    func testEmptyWindow() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let mbps = window.megabitsPerSecond(at: base)
        XCTAssertNil(mbps)
    }

    func testMultipleSamplesWithinWindow() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .milliseconds(100))
        window.record(byteCount: 100_000, transferDuration: .milliseconds(100), endedAt: time1)

        let time2 = base.advanced(by: .milliseconds(200))
        window.record(byteCount: 100_000, transferDuration: .milliseconds(100), endedAt: time2)

        let time3 = base.advanced(by: .milliseconds(300))
        window.record(byteCount: 100_000, transferDuration: .milliseconds(100), endedAt: time3)

        let mbps = window.megabitsPerSecond(at: time3)
        XCTAssertNotNil(mbps)
        if let mbps {
            let totalBytes = 300_000
            let totalDuration = 0.3
            let expectedMbps = (Double(totalBytes) * 8) / (totalDuration * 1_000_000)
            XCTAssertEqual(mbps, expectedMbps, accuracy: 0.001)
        }
    }

    func testWindowBoundaryCondition() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .seconds(-2))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: time1)

        let time2 = base
        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNil(mbps)
    }

    func testSmallDurationLargeBytesHighMbps() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let endTime = base.advanced(by: .milliseconds(50))
        window.record(byteCount: 1_000_000, transferDuration: .milliseconds(50), endedAt: endTime)

        let mbps = window.megabitsPerSecond(at: endTime)
        XCTAssertNotNil(mbps)
        if let mbps {
            XCTAssertEqual(mbps, 160.0, accuracy: 0.1)
        }
    }
}
