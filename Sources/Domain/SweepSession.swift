import Foundation
import Observation

@MainActor
@Observable
public final class SweepSession {
    /// How long a reading may go without a fresh sample before it's considered stale. Per T039:
    /// a dead spot must read as dead, not hold the last healthy number.
    public nonisolated static let stalenessThreshold: Duration = .milliseconds(900)
    /// How long the stale reading takes to fade to zero once past the threshold.
    public nonisolated static let stalenessDecayDuration: Duration = .milliseconds(1000)
    private nonisolated static let stalenessPollInterval: Duration = .milliseconds(100)
    /// The displayed reading's refresh cadence, decoupled from probe completion: ~4Hz per the
    /// design spec. Sourced from `ScoutMotion.tickInterval` so the two stay in lockstep.
    private nonisolated static let tickInterval: Duration = .seconds(ScoutMotion.tickInterval)

    private let sampler: any ThroughputSampling
    private let radio: any RadioInfoProviding
    private let path: any CellularPathMonitoring
    private let now: @Sendable () -> ContinuousClock.Instant

    public private(set) var downloadMbps: Double = 0
    public private(set) var uploadMbps: Double = 0
    public private(set) var quality: SignalQuality = .init(downloadMbps: 0)
    public private(set) var generation: RadioGeneration = .unknown
    public private(set) var sessionDownloadBytes: Int64 = 0
    public private(set) var sessionUploadBytes: Int64 = 0
    public private(set) var cellularAvailable: Bool = true
    public private(set) var isMeasuring: Bool = false
    public private(set) var isStalled: Bool = false
    public private(set) var isPaused: Bool = false

    private var downloadWindow = ThroughputWindow(window: ThroughputWindow.liveWindow)
    private var uploadWindow = ThroughputWindow(window: ThroughputWindow.liveWindow)

    private var lastSampleAt: ContinuousClock.Instant?
    private var downloadMbpsAtLastSample: Double = 0
    private var uploadMbpsAtLastSample: Double = 0

    private var sampleTask: Task<Void, Never>?
    private var radioTask: Task<Void, Never>?
    private var pathTask: Task<Void, Never>?
    private var stalenessTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

