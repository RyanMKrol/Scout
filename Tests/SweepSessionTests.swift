@testable import Scout
import XCTest

private final class FakeThroughputSampler: ThroughputSampling, @unchecked Sendable {
    private(set) var subscribeCount = 0
    private(set) var terminatedCount = 0
    private var continuation: AsyncStream<ThroughputSample>.Continuation?

    func samples() -> AsyncStream<ThroughputSample> {
        subscribeCount += 1
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.terminatedCount += 1
            }
        }
    }

    func yield(_ sample: ThroughputSample) {
        continuation?.yield(sample)
    }
}

private final class FakeRadioInfoProvider: RadioInfoProviding, @unchecked Sendable {
    private var continuation: AsyncStream<RadioGeneration>.Continuation?

    func generations() -> AsyncStream<RadioGeneration> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func yield(_ generation: RadioGeneration) {
        continuation?.yield(generation)
    }
}

private final class FakeCellularPathMonitor: CellularPathMonitoring, @unchecked Sendable {
    private var continuation: AsyncStream<Bool>.Continuation?

    func availability() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func yield(_ available: Bool) {
        continuation?.yield(available)
    }
}

private final class ManualClock: @unchecked Sendable {
    private let lock = NSLock()
    private var instant: ContinuousClock.Instant

    init(start: ContinuousClock.Instant = ContinuousClock().now) {
        instant = start
    }

    func now() -> ContinuousClock.Instant {
        lock.lock()
        defer { lock.unlock() }
        return instant
    }

    func advance(by duration: Duration) {
        lock.lock()
        instant = instant.advanced(by: duration)
        lock.unlock()
    }
}

