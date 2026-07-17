import Foundation

public enum ScoutMeter {
    public nonisolated static let downloadCapMbps = 10.0
    public nonisolated static let uploadCapMbps = 5.0

    public nonisolated static func downloadDisplay(_ mbps: Double) -> String {
        let normalized = mbps < 0 ? 0.0 : mbps
        let rounded = (normalized * 10).rounded() / 10
        if rounded >= 10.0 {
            return "10+"
        }
        return String(format: "%.1f", rounded)
    }

    public nonisolated static func uploadDisplay(_ mbps: Double) -> String {
        let normalized = mbps < 0 ? 0.0 : mbps
        let rounded = (normalized * 10).rounded() / 10
        if rounded >= 5.0 {
            return "5+"
        }
        return String(format: "%.1f", rounded)
    }

    public nonisolated static func megabytesDisplay(bytes: Int64) -> String {
        let mb = Double(bytes) / 1_000_000
        if mb < 10 {
            return String(format: "%.1f MB", mb)
        }
        return String(format: "%.0f MB", mb.rounded())
    }

    public nonisolated static func downloadArcFraction(_ mbps: Double) -> Double {
        let normalized = mbps <= 0 ? 0.0 : mbps
        let capped = min(normalized, 10)
        let logValue = log10(capped + 1) / log10(11)
        return max(0.04, min(logValue, 1.0))
    }

    public nonisolated static func uploadArcFraction(_ mbps: Double) -> Double {
        let normalized = mbps <= 0 ? 0.0 : mbps
        let capped = min(normalized, 5)
        let logValue = log10(capped + 1) / log10(6)
        return max(0.04, min(logValue, 1.0))
    }
}