    public init(
        sampler: any ThroughputSampling,
        radio: any RadioInfoProviding,
        path: any CellularPathMonitoring,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now }
    ) {
        self.sampler = sampler
        self.radio = radio
        self.path = path
        self.now = now
    }

    public func start() {
        guard !isMeasuring else {
            return
        }
        isMeasuring = true

        if cellularAvailable {
            subscribeToSamples()
        }

        radioTask = startRadioTask()
        pathTask = startPathTask()
        stalenessTask = startPollingTask(interval: Self.stalenessPollInterval) { [weak self] in
            self?.evaluateStaleness()
        }
        tickTask = startPollingTask(interval: Self.tickInterval) { [weak self] in
            self?.republishFromWindow()
        }
    }

    private func startRadioTask() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else {
                return
            }
            for await generation in radio.generations() {
                self.generation = generation
            }
        }
    }

    private func startPathTask() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else {
                return
            }
            for await available in path.availability() {
                handlePathUpdate(available: available)
            }
        }
    }

    private func startPollingTask(interval: Duration, work: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else {
                    break
                }
                work()
            }
        }
    }

    public func stop() {
        sampleTask?.cancel()
        sampleTask = nil
        radioTask?.cancel()
        radioTask = nil
        pathTask?.cancel()
        pathTask = nil
        stalenessTask?.cancel()
        stalenessTask = nil
        tickTask?.cancel()
        tickTask = nil
        isMeasuring = false
        isStalled = false
        isPaused = false
        lastSampleAt = nil
    }

    /// Suspends sample consumption without stopping the session: the sampler subscription is
    /// torn down and the last-displayed download/upload/quality/generation values are held as a
    /// frozen snapshot rather than zeroed, distinct from stop()'s full teardown and from the
    /// no-cellular empty state.
    public func pause() {
        guard isMeasuring, !isPaused else {
            return
        }
        isPaused = true
        sampleTask?.cancel()
        sampleTask = nil
    }

    /// Resumes live updating after pause(), re-subscribing to samples exactly as start() does
    /// when cellular is available.
    public func resume() {
        guard isMeasuring, isPaused else {
            return
        }
        isPaused = false
        if cellularAvailable {
            subscribeToSamples()
        }
    }

    public func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    private func handlePathUpdate(available: Bool) {
        cellularAvailable = available

        if available {
            if isMeasuring, !isPaused {
                subscribeToSamples()
            }
        } else {
            sampleTask?.cancel()
            sampleTask = nil
            guard !isPaused else {
                return
            }
            downloadMbps = 0
            uploadMbps = 0
            quality = SignalQuality(downloadMbps: downloadMbps)
            isStalled = false
            lastSampleAt = nil
        }
    }

    private func subscribeToSamples() {
        sampleTask?.cancel()
        downloadWindow = ThroughputWindow(window: ThroughputWindow.liveWindow)
        uploadWindow = ThroughputWindow(window: ThroughputWindow.liveWindow)
        isStalled = false
        lastSampleAt = now()

        sampleTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await sample in sampler.samples() {
                record(sample)
            }
        }
    }

    private func record(_ sample: ThroughputSample) {
        switch sample.direction {
        case .download:
            downloadWindow.record(
                byteCount: sample.byteCount,
                transferDuration: sample.transferDuration,
                endedAt: sample.endedAt
            )
            let value = downloadWindow.megabitsPerSecond(at: sample.endedAt) ?? 0
            downloadMbps = min(value, ScoutMeter.downloadCapMbps)
            quality = SignalQuality(downloadMbps: downloadMbps)
            sessionDownloadBytes += Int64(sample.byteCount)
        case .upload:
            uploadWindow.record(
                byteCount: sample.byteCount,
                transferDuration: sample.transferDuration,
                endedAt: sample.endedAt
            )
            let value = uploadWindow.megabitsPerSecond(at: sample.endedAt) ?? 0
            uploadMbps = min(value, ScoutMeter.uploadCapMbps)
            sessionUploadBytes += Int64(sample.byteCount)
        }

        isStalled = false
        lastSampleAt = now()
        downloadMbpsAtLastSample = downloadMbps
        uploadMbpsAtLastSample = uploadMbps
    }

    /// Recomputes the rolling-window Mbps and republishes it, independent of probe arrival, so
    /// the displayed value eases as samples age out of the window rather than only updating once
    /// per probe. Skipped once `evaluateStaleness()` has taken over fading the reading to zero.
    private func republishFromWindow() {
        guard isMeasuring, cellularAvailable, !isStalled, !isPaused else {
            return
        }

        let at = now()

        if let value = downloadWindow.megabitsPerSecond(at: at) {
            downloadMbps = min(value, ScoutMeter.downloadCapMbps)
            quality = SignalQuality(downloadMbps: downloadMbps)
        }

        if let value = uploadWindow.megabitsPerSecond(at: at) {
            uploadMbps = min(value, ScoutMeter.uploadCapMbps)
        }
    }

    private func evaluateStaleness() {
        guard isMeasuring, cellularAvailable, !isPaused, let lastSampleAt else {
            return
        }

        let elapsed = now() - lastSampleAt
        guard elapsed > Self.stalenessThreshold else {
            isStalled = false
            return
        }

        isStalled = true
        let overage = elapsed - Self.stalenessThreshold
        let fraction = min(1.0, overage.timeInterval / Self.stalenessDecayDuration.timeInterval)
        downloadMbps = downloadMbpsAtLastSample * (1 - fraction)
        uploadMbps = uploadMbpsAtLastSample * (1 - fraction)
        quality = SignalQuality(downloadMbps: downloadMbps)
    }
}

private extension Duration {
    var timeInterval: Double {
        Double(components.seconds) + (Double(components.attoseconds) / 1e18)
    }
}
