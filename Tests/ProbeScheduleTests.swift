@testable import Scout
import XCTest

@MainActor
final class ProbeScheduleTests: XCTestCase {
    func testFourProbeCycleIsThreeDownloadsOneUpload() {
        let directions = (0 ..< 4).map { ProbeSchedule.direction(forProbeIndex: $0) }
        XCTAssertEqual(directions, [.download, .download, .download, .upload])
    }

    func testDownloadToUploadRatioOverManyProbesIsThreeToOne() {
        let probeCount = 40
        let directions = (0 ..< probeCount).map { ProbeSchedule.direction(forProbeIndex: $0) }

        let downloadCount = directions.count(where: { $0 == .download })
        let uploadCount = directions.count(where: { $0 == .upload })

        XCTAssertEqual(downloadCount, 30)
        XCTAssertEqual(uploadCount, 10)
        XCTAssertEqual(downloadCount, uploadCount * 3)
    }

    func testUploadIsEveryFourthProbe() {
        let probeCount = 12
        let uploadIndices = (0 ..< probeCount).filter { ProbeSchedule.direction(forProbeIndex: $0) == .upload }
        XCTAssertEqual(uploadIndices, [3, 7, 11])
    }
}
