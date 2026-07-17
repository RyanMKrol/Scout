public enum SignalQuality: Sendable {
    case great
    case usable
    case poor

    public nonisolated init(downloadMbps: Double) {
        if downloadMbps >= 6.0 {
            self = .great
        } else if downloadMbps >= 2.0 {
            self = .usable
        } else {
            self = .poor
        }
    }

    public nonisolated static let greatThresholdMbps = 6.0
    public nonisolated static let usableThresholdMbps = 2.0
}

extension SignalQuality: Equatable {
    public nonisolated static func == (lhs: SignalQuality, rhs: SignalQuality) -> Bool {
        switch (lhs, rhs) {
        case (.great, .great), (.usable, .usable), (.poor, .poor):
            true
        default:
            false
        }
    }
}