@MainActor
final class SweepSessionTests: XCTestCase {
    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: Duration = .seconds(2)
    ) async {
        let deadline = ContinuousClock().now.advanced(by: timeout)
        while !condition(), ContinuousClock().now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testDownloadSampleCapsAndUpdatesQualityAndBytes() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let session = SweepSession(sampler: sampler, radio: radio, path: path)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }
        let endedAt = ContinuousClock().now
        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 250_000, transferDuration: .milliseconds(200),
                endedAt: endedAt
            )
        )

        await waitUntil { session.downloadMbps > 0 }

        XCTAssertEqual(session.downloadMbps, 10.0, accuracy: 0.001)
        XCTAssertEqual(session.quality, .great)
        XCTAssertEqual(session.sessionDownloadBytes, 250_000)
        XCTAssertEqual(session.sessionUploadBytes, 0)
        XCTAssertEqual(session.uploadMbps, 0)

        session.stop()
    }

    func testUploadSampleLandsInUploadOnlyAndIsCapped() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let session = SweepSession(sampler: sampler, radio: radio, path: path)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }
        let endedAt = ContinuousClock().now
        sampler.yield(
            ThroughputSample(
                direction: .upload, byteCount: 1_000_000, transferDuration: .milliseconds(200),
                endedAt: endedAt
            )
        )

        await waitUntil { session.uploadMbps > 0 }

        XCTAssertEqual(session.uploadMbps, ScoutMeter.uploadCapMbps, accuracy: 0.001)
        XCTAssertEqual(session.sessionUploadBytes, 1_000_000)
        XCTAssertEqual(session.sessionDownloadBytes, 0)
        XCTAssertEqual(session.downloadMbps, 0)

        session.stop()
    }

    func testByteCountersAccumulateAcrossMultipleSamplesSplitByDirection() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let session = SweepSession(sampler: sampler, radio: radio, path: path)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }
        let base = ContinuousClock().now
        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 100_000, transferDuration: .milliseconds(100),
                endedAt: base.advanced(by: .milliseconds(100))
            )
        )
        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 50000, transferDuration: .milliseconds(100),
                endedAt: base.advanced(by: .milliseconds(200))
            )
        )
        sampler.yield(
            ThroughputSample(
                direction: .upload, byteCount: 20000, transferDuration: .milliseconds(100),
                endedAt: base.advanced(by: .milliseconds(300))
            )
        )

        await waitUntil { session.sessionDownloadBytes == 150_000 && session.sessionUploadBytes == 20000 }

        XCTAssertEqual(session.sessionDownloadBytes, 150_000)
        XCTAssertEqual(session.sessionUploadBytes, 20000)

        session.stop()
    }

    func testStopTerminatesSamplerStreamAndClearsIsMeasuring() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let session = SweepSession(sampler: sampler, radio: radio, path: path)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }

        session.stop()

        await waitUntil { sampler.terminatedCount == 1 }

        XCTAssertEqual(sampler.terminatedCount, 1)
        XCTAssertFalse(session.isMeasuring)
    }

    func testCellularUnavailableStopsSamplerAndZeroesReadings() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let session = SweepSession(sampler: sampler, radio: radio, path: path)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }

        let endedAt = ContinuousClock().now
        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 250_000, transferDuration: .milliseconds(200),
                endedAt: endedAt
            )
        )
        await waitUntil { session.downloadMbps > 0 }

        path.yield(false)
        await waitUntil { !session.cellularAvailable }

        XCTAssertFalse(session.cellularAvailable)
        await waitUntil { session.downloadMbps == 0 }
        XCTAssertEqual(session.downloadMbps, 0)
        XCTAssertEqual(session.uploadMbps, 0)

        await waitUntil { sampler.terminatedCount == 1 }
        XCTAssertEqual(sampler.terminatedCount, 1)

        session.stop()
    }

    func testStalledSampleDecaysReadingAndClearsOnFreshSample() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let clock = ManualClock()
        let session = SweepSession(sampler: sampler, radio: radio, path: path, now: clock.now)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }

        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 250_000, transferDuration: .milliseconds(200),
                endedAt: ContinuousClock().now
            )
        )
        await waitUntil { session.downloadMbps > 0 }
        XCTAssertEqual(session.downloadMbps, 10.0, accuracy: 0.001)
        XCTAssertFalse(session.isStalled)

        // No fresh sample arrives: advance the injected clock well past the staleness
        // threshold + decay window so the reading must fall fully to zero.
        clock.advance(by: SweepSession.stalenessThreshold + SweepSession.stalenessDecayDuration)
        await waitUntil { session.isStalled }

        XCTAssertTrue(session.isStalled)
        await waitUntil { session.downloadMbps == 0 }
        XCTAssertEqual(session.downloadMbps, 0)

        // A fresh sample immediately clears the stalled state.
        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 250_000, transferDuration: .milliseconds(200),
                endedAt: ContinuousClock().now
            )
        )
        await waitUntil { !session.isStalled }
        XCTAssertFalse(session.isStalled)
        XCTAssertEqual(session.downloadMbps, 10.0, accuracy: 0.001)

        session.stop()
    }

    func testTickRepublishesFromWindowBetweenProbesAndStopsAfterStop() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let clock = ManualClock()
        let session = SweepSession(sampler: sampler, radio: radio, path: path, now: clock.now)
        let start = clock.now()

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }

        // Two samples land close together: an older one at `start` and a newer one 200ms later.
        // Both are resident in the (500ms) wall-clock window, so the published rate is their
        // combined bytes divided by the elapsed span since the older sample.
        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 12500, transferDuration: .milliseconds(100),
                endedAt: start
            )
        )
        await waitUntil { session.downloadMbps > 0 }

        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 137_500, transferDuration: .milliseconds(100),
                endedAt: start.advanced(by: .milliseconds(200))
            )
        )
        // (12500 + 137500) bytes × 8 / 1e6 / 0.2s elapsed = 6.0 Mbps.
        await waitUntil { session.downloadMbps > 2.0 }
        XCTAssertEqual(session.downloadMbps, 6.0, accuracy: 0.001)

        // No new probe arrives. Advance the injected clock to 600ms since `start` (well under the
        // staleness threshold) so the older sample ages out of the window; the next tick should
        // recompute from the window's remaining sample and republish, without any fresh probe.
        clock.advance(by: .milliseconds(600))
        XCTAssertLessThan(clock.now() - start, SweepSession.stalenessThreshold)

        // Only the second sample remains: 137,500 bytes × 8 / 1e6 / 0.4s elapsed = 2.75 Mbps.
        // (The combined 6.0 reading above may land as 5.999999999999999 due to floating-point
        // rounding, so compare against a threshold well clear of it rather than < 6.0.)
        await waitUntil { session.downloadMbps < 5.5 }
        XCTAssertEqual(session.downloadMbps, 2.75, accuracy: 0.001)
        XCTAssertFalse(session.isStalled)

        session.stop()

        // Once stopped, the tick must be torn down: advancing well past the window again and
        // waiting must NOT change the published value any further.
        clock.advance(by: .milliseconds(650))
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(session.downloadMbps, 2.75, accuracy: 0.001)
    }

    func testContinuousChunkStreamKeepsLiveReadingAndStalenessOnlyFiresOnGenuineGap() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let clock = ManualClock()
        let session = SweepSession(sampler: sampler, radio: radio, path: path, now: clock.now)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }

        // Simulate a continuous streaming sampler: many small chunks landing close together,
        // like T045's per-chunk emission, rather than one or two discrete probes.
        let chunkBytes = 2500
        let chunkInterval = Duration.milliseconds(50)
        for _ in 0 ..< 10 {
            sampler.yield(
                ThroughputSample(
                    direction: .download, byteCount: chunkBytes, transferDuration: .zero,
                    endedAt: clock.now()
                )
            )
            clock.advance(by: chunkInterval)
            try? await Task.sleep(for: .milliseconds(5))
        }

        await waitUntil { session.downloadMbps > 0 }
        XCTAssertFalse(session.isStalled)
        XCTAssertEqual(session.sessionDownloadBytes, Int64(chunkBytes * 10))

        // A brief gap well under the staleness threshold must NOT collapse the reading to zero:
        // the wall-clock window keeps reporting a live rate on the 250ms display tick, recomputed
        // from the window rather than only from the last `record()` call.
        clock.advance(by: .milliseconds(300))
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertFalse(session.isStalled)
        XCTAssertGreaterThan(session.downloadMbps, 0)

        // Chunks genuinely stop arriving: advance the injected clock well past the stall
        // threshold plus the decay window. Only now must isStalled fire and the reading decay
        // fully to zero — a true "dead spot", not a firing between normal continuous reads.
        clock.advance(by: SweepSession.stalenessThreshold + SweepSession.stalenessDecayDuration)
        await waitUntil { session.isStalled }
        XCTAssertTrue(session.isStalled)
        await waitUntil { session.downloadMbps == 0 }
        XCTAssertEqual(session.downloadMbps, 0)

        session.stop()
    }

    func testCellularAvailableAgainResubscribesSampler() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let session = SweepSession(sampler: sampler, radio: radio, path: path)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }

        path.yield(false)
        await waitUntil { sampler.terminatedCount == 1 }

        path.yield(true)
        await waitUntil { sampler.subscribeCount == 2 }

        XCTAssertEqual(sampler.subscribeCount, 2)
        XCTAssertTrue(session.cellularAvailable)

        session.stop()
    }

    func testPauseFreezesReadingAndResumeRestoresLiveUpdating() async {
        let sampler = FakeThroughputSampler()
        let radio = FakeRadioInfoProvider()
        let path = FakeCellularPathMonitor()
        let session = SweepSession(sampler: sampler, radio: radio, path: path)

        session.start()
        await waitUntil { sampler.subscribeCount == 1 }

        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 25000, transferDuration: .milliseconds(200),
                endedAt: ContinuousClock().now
            )
        )
        await waitUntil { session.downloadMbps > 0 }
        let frozenValue = session.downloadMbps
        // A single sample with a near-zero elapsed span falls back to the minimum divisor floor
        // (50ms): 25,000 bytes × 8 / 1e6 / 0.05s = 4.0 Mbps.
        XCTAssertEqual(frozenValue, 4.0, accuracy: 0.001)

        session.pause()
        XCTAssertTrue(session.isPaused)
        await waitUntil { sampler.terminatedCount == 1 }
        XCTAssertEqual(sampler.terminatedCount, 1)

        // A sample yielded after pause must not reach the (torn-down) subscription, and the
        // displayed value must stay frozen at its last value.
        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 900_000, transferDuration: .milliseconds(200),
                endedAt: ContinuousClock().now
            )
        )
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(session.downloadMbps, frozenValue, accuracy: 0.001)
        XCTAssertTrue(session.isMeasuring)

        session.resume()
        XCTAssertFalse(session.isPaused)
        await waitUntil { sampler.subscribeCount == 2 }

        sampler.yield(
            ThroughputSample(
                direction: .download, byteCount: 900_000, transferDuration: .milliseconds(200),
                endedAt: ContinuousClock().now
            )
        )
        await waitUntil { session.downloadMbps > frozenValue }
        XCTAssertGreaterThan(session.downloadMbps, frozenValue)

        session.stop()
    }
}
