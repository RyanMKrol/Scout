@testable import Scout
import XCTest

@MainActor
final class HTTPProbeRequestTests: XCTestCase {
    // MARK: - Request Builders

    func testDownloadRequestIsByteExact() {
        let expected = "GET /__down?bytes=262144 HTTP/1.1\r\n" +
            "Host: speed.cloudflare.com\r\n" +
            "Connection: keep-alive\r\n" +
            "\r\n"
        XCTAssertEqual(HTTPProbeRequest.download(), Data(expected.utf8))
    }

    func testUploadHeaderIsByteExact() {
        let expected = "POST /__up HTTP/1.1\r\n" +
            "Host: speed.cloudflare.com\r\n" +
            "Content-Type: application/octet-stream\r\n" +
            "Content-Length: 262144\r\n" +
            "Connection: keep-alive\r\n" +
            "\r\n"
        XCTAssertEqual(HTTPProbeRequest.uploadHeader(), Data(expected.utf8))
    }

    func testUploadBodyIsProbeBytesOfFilledByte() {
        let body = HTTPProbeRequest.uploadBody()
        XCTAssertEqual(body.count, 262_144)
        XCTAssertTrue(body.allSatisfy { $0 == 0x55 })
    }

    // MARK: - Pacer

    func testDelayBeforeNextProbeWithNoLastStartIsZero() {
        let now = ContinuousClock().now
        let delay = ProbePacer.delayBeforeNextProbe(lastProbeStartedAt: nil, now: now)
        XCTAssertEqual(delay, .zero)
    }

    func testDelayBeforeNextProbeAt200MillisecondsIs300MillisecondsRemaining() {
        let base = ContinuousClock().now
        let now = base.advanced(by: .milliseconds(200))
        let delay = ProbePacer.delayBeforeNextProbe(lastProbeStartedAt: base, now: now)
        XCTAssertEqual(delay, .milliseconds(300))
    }

    func testDelayBeforeNextProbeAtOrPastIntervalIsZero() {
        let base = ContinuousClock().now
        let now = base.advanced(by: .milliseconds(500))
        let delay = ProbePacer.delayBeforeNextProbe(lastProbeStartedAt: base, now: now)
        XCTAssertEqual(delay, .zero)
    }
}
