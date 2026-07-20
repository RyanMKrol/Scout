import Foundation

public enum ScoutMeter {
    /// Upper end of the dial's log scale — real cellular throughput can exceed this, in which
    /// case the arc simply pins at 1.0 rather than the reading itself being capped.
    public nonisolated static let downloadScaleMbps = 300.0
    public nonisolated static let uploadScaleMbps = 100.0

    public nonisolated static func downloadDisplay(_ mbps: Double) -> String {
        formattedMbps(mbps)
    }

    public nonisolated static func uploadDisplay(_ mbps: Double) -> String {
        formattedMbps(mbps)
    }

    /// One decimal place below 10 Mbps, a rounded whole number at/above it — precision that
    /// matters at slow speeds is just noise once the reading is well into double digits.
    private nonisolated static func formattedMbps(_ mbps: Double) -> String {
        let normalized = mbps < 0 ? 0.0 : mbps
        let roundedTenths = (normalized * 10).rounded() / 10
        if roundedTenths < 10.0 {
            return String(format: "%.1f", roundedTenths)
        }
        return String(format: "%.0f", normalized.rounded())
    }

    public nonisolated static func megabytesDisplay(bytes: Int64) -> String {
        let mb = Double(bytes) / 1_000_000
        if mb < 10 {
            return String(format: "%.1f MB", mb)
        }
        return String(format: "%.0f MB", mb.rounded())
    }

    public nonisolated static func downloadArcFraction(_ mbps: Double) -> Double {
        arcFraction(mbps, scaleMbps: downloadScaleMbps)
    }

    public nonisolated static func uploadArcFraction(_ mbps: Double) -> Double {
        arcFraction(mbps, scaleMbps: uploadScaleMbps)
    }

    private nonisolated static func arcFraction(_ mbps: Double, scaleMbps: Double) -> Double {
        let normalized = mbps <= 0 ? 0.0 : mbps
        let logValue = log10(normalized + 1) / log10(scaleMbps + 1)
        return max(0.04, min(logValue, 1.0))
    }
}
