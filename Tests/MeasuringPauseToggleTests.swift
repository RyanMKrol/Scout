@testable import Scout
import XCTest

/// Covers T044's dial pause/resume toggle. A driveable XCUITest belongs in UITests/, which is
/// out of this task's scope (Sources/Screens/**, Sources/DesignSystem/**, Sources/Domain/**,
/// Tests/**) — so per the task's documented fallback bar, this pins the wiring at the domain
/// layer instead: SweepSession.togglePause() (the call MeasuringView's dial tap gesture makes)
/// and AccessibilitySummary's paused-aware value.
private final class FakeThroughputSampler: ThroughputSampling, @unchecked Sendable {
    func samples() -> AsyncStream<ThroughputSample> {
        AsyncStream { _ in }
    }
}

private final class FakeRadioInfoProvider: RadioInfoProviding, @unchecked Sendable {
    func generations() -> AsyncStream<RadioGeneration> {
        AsyncStream { _ in }
    }
}

private final class FakeCellularPathMonitor: CellularPathMonitoring, @unchecked Sendable {
    func availability() -> AsyncStream<Bool> {
        AsyncStream { _ in }
    }
}

@MainActor
final class MeasuringPauseToggleTests: XCTestCase {
    func testTogglePauseFlipsIsPausedThenFlipsBackOnSecondTap() {
        let session = SweepSession(
            sampler: FakeThroughputSampler(),
            radio: FakeRadioInfoProvider(),
            path: FakeCellularPathMonitor()
        )
        session.start()
        XCTAssertFalse(session.isPaused)

        session.togglePause()
        XCTAssertTrue(session.isPaused, "First tap of the dial toggle should pause the session")

        session.togglePause()
        XCTAssertFalse(session.isPaused, "Second tap of the dial toggle should resume the session")

        session.stop()
    }

    func testToggleIsInertWhenSessionIsNotMeasuring() {
        // MeasuringView only wires the dial tap gesture into measuringContent(), which is shown
        // only when consentGiven && cellularAvailable — the same precondition under which the
        // session is running. Before the session starts (the empty-state path), a toggle call
        // must never enable pause.
        let session = SweepSession(
            sampler: FakeThroughputSampler(),
            radio: FakeRadioInfoProvider(),
            path: FakeCellularPathMonitor()
        )

        session.togglePause()

        XCTAssertFalse(session.isPaused)
        XCTAssertFalse(session.isMeasuring)
    }

    func testAccessibilityValueIsPausedAwareWhenPaused() {
        let liveValue = AccessibilitySummary.value(
            downloadMbps: 7.0,
            uploadMbps: 3.0,
            generation: .fiveG,
            quality: .great,
            downloadBytes: 1_000_000,
            uploadBytes: 500_000,
            isPaused: false
        )
        let pausedValue = AccessibilitySummary.value(
            downloadMbps: 7.0,
            uploadMbps: 3.0,
            generation: .fiveG,
            quality: .great,
            downloadBytes: 1_000_000,
            uploadBytes: 500_000,
            isPaused: true
        )

        XCTAssertFalse(liveValue.contains("Paused"))
        XCTAssertTrue(pausedValue.hasPrefix("Paused"))
        XCTAssertTrue(pausedValue.contains("7 megabits per second down"))
    }

    func testAccessibilityValueDefaultsToNotPaused() {
        let value = AccessibilitySummary.value(
            downloadMbps: 7.0,
            uploadMbps: 3.0,
            generation: .fiveG,
            quality: .great,
            downloadBytes: 1_000_000,
            uploadBytes: 500_000
        )

        XCTAssertFalse(value.contains("Paused"))
    }
}
