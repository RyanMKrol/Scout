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
}
