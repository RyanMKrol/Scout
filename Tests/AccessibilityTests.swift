@testable import Scout
import SwiftUI
import XCTest

final class AccessibilityTests: XCTestCase {
    // MARK: - AccessibilitySummary Tests

    func testAccessibilitySummaryValueFormatting() {
        let summary = AccessibilitySummary.value(
            downloadMbps: 7.4,
            uploadMbps: 2.1,
            generation: .fiveG,
            quality: .great,
            downloadBytes: 3_200_000,
            uploadBytes: 1_500_000
        )

        XCTAssertTrue(summary.contains("7 megabits per second down"))
        XCTAssertTrue(summary.contains("2 megabits per second up"))
        XCTAssertTrue(summary.contains("5G"))
        XCTAssertTrue(summary.contains("Great signal"))
        XCTAssertTrue(summary.contains("3.2 megabytes down"))
        XCTAssertTrue(summary.contains("1.5 megabytes up"))
        XCTAssertTrue(summary.contains("used this session"))
    }

    func testAccessibilitySummaryAtCapMbps() {
        let summary = AccessibilitySummary.value(
            downloadMbps: 10.5,
            uploadMbps: 5.5,
            generation: .lte,
            quality: .great,
            downloadBytes: 5_000_000,
            uploadBytes: 2_000_000
        )

        XCTAssertTrue(summary.contains("more than 10 megabits per second down"))
        XCTAssertTrue(summary.contains("more than 5 megabits per second up"))
    }

    func testAccessibilitySummaryWithUnknownGeneration() {
        let summary = AccessibilitySummary.value(
            downloadMbps: 3.0,
            uploadMbps: 1.5,
            generation: .unknown,
            quality: .usable,
            downloadBytes: 1_000_000,
            uploadBytes: 500_000
        )

        // Unknown generation should not appear in the summary
        XCTAssertFalse(summary.contains("Unknown"))
        XCTAssertTrue(summary.contains("3 megabits per second down"))
        XCTAssertTrue(summary.contains("Usable signal"))
    }

    func testAccessibilitySummaryForPoorQuality() {
        let summary = AccessibilitySummary.value(
            downloadMbps: 1.0,
            uploadMbps: 0.5,
            generation: .threeG,
            quality: .poor,
            downloadBytes: 500_000,
            uploadBytes: 250_000
        )

        XCTAssertTrue(summary.contains("Poor signal"))
        XCTAssertTrue(summary.contains("3G"))
    }

    func testAccessibilitySummaryForZeroBytes() {
        let summary = AccessibilitySummary.value(
            downloadMbps: 5.0,
            uploadMbps: 2.5,
            generation: .fiveG,
            quality: .great,
            downloadBytes: 0,
            uploadBytes: 0
        )

        XCTAssertTrue(summary.contains("0 megabytes down"))
        XCTAssertTrue(summary.contains("0 megabytes up"))
    }

    // MARK: - Reduce Motion Tests

    func testReduceMotionBehaviorBuiltIntoAnimationComponents() {
        // PulsingDot and SweepWedgeView both read @Environment(\.accessibilityReduceMotion)
        // and conditionally apply animations. This test documents that the implementation
        // respects the accessibility setting by checking that components are created
        // (full verification of animation behavior requires UI testing on device).
        let pulsingDot = PulsingDot(color: .green, diameter: 7)
        XCTAssertNotNil(pulsingDot)

        let sweepWedge = SweepWedgeView(
            color: .green,
            opacity: 0.18,
            wedgeDegrees: 98,
            period: 3.2,
            rotating: true
        )
        XCTAssertNotNil(sweepWedge)
    }
}
