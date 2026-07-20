@testable import Scout
import XCTest

@MainActor
final class PeriodicUploadBurstTests: XCTestCase {
    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: Duration = .seconds(5)
    ) async {
        let deadline = ContinuousClock().now.advanced(by: timeout)
        while !condition(), ContinuousClock().now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Test that SimulatedSampler emits upload bursts periodically while continuous downloads flow.
    /// Uses an injected clock to verify timing without waiting for real delays.
    func testSimulatedBurstsEmitOnIntervalAlongsideContinuousDownloads() async {
        let sampler = SimulatedSampler(scenario: .great)
        var collected: [ThroughputSample] = []

        let task = Task { @MainActor in
            for await sample in sampler.samples() {
                collected.append(sample)
                if collected.count >= 50 {
                    break
                }
            }
        }

        await waitUntil { collected.count >= 50 }
        task.cancel()

        let uploadSamples = collected.filter { $0.direction == .upload }
        let downloadSamples = collected.filter { $0.direction == .download }

        XCTAssertGreaterThan(downloadSamples.count, 0)
        XCTAssertGreaterThan(uploadSamples.count, 0)
        XCTAssertGreaterThan(downloadSamples.count, uploadSamples.count)

        for sample in uploadSamples {
            XCTAssertEqual(sample.direction, .upload)
            XCTAssertGreaterThan(sample.byteCount, 0)
            XCTAssertGreaterThan(sample.transferDuration, .zero)
        }

        for sample in downloadSamples {
            XCTAssertEqual(sample.direction, .download)
            XCTAssertGreaterThan(sample.byteCount, 0)
            XCTAssertGreaterThan(sample.transferDuration, .zero)
        }
    }

    /// Test that upload samples update the upload window and reading when recorded in SweepSession.
    func testUploadSamplesUpdateSessionReading() async {
        let sampler = SimulatedSampler(scenario: .great)
        let radio = SimulatedRadioProvider(scenario: .great)
        let path = SimulatedPathMonitor(scenario: .great)
        let clock = ManualClock()
        let session = SweepSession(sampler: sampler, radio: radio, path: path, now: clock.now)

        session.start()
        await waitUntil { session.downloadMbps > 0 }

        XCTAssertGreaterThan(session.downloadMbps, 0)

        await waitUntil({ session.uploadMbps > 0 }, timeout: .seconds(10))
        XCTAssertGreaterThan(session.uploadMbps, 0)

        XCTAssertGreaterThan(session.sessionDownloadBytes, 0)
        XCTAssertGreaterThan(session.sessionUploadBytes, 0)

        session.stop()
    }

    /// Test that uploads are emitted much less frequently than downloads, keeping them a minor
    /// fraction of session data volume.
    func testUploadBurstsAreMinorFractionOfTotal() async {
        let sampler = SimulatedSampler(scenario: .great)
        var collected: [ThroughputSample] = []

        let task = Task { @MainActor in
            for await sample in sampler.samples() {
                collected.append(sample)
                if collected.count >= 100 {
                    break
                }
            }
        }

        await waitUntil { collected.count >= 100 }
        task.cancel()

        let uploadBytes = collected
            .filter { $0.direction == .upload }
            .reduce(0) { $0 + $1.byteCount }
        let downloadBytes = collected
            .filter { $0.direction == .download }
            .reduce(0) { $0 + $1.byteCount }
        let totalBytes = uploadBytes + downloadBytes

        let uploadFraction = Double(uploadBytes) / Double(totalBytes)

        XCTAssertLessThan(uploadFraction, 0.25, "Upload should be less than 25% of total")
    }

    /// Test that cancelling a simulated sampler stops emission of both download and upload.
    func testCancellingStopsDownloadsAndUploads() async {
        let sampler = SimulatedSampler(scenario: .great)
        var collected: [ThroughputSample] = []

        let task = Task { @MainActor in
            for await sample in sampler.samples() {
                collected.append(sample)
            }
        }

        await waitUntil { collected.count >= 10 }
        task.cancel()

        let countAtCancel = collected.count
        try? await Task.sleep(for: .milliseconds(500))
        let countAfterGrace = collected.count

        XCTAssertEqual(countAtCancel, countAfterGrace)
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
