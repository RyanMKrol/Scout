@testable import Scout
import XCTest

@MainActor
final class AppEnvironmentTests: XCTestCase {
    private let key = "ScoutScenario"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testMissingKeyDefaultsToLive() {
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(AppEnvironment.scenario(), .live)
    }

    func testGarbageStringDefaultsToLive() {
        UserDefaults.standard.set("NotAScenario", forKey: key)
        XCTAssertEqual(AppEnvironment.scenario(), .live)
    }

    func testEachRawValueMapsToItsCase() {
        let cases: [(String, SimulationScenario)] = [
            ("Live", .live),
            ("Great", .great),
            ("Usable", .usable),
            ("Poor", .poor),
            ("None", .none),
        ]
        for (raw, expected) in cases {
            UserDefaults.standard.set(raw, forKey: key)
            XCTAssertEqual(AppEnvironment.scenario(), expected, "raw value \(raw)")
        }
    }

    func testMakeSessionReturnsWiredSession() {
        UserDefaults.standard.set("Great", forKey: key)
        let session = AppEnvironment.makeSession()
        XCTAssertNotNil(session)
    }
}
