@testable import Scout
import XCTest

final class AccessibilitySummaryTests: XCTestCase {
    func testNormalValues() {
        let result = AccessibilitySummary.value(
            downloadMbps: 7.4,
            uploadMbps: 3.2,
            generation: .fiveG,
            quality: .usable,
            downloadBytes: 14_000_000,
            uploadBytes: 6_000_000
        )
        let expected = "7 megabits per second down, 3 megabits per second up, 5G, " +
            "Usable signal, 14 megabytes down and 6 megabytes up used this session"
        XCTAssertEqual(result, expected)
    }

    func testUncappedDownload() {
        let result = AccessibilitySummary.value(
            downloadMbps: 42.5,
            uploadMbps: 2.0,
            generation: .lte,
            quality: .great,
            downloadBytes: 1_000_000,
            uploadBytes: 500_000
        )
        XCTAssertTrue(result.contains("43 megabits per second down"))
    }

    func testUncappedUpload() {
        let result = AccessibilitySummary.value(
            downloadMbps: 5.0,
            uploadMbps: 18.5,
            generation: .threeG,
            quality: .usable,
            downloadBytes: 2_000_000,
            uploadBytes: 1_000_000
        )
        XCTAssertTrue(result.contains("19 megabits per second up"))
    }

    func testUnknownGeneration() {
        let result = AccessibilitySummary.value(
            downloadMbps: 3.0,
            uploadMbps: 1.2,
            generation: .unknown,
            quality: .usable,
            downloadBytes: 5_000_000,
            uploadBytes: 2_000_000
        )
        let expected =
            "3 megabits per second down, 1 megabits per second up, Usable signal, 5 megabytes down and 2 megabytes up used this session"
        XCTAssertEqual(result, expected)
        XCTAssertFalse(result.contains("unknown"))
    }

    func testZeroBytes() {
        let result = AccessibilitySummary.value(
            downloadMbps: 4.0,
            uploadMbps: 2.0,
            generation: .fiveG,
            quality: .usable,
            downloadBytes: 0,
            uploadBytes: 0
        )
        let expected = "0.0 megabytes down and 0.0 megabytes up used this session"
        XCTAssertTrue(result.contains(expected))
    }

    func testGreatQuality() {
        let result = AccessibilitySummary.value(
            downloadMbps: 8.0,
            uploadMbps: 4.0,
            generation: .fiveG,
            quality: .great,
            downloadBytes: 10_000_000,
            uploadBytes: 5_000_000
        )
        XCTAssertTrue(result.contains("Great signal"))
    }

    func testPoorQuality() {
        let result = AccessibilitySummary.value(
            downloadMbps: 1.0,
            uploadMbps: 0.5,
            generation: .lte,
            quality: .poor,
            downloadBytes: 1_000_000,
            uploadBytes: 500_000
        )
        XCTAssertTrue(result.contains("Poor signal"))
    }

    func testRoundingDownward() {
        let result = AccessibilitySummary.value(
            downloadMbps: 2.4,
            uploadMbps: 1.1,
            generation: .lte,
            quality: .usable,
            downloadBytes: 1_000_000,
            uploadBytes: 500_000
        )
        XCTAssertTrue(result.contains("2 megabits per second down"))
        XCTAssertTrue(result.contains("1 megabits per second up"))
    }

    func testRoundingUpward() {
        let result = AccessibilitySummary.value(
            downloadMbps: 7.6,
            uploadMbps: 4.8,
            generation: .fiveG,
            quality: .great,
            downloadBytes: 10_000_000,
            uploadBytes: 5_000_000
        )
        XCTAssertTrue(result.contains("8 megabits per second down"))
        XCTAssertTrue(result.contains("5 megabits per second up"))
    }

    func testAllRadioGenerations() {
        let generations: [RadioGeneration] = [.fiveG, .lte, .threeG, .twoG, .unknown]
        for generation in generations {
            let result = AccessibilitySummary.value(
                downloadMbps: 5.0,
                uploadMbps: 2.0,
                generation: generation,
                quality: .usable,
                downloadBytes: 1_000_000,
                uploadBytes: 500_000
            )
            if generation != .unknown {
                XCTAssertTrue(
                    result.contains(generation.rawValue),
                    "Missing \(generation.rawValue) in: \(result)"
                )
            } else {
                XCTAssertFalse(
                    result.contains("unknown"),
                    "Should not contain 'unknown' for .unknown generation"
                )
            }
        }
    }

    func testLargeByteValues() {
        let result = AccessibilitySummary.value(
            downloadMbps: 9.0,
            uploadMbps: 4.5,
            generation: .fiveG,
            quality: .great,
            downloadBytes: 150_000_000,
            uploadBytes: 75_000_000
        )
        let expected = "150 megabytes down and 75 megabytes up used this session"
        XCTAssertTrue(result.contains(expected))
    }

    func testDecimalByteValues() {
        let result = AccessibilitySummary.value(
            downloadMbps: 5.0,
            uploadMbps: 2.5,
            generation: .lte,
            quality: .usable,
            downloadBytes: 3_200_000,
            uploadBytes: 1_500_000
        )
        let expected = "3.2 megabytes down and 1.5 megabytes up used this session"
        XCTAssertTrue(result.contains(expected))
    }
}
