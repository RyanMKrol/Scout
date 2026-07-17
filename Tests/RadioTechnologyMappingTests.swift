import CoreTelephony
@testable import Scout
import XCTest

final class RadioTechnologyMappingTests: XCTestCase {
    func testFiveGNRTechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyNR
        )
        XCTAssertEqual(generation, .fiveG)
    }

    func testFiveGNRNSATechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyNRNSA
        )
        XCTAssertEqual(generation, .fiveG)
    }

    func testLTETechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyLTE
        )
        XCTAssertEqual(generation, .lte)
    }

    func testWCDMATechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyWCDMA
        )
        XCTAssertEqual(generation, .threeG)
    }

    func testHSDPATechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyHSDPA
        )
        XCTAssertEqual(generation, .threeG)
    }

    func testHSUPATechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyHSUPA
        )
        XCTAssertEqual(generation, .threeG)
    }

    func testCDMAEVDORev0Technology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyCDMAEVDORev0
        )
        XCTAssertEqual(generation, .threeG)
    }

    func testCDMAEVDORevATechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyCDMAEVDORevA
        )
        XCTAssertEqual(generation, .threeG)
    }

    func testCDMAEVDORevBTechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyCDMAEVDORevB
        )
        XCTAssertEqual(generation, .threeG)
    }

    func testEHRPDTechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyeHRPD
        )
        XCTAssertEqual(generation, .threeG)
    }

    func testGPRSTechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyGPRS
        )
        XCTAssertEqual(generation, .twoG)
    }

    func testEdgeTechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyEdge
        )
        XCTAssertEqual(generation, .twoG)
    }

    func testCDMA1xTechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: CTRadioAccessTechnologyCDMA1x
        )
        XCTAssertEqual(generation, .twoG)
    }

    func testNilRadioAccessTechnology() {
        let generation = RadioTechnologyMapping.generation(fromRadioAccessTechnology: nil)
        XCTAssertEqual(generation, .unknown)
    }

    func testUnrecognizedFutureTechnology() {
        let generation = RadioTechnologyMapping.generation(
            fromRadioAccessTechnology: "CTRadioAccessTechnologyFutureThing"
        )
        XCTAssertEqual(generation, .unknown)
    }
}
