import SwiftUI

private extension Color {
    /// Creates a color from a hex value in sRGB color space.
    /// - Parameter scoutHex: A 24-bit hex value (e.g., 0x63D99B).
    init(scoutHex: UInt32) {
        let r = Double((scoutHex >> 16) & 0xFF) / 255.0
        let g = Double((scoutHex >> 8) & 0xFF) / 255.0
        let b = Double(scoutHex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

/// Scout's design token namespace for colors and motion constants.
enum ScoutTheme {
    // MARK: - Colors

    /// Near-black background color for all screens.
    static let background = Color(scoutHex: 0x050506)

    /// Great signal quality indicator: vibrant green (oklch(0.80 0.14 158)).
    /// Also used as the brand primary accent (splash, icon, primary button).
    static let great = Color(scoutHex: 0x63D99B)

    /// Usable signal quality indicator: warm amber/gold (oklch(0.82 0.13 82)).
    static let usable = Color(scoutHex: 0xEEBB58)

    /// Poor signal quality indicator: muted terracotta/clay (oklch(0.70 0.10 30)).
    static let poor = Color(scoutHex: 0xD58679)

    /// Upload arc color in the measuring dial: calm cool blue (oklch(0.74 0.08 235)).
    /// Deliberately outside the quality-signal hues to keep color unambiguous.
    static let uploadArc = Color(scoutHex: 0x78B3D6)

    /// Upload text numerals in the measuring dial: slightly lighter cool blue (oklch(0.80 0.06 235)).
    /// Paired with uploadArc to maintain visual hierarchy without signaling quality.
    static let uploadText = Color(scoutHex: 0x99C5DF)

    /// Text color on the green primary button (start sweeping); near-black for contrast.
    static let onAccent = Color(scoutHex: 0x04140C)

    /// Helper to apply white text at a given opacity level.
    /// Used across the app for the handoff's opacity scale: 1.0/0.82/0.72/0.60/0.55/0.50/0.40/0.35/0.30/0.22.
    /// - Parameter opacity: A fractional opacity value (0.0 to 1.0).
    /// - Returns: White color at the specified opacity.
    static func white(_ opacity: Double) -> Color {
        Color.white.opacity(opacity)
    }
}

/// Scout's motion timing constants.
enum ScoutMotion {
    /// Splash screen radar sweep rotation period: 3.2s linear, infinite.
    /// Used for the rotating angular-gradient wedge behind the rings.
    static let splashSweepPeriod: Double = 3.2

    /// Measuring dial sweep rotation period: 3.4s linear, infinite.
    /// Used for the rotating angular-gradient wedge behind the download/upload arcs.
    static let dialSweepPeriod: Double = 3.4

    /// Status dot pulse animation period: 1.6s ease-in-out, infinite.
    /// Animates opacity and scale: 0.3/0.8 → 1/1 → 0.3/0.8 over one cycle.
    static let pulsePeriod: Double = 1.6

    /// Arc-length transition duration: 0.28s linear.
    /// Applied when the download or upload arc fills change to track Mbps changes.
    static let arcDuration: Double = 0.28

    /// Quality-color transition duration: 0.45s ease.
    /// Applied to the hero download number and download arc when quality band changes.
    static let colorDuration: Double = 0.45

    /// Throughput reading cadence: 0.25s (~4 Hz).
    /// The rolling-window Mbps is recomputed and pushed to the UI at this interval.
    static let tickInterval: Double = 0.25
}
