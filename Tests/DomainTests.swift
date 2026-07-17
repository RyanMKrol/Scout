@testable import Scout
import XCTest

final class DomainTests: XCTestCase {
    // MARK: - RadioGeneration Tests

    func testRadioGenerationRawValues() {
        XCTAssertEqual(RadioGeneration.fiveG.rawValue, "5G")
        XCTAssertEqual(RadioGeneration.lte.rawValue, "LTE")
        XCTAssertEqual(RadioGeneration.threeG.rawValue, "3G")
        XCTAssertEqual(RadioGeneration.twoG.rawValue, "2G")
        XCTAssertEqual(RadioGeneration.unknown.rawValue, "")
    }

    func testRadioGenerationEquality() {
        XCTAssertEqual(RadioGeneration.fiveG, RadioGeneration.fiveG)
        XCTAssertNotEqual(RadioGeneration.fiveG, RadioGeneration.lte)
    }

    // MARK: - SignalQuality Tests

    func testSignalQualityThresholds() {
        let testCases: [(Double, SignalQuality)] = [
            (6.0, .great),
            (7.0, .great),
            (10.0, .great),
            (5.99, .usable),
            (2.0, .usable),
            (5.0, .usable),
            (1.99, .poor),
            (1.0, .poor),
            (0.0, .poor),
            (-1.0, .poor),
        ]

        for (mbps, expectedQuality) in testCases {
            let quality = SignalQuality(downloadMbps: mbps)
            XCTAssertEqual(
                quality, expectedQuality,
                "SignalQuality for \(mbps) Mbps should be \(expectedQuality)"
            )
        }
    }

    func testSignalQualityThresholdConstants() {
        XCTAssertEqual(SignalQuality.greatThresholdMbps, 6.0)
        XCTAssertEqual(SignalQuality.usableThresholdMbps, 2.0)
    }

    // MARK: - ScoutMeter Download Display Tests

    func testDownloadDisplay() {
        let testCases: [(Double, String)] = [
            (0, "0.0"),
            (7.42, "7.4"),
            (9.94, "9.9"),
            (9.95, "10+"),
            (12, "10+"),
            (-1.0, "0.0"),
            (-5.5, "0.0"),
            (1.0, "1.0"),
            (2.5, "2.5"),
            (5.0, "5.0"),
            (9.999, "10+"),
            (10.0, "10+"),
            (100.0, "10+"),
        ]

        for (mbps, expectedDisplay) in testCases {
            let display = ScoutMeter.downloadDisplay(mbps)
            XCTAssertEqual(
                display, expectedDisplay,
                "downloadDisplay for \(mbps) should be \(expectedDisplay)"
            )
        }
    }

    // MARK: - ScoutMeter Upload Display Tests

    func testUploadDisplay() {
        let testCases: [(Double, String)] = [
            (0, "0.0"),
            (4.94, "4.9"),
            (4.95, "5+"),
            (7, "5+"),
            (-1.0, "0.0"),
            (-5.5, "0.0"),
            (1.0, "1.0"),
            (2.5, "2.5"),
            (5.0, "5+"),
            (4.999, "5+"),
            (6.0, "5+"),
            (100.0, "5+"),
        ]

        for (mbps, expectedDisplay) in testCases {
            let display = ScoutMeter.uploadDisplay(mbps)
            XCTAssertEqual(
                display, expectedDisplay,
                "uploadDisplay for \(mbps) should be \(expectedDisplay)"
            )
        }
    }

    // MARK: - ScoutMeter Megabytes Display Tests

    func testMegabytesDisplay() {
        let testCases: [(Int64, String)] = [
            (0, "0.0 MB"),
            (3_200_000, "3.2 MB"),
            (14_000_000, "14 MB"),
            (9_940_000, "9.9 MB"),
            (1_000_000, "1.0 MB"),
            (5_500_000, "5.5 MB"),
            (10_000_000, "10 MB"),
            (100_000_000, "100 MB"),
            (1_500_000, "1.5 MB"),
            (9_500_000, "9.5 MB"),
        ]

        for (bytes, expectedDisplay) in testCases {
            let display = ScoutMeter.megabytesDisplay(bytes: bytes)
            XCTAssertEqual(
                display, expectedDisplay,
                "megabytesDisplay for \(bytes) bytes should be \(expectedDisplay)"
            )
        }
    }

    // MARK: - ScoutMeter Download Arc Fraction Tests

    func testDownloadArcFraction() {
        let testCases: [(Double, Double)] = [
            (0, 0.04),
            (10, 1.0),
            (12, 1.0),
            (100, 1.0),
            (-1, 0.04),
            (-100, 0.04),
        ]

        for (mbps, expectedFraction) in testCases {
            let fraction = ScoutMeter.downloadArcFraction(mbps)
            XCTAssertEqual(
                fraction, expectedFraction, accuracy: 0.001,
                "downloadArcFraction for \(mbps) should be \(expectedFraction)"
            )
        }
    }

    func testDownloadArcFractionMonotonicallyIncreasing() {
        let samples = [0.5, 1.0, 2.0, 5.0, 10.0]
        var previousFraction: Double?

        for sample in samples {
            let fraction = ScoutMeter.downloadArcFraction(sample)
            if let prev = previousFraction {
                XCTAssertLessThanOrEqual(
                    prev, fraction,
                    "downloadArcFraction should be monotonically increasing; \(prev) > \(fraction) for sample \(sample)"
                )
            }
            previousFraction = fraction
        }
    }

    // MARK: - ScoutMeter Upload Arc Fraction Tests

    func testUploadArcFraction() {
        let testCases: [(Double, Double)] = [
            (0, 0.04),
            (5, 1.0),
            (7, 1.0),
            (100, 1.0),
            (-1, 0.04),
            (-100, 0.04),
        ]

        for (mbps, expectedFraction) in testCases {
            let fraction = ScoutMeter.uploadArcFraction(mbps)
            XCTAssertEqual(
                fraction, expectedFraction, accuracy: 0.001,
                "uploadArcFraction for \(mbps) should be \(expectedFraction)"
            )
        }
    }

    func testUploadArcFractionMonotonicallyIncreasing() {
        let samples = [0.5, 1.0, 2.0, 5.0, 7.0]
        var previousFraction: Double?

        for sample in samples {
            let fraction = ScoutMeter.uploadArcFraction(sample)
            if let prev = previousFraction {
                XCTAssertLessThanOrEqual(
                    prev, fraction,
                    "uploadArcFraction should be monotonically increasing; \(prev) > \(fraction) for sample \(sample)"
                )
            }
            previousFraction = fraction
        }
    }

    // MARK: - ScoutMeter Constants

    func testScoutMeterConstants() {
        XCTAssertEqual(ScoutMeter.downloadCapMbps, 10.0)
        XCTAssertEqual(ScoutMeter.uploadCapMbps, 5.0)
    }
}
