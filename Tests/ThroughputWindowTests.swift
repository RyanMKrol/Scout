@testable import Scout
import XCTest

final class ThroughputWindowTests: XCTestCase {
    func testSteadyArrivalReportsWallClockRateRegardlessOfChunkDuration() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        // 50,000 bytes every 50ms, but each chunk claims a wildly different (irrelevant)
        // transfer duration — the wall-clock rate must ignore it entirely.
        let bytesPerSample = 50000
        let spacing = Duration.milliseconds(50)
        let chunkDurations: [Duration] = [.milliseconds(5), .milliseconds(900), .milliseconds(1)]
        let sampleCount = 21

        var time = base
        for i in 0 ..< sampleCount {
            time = base.advanced(by: spacing * i)
            window.record(
                byteCount: bytesPerSample,
                transferDuration: chunkDurations[i % chunkDurations.count],
                endedAt: time
            )
        }

        let mbps = window.megabitsPerSecond(at: time)
        XCTAssertNotNil(mbps)
        if let mbps {
            // B/Δt = 50,000 bytes / 0.05s = 1,000,000 bytes/s = 8 Mbps, independent of chunk duration.
            XCTAssertEqual(mbps, 8.0, accuracy: 0.5)
        }
    }

    func testSamplesOlderThanWindowAreEvicted() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: ThroughputWindow.liveWindow)

        let staleTime = base
        window.record(byteCount: 10_000_000, transferDuration: .milliseconds(1), endedAt: staleTime)

        let freshTime = base.advanced(by: ThroughputWindow.liveWindow + .milliseconds(100))
        window.record(byteCount: 62500, transferDuration: .milliseconds(50), endedAt: freshTime)

        let mbps = window.megabitsPerSecond(at: freshTime)
        XCTAssertNotNil(mbps)
        if let mbps {
            // Only the fresh sample remains: 62,500 bytes with a zero-elapsed span falls back to
            // the minimum divisor floor (50ms) — 0.5 megabits / 0.05s = 10 Mbps. If the huge stale
            // sample had leaked in, this would be orders of magnitude higher.
            XCTAssertEqual(mbps, 10.0, accuracy: 0.001)
        }
    }

    func testRateDropsToNilOnceArrivalsStopAndWindowElapses() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: ThroughputWindow.liveWindow)

        window.record(byteCount: 62500, transferDuration: .milliseconds(50), endedAt: base)

        let stillWithinWindow = base.advanced(by: ThroughputWindow.liveWindow / 2)
        XCTAssertNotNil(window.megabitsPerSecond(at: stillWithinWindow))

        let pastWindow = base.advanced(by: ThroughputWindow.liveWindow + .milliseconds(1))
        XCTAssertNil(window.megabitsPerSecond(at: pastWindow))
    }

    func testDefaultLiveWindowIsHalfASecond() {
        XCTAssertEqual(ThroughputWindow.liveWindow, .milliseconds(500))
    }

    func testOneMillionBytesOverHalfSecondReadsAbout16Mbps() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: ThroughputWindow.liveWindow)

        let spacing = Duration.milliseconds(10)
        var time = base
        for i in 0 ..< 50 {
            time = base.advanced(by: spacing * i)
            window.record(byteCount: 20000, transferDuration: .microseconds(1), endedAt: time)
        }

        let mbps = window.megabitsPerSecond(at: time)
        XCTAssertNotNil(mbps)
        if let mbps {
            // 1,000,000 bytes over ~0.49s elapsed (window is nearly fully warmed) = 8,000,000 bits
            // / ~0.49s / 1e6 ≈ 16 Mbps.
            XCTAssertEqual(mbps, 16.0, accuracy: 1.0)
        }
    }

    func testEmptyWindowReturnsNil() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let mbps = window.megabitsPerSecond(at: base)
        XCTAssertNil(mbps)
    }

    func testIgnoreZeroByteCount() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .milliseconds(200))
        window.record(byteCount: 0, transferDuration: .milliseconds(200), endedAt: time1)

        let time2 = base.advanced(by: .milliseconds(700))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: time2)

        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNotNil(mbps)
    }

    func testIgnoreNegativeByteCount() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .milliseconds(200))
        window.record(byteCount: -100, transferDuration: .milliseconds(200), endedAt: time1)

        let time2 = base.advanced(by: .milliseconds(700))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: time2)

        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNotNil(mbps)
    }

    func testWindowBoundaryConditionEvictsExactlyAtCutoff() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: .seconds(2))

        let time1 = base.advanced(by: .seconds(-2))
        window.record(byteCount: 250_000, transferDuration: .milliseconds(200), endedAt: time1)

        let time2 = base
        let mbps = window.megabitsPerSecond(at: time2)
        XCTAssertNil(mbps)
    }

    func testStepChangeInThroughputIsReflectedWithinOneWindowSpan() {
        let base = ContinuousClock().now
        var window = ThroughputWindow(window: ThroughputWindow.liveWindow)

        let preStepSpacing = Duration.milliseconds(100)
        var time = base
        for i in 0 ..< 5 {
            time = base.advanced(by: preStepSpacing * i)
            window.record(byteCount: 12500, transferDuration: .milliseconds(100), endedAt: time)
        }

        // Step change to much faster throughput; sample densely and for far longer than the
        // 500ms window so the pre-step samples fully evict and the window saturates with
        // post-step-only samples.
        let stepStart = time
        let postStepSpacing = Duration.milliseconds(10)
        let samplesAfterStep = 60
        for i in 1 ... samplesAfterStep {
            time = stepStart.advanced(by: postStepSpacing * i)
            window.record(byteCount: 125_000, transferDuration: .milliseconds(10), endedAt: time)
        }

        let mbps = window.megabitsPerSecond(at: time)
        XCTAssertNotNil(mbps)
        if let mbps {
            // 125,000 bytes/10ms ideally is 100 Mbps; the finite window edge inflates it slightly.
            XCTAssertEqual(mbps, 100.0, accuracy: 5.0)
        }
    }
}
