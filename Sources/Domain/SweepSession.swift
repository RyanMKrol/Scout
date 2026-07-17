import Foundation
import Observation

@MainActor
@Observable
public final class SweepSession {
    private let sampler: any ThroughputSampling
    private let radio: any RadioInfoProviding
    private let path: any CellularPathMonitoring

    public private(set) var downloadMbps: Double = 0
    public private(set) var uploadMbps: Double = 0
    public private(set) var quality: SignalQuality = .init(downloadMbps: 0)
    public private(set) var generation: RadioGeneration = .unknown
    public private(set) var sessionDownloadBytes: Int64 = 0
    public private(set) var sessionUploadBytes: Int64 = 0
    public private(set) var cellularAvailable: Bool = true
    public private(set) var isMeasuring: Bool = false

    private var downloadWindow = ThroughputWindow(window: ThroughputWindow.liveWindow)
    private var uploadWindow = ThroughputWindow(window: ThroughputWindow.liveWindow)

    private var sampleTask: Task<Void, Never>?
    private var radioTask: Task<Void, Never>?
    private var pathTask: Task<Void, Never>?

    public init(
        sampler: any ThroughputSampling,
        radio: any RadioInfoProviding,
        path: any CellularPathMonitoring
    ) {
        self.sampler = sampler
        self.radio = radio
        self.path = path
    }

    public func start() {
        guard !isMeasuring else {
            return
        }
        isMeasuring = true

        if cellularAvailable {
            subscribeToSamples()
        }

        radioTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await generation in radio.generations() {
                self.generation = generation
            }
        }

        pathTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await available in path.availability() {
                handlePathUpdate(available: available)
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
        isMeasuring = false
    }

    private func handlePathUpdate(available: Bool) {
        cellularAvailable = available

        if available {
            if isMeasuring {
                subscribeToSamples()
            }
        } else {
            sampleTask?.cancel()
            sampleTask = nil
            downloadMbps = 0
            uploadMbps = 0
            quality = SignalQuality(downloadMbps: downloadMbps)
        }
    }

    private func subscribeToSamples() {
        sampleTask?.cancel()
        downloadWindow = ThroughputWindow(window: ThroughputWindow.liveWindow)
        uploadWindow = ThroughputWindow(window: ThroughputWindow.liveWindow)

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
    }
}
