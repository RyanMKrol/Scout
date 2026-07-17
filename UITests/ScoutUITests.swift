import XCTest

final class ScoutUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testFirstRunConsentFlow() {
        app.launchArguments = ["-firstRunConsentGiven", "NO"]
        app.launch()

        let consentStart = app.buttons["consent.start"]
        XCTAssertTrue(
            consentStart.waitForExistence(timeout: 15),
            "consent.start button should appear on first run"
        )

        let consentNotNow = app.buttons["consent.notNow"]
        XCTAssertTrue(
            consentNotNow.waitForExistence(timeout: 15),
            "consent.notNow button should appear on first run"
        )

        consentStart.tap()

        let measuringHero = app.staticTexts["measuring.hero"]
        XCTAssertTrue(
            measuringHero.waitForExistence(timeout: 15),
            "measuring.hero should appear after tapping Start"
        )
    }

    func testMeasuringScreenElements() {
        app.launchArguments = ["-firstRunConsentGiven", "YES", "-ScoutScenario", "Great"]
        app.launch()

        let measuringHero = app.staticTexts["measuring.hero"]
        XCTAssertTrue(
            measuringHero.waitForExistence(timeout: 15),
            "measuring.hero should appear with consent given"
        )

        let measuringUpload = app.staticTexts["measuring.upload"]
        XCTAssertTrue(
            measuringUpload.waitForExistence(timeout: 15),
            "measuring.upload should appear"
        )

        let measuringQuality = app.staticTexts["measuring.quality"]
        XCTAssertTrue(
            measuringQuality.waitForExistence(timeout: 15),
            "measuring.quality should appear"
        )

        let measuringDataDown = app.staticTexts["measuring.dataDown"]
        XCTAssertTrue(
            measuringDataDown.waitForExistence(timeout: 15),
            "measuring.dataDown should appear"
        )

        let measuringDataUp = app.staticTexts["measuring.dataUp"]
        XCTAssertTrue(
            measuringDataUp.waitForExistence(timeout: 15),
            "measuring.dataUp should appear"
        )
    }

    func testNoCellularState() {
        app.launchArguments = ["-firstRunConsentGiven", "YES", "-ScoutScenario", "None"]
        app.launch()

        let pausedTitle = app.staticTexts["paused.title"]
        XCTAssertTrue(
            pausedTitle.waitForExistence(timeout: 15),
            "paused.title should appear when cellular is unavailable"
        )

        let measuringQuality = app.staticTexts["measuring.quality"]
        XCTAssertFalse(
            measuringQuality.waitForExistence(timeout: 15),
            "measuring.quality should not exist when cellular is unavailable"
        )
    }

    func testDeclineThenStartFromIdle() {
        app.launchArguments = ["-firstRunConsentGiven", "NO"]
        app.launch()

        let consentNotNow = app.buttons["consent.notNow"]
        XCTAssertTrue(
            consentNotNow.waitForExistence(timeout: 15),
            "consent.notNow button should appear on first run"
        )

        consentNotNow.tap()

        let pausedStartButton = app.buttons["paused.startButton"]
        XCTAssertTrue(
            pausedStartButton.waitForExistence(timeout: 15),
            "paused.startButton should appear after declining consent"
        )

        pausedStartButton.tap()

        let measuringHero = app.staticTexts["measuring.hero"]
        XCTAssertTrue(
            measuringHero.waitForExistence(timeout: 15),
            "measuring.hero should appear after tapping start from idle"
        )
    }
}
