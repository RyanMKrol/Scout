@testable import Scout
import XCTest

@MainActor
final class AppRouterTests: XCTestCase {
    func testFreshInstallFlow() {
        let router = AppRouter(consentGiven: false)

        // Start at splash
        XCTAssertEqual(router.phase, .splash)
        XCTAssertEqual(router.consentGiven, false)

        // Splash finishes → consent (because consentGiven is false)
        router.splashFinished()
        XCTAssertEqual(router.phase, .consent)
        XCTAssertEqual(router.consentGiven, false)

        // User grants consent → measuring
        router.startSweeping()
        XCTAssertEqual(router.phase, .measuring)
        XCTAssertEqual(router.consentGiven, true)
    }

    func testReturningUserFlow() {
        let router = AppRouter(consentGiven: true)

        // Start at splash
        XCTAssertEqual(router.phase, .splash)
        XCTAssertEqual(router.consentGiven, true)

        // Splash finishes → measuring (because consentGiven is true)
        router.splashFinished()
        XCTAssertEqual(router.phase, .measuring)
        XCTAssertEqual(router.consentGiven, true)
    }

    func testDeclinedConsentFlow() {
        let router = AppRouter(consentGiven: false)

        // Navigate to consent
        router.splashFinished()
        XCTAssertEqual(router.phase, .consent)

        // User declines consent
        router.declineConsent()
        XCTAssertEqual(router.phase, .measuring)
        XCTAssertEqual(router.consentGiven, false)

        // Later, user can grant consent from measuring screen
        router.startSweeping()
        XCTAssertEqual(router.phase, .measuring)
        XCTAssertEqual(router.consentGiven, true)
    }

    func testHoldSplashBehavior() {
        let router = AppRouter(consentGiven: false, holdSplash: true)

        // Start at splash
        XCTAssertEqual(router.phase, .splash)

        // splashFinished is a no-op when holdSplash is true
        router.splashFinished()
        XCTAssertEqual(router.phase, .splash)

        // Can still manually move to measuring if needed
        router.startSweeping()
        XCTAssertEqual(router.phase, .measuring)
    }

    func testHoldSplashWithConsentTrue() {
        let router = AppRouter(consentGiven: true, holdSplash: true)

        // Start at splash
        XCTAssertEqual(router.phase, .splash)

        // splashFinished is a no-op even when consentGiven is true
        router.splashFinished()
        XCTAssertEqual(router.phase, .splash)
    }

    func testSplashFinishedTwiceDoesNothing() {
        let router = AppRouter(consentGiven: false)

        // First call: splash → consent
        router.splashFinished()
        XCTAssertEqual(router.phase, .consent)

        // Second call: no-op (not on splash anymore)
        router.splashFinished()
        XCTAssertEqual(router.phase, .consent)
    }

    func testDeclineConsentFromMeasuringDoesNothing() {
        let router = AppRouter(consentGiven: false)

        // Navigate to measuring via decline
        router.splashFinished()
        router.declineConsent()
        XCTAssertEqual(router.phase, .measuring)

        // Try to decline again from measuring — no-op
        router.declineConsent()
        XCTAssertEqual(router.phase, .measuring)
        XCTAssertEqual(router.consentGiven, false)
    }

    func testStartSweepingFromMeasuring() {
        let router = AppRouter(consentGiven: false)

        // Get to measuring with no consent
        router.splashFinished()
        router.declineConsent()
        XCTAssertEqual(router.phase, .measuring)
        XCTAssertEqual(router.consentGiven, false)

        // User grants consent from measuring screen (idle state)
        router.startSweeping()
        XCTAssertEqual(router.phase, .measuring)
        XCTAssertEqual(router.consentGiven, true)
    }

    func testConsentGivenObservability() {
        let router = AppRouter(consentGiven: false)

        XCTAssertEqual(router.consentGiven, false)

        router.splashFinished()
        router.startSweeping()

        XCTAssertEqual(router.consentGiven, true)
    }

    func testStartSweepingAlwaysSetsConsent() {
        let router = AppRouter(consentGiven: true)

        // Navigate to consent (won't happen with consentGiven=true, but test it anyway)
        router.splashFinished()
        XCTAssertEqual(router.phase, .measuring)

        // Call startSweeping — ensures consent is true and phase is measuring
        router.startSweeping()
        XCTAssertEqual(router.phase, .measuring)
        XCTAssertEqual(router.consentGiven, true)
    }
}
