@testable import Scout
import XCTest

@MainActor
final class HTTPResponseParserTests: XCTestCase {
    var parser: HTTPResponseParser!

    override func setUp() {
        super.setUp()
        parser = HTTPResponseParser()
    }

    // MARK: - Full Response in One Chunk

    func testFullResponse200InOneChunk() throws {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello"
        let events = try parser.feed(Data(response.utf8))

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0], .headersComplete(statusCode: 200, contentLength: 5))
        XCTAssertEqual(events[1], .bodyProgress(newBodyBytes: 5))
        XCTAssertEqual(events[2], .responseComplete)
    }

    // MARK: - Byte-by-Byte

    func testResponseFedByteByByte() throws {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello"
        var allEvents: [HTTPResponseParser.Event] = []

        for byte in Data(response.utf8) {
            let events = try parser.feed(Data([byte]))
            allEvents.append(contentsOf: events)
        }

        let filtered = allEvents.filter { $0 != .needMoreData }

        var hasHeadersComplete = false
        var totalBodyBytes = 0
        var hasResponseComplete = false

        for event in filtered {
            switch event {
            case .headersComplete(statusCode: 200, contentLength: 5):
                hasHeadersComplete = true
            case let .bodyProgress(bytes):
                totalBodyBytes += bytes
            case .responseComplete:
                hasResponseComplete = true
            default:
                break
            }
        }

        XCTAssertTrue(hasHeadersComplete, "Should have headersComplete(200, 5)")
        XCTAssertEqual(totalBodyBytes, 5, "Should have accumulated 5 body bytes")
        XCTAssertTrue(hasResponseComplete, "Should have responseComplete")
    }

    // MARK: - Chunk Boundary Cases

    func testChunkBoundarySplitsHeaderDelimiter() throws {
        let part1 = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n"
        let part2 = "\r\nHello"

        let events1 = try parser.feed(Data(part1.utf8))
        let hasNeedMoreData = events1.contains { $0 == .needMoreData }
        XCTAssertTrue(hasNeedMoreData, "Should need more data when header delimiter is split")

        let events2 = try parser.feed(Data(part2.utf8))
        let filtered = events2.filter { $0 != .needMoreData }

        XCTAssertTrue(filtered.contains(.headersComplete(statusCode: 200, contentLength: 5)))
        XCTAssertTrue(filtered.contains(.bodyProgress(newBodyBytes: 5)))
        XCTAssertTrue(filtered.contains(.responseComplete))
    }

    func testChunkBoundarySplitsStatusLine() throws {
        let part1 = "HTTP/1.1 "
        let part2 = "200 OK\r\nContent-Length: 5\r\n\r\nHello"

        let events1 = try parser.feed(Data(part1.utf8))
        let hasNeedMoreData = events1.contains { $0 == .needMoreData }
        XCTAssertTrue(hasNeedMoreData, "Should need more data when status line is split")

        let events2 = try parser.feed(Data(part2.utf8))
        let filtered = events2.filter { $0 != .needMoreData }

        XCTAssertTrue(filtered.contains(.headersComplete(statusCode: 200, contentLength: 5)))
        XCTAssertTrue(filtered.contains(.bodyProgress(newBodyBytes: 5)))
        XCTAssertTrue(filtered.contains(.responseComplete))
    }

    // MARK: - Keep-Alive Pipelining

    func testTwoBackToBackResponses() throws {
        let response1 = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello"
        let response2 = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nWorld"
        let combined = response1 + response2

        let events = try parser.feed(Data(combined.utf8))

        let filtered = events.filter { $0 != .needMoreData }

        // First response
        XCTAssertEqual(filtered[0], .headersComplete(statusCode: 200, contentLength: 5))
        XCTAssertEqual(filtered[1], .bodyProgress(newBodyBytes: 5))
        XCTAssertEqual(filtered[2], .responseComplete)

        // Second response
        XCTAssertEqual(filtered[3], .headersComplete(statusCode: 200, contentLength: 5))
        XCTAssertEqual(filtered[4], .bodyProgress(newBodyBytes: 5))
        XCTAssertEqual(filtered[5], .responseComplete)
    }

    // MARK: - Error Cases

    func testNon2XXStatus403() throws {
        let response = "HTTP/1.1 403 Forbidden\r\nContent-Length: 5\r\n\r\nError"

        XCTAssertThrowsError(try parser.feed(Data(response.utf8))) { error in
            guard case HTTPResponseParser.ParserError.nonSuccessStatus(403) = error else {
                XCTFail("Expected nonSuccessStatus(403), got \(error)")
                return
            }
        }
    }

    func testMalformedStatusLine() throws {
        let response = "GARBAGE\r\nContent-Length: 5\r\n\r\nHello"

        XCTAssertThrowsError(try parser.feed(Data(response.utf8))) { error in
            guard case HTTPResponseParser.ParserError.malformedResponse = error else {
                XCTFail("Expected malformedResponse, got \(error)")
                return
            }
        }
    }

    // MARK: - Header Case Insensitivity

    func testLowercaseContentLengthHeader() throws {
        let response = "HTTP/1.1 200 OK\r\ncontent-length: 5\r\n\r\nHello"
        let events = try parser.feed(Data(response.utf8))

        let filtered = events.filter { $0 != .needMoreData }
        XCTAssertEqual(filtered[0], .headersComplete(statusCode: 200, contentLength: 5))
        XCTAssertEqual(filtered[1], .bodyProgress(newBodyBytes: 5))
        XCTAssertEqual(filtered[2], .responseComplete)
    }

    func testMixedCaseContentLengthHeader() throws {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello"
        let events = try parser.feed(Data(response.utf8))

        let filtered = events.filter { $0 != .needMoreData }
        XCTAssertEqual(filtered[0], .headersComplete(statusCode: 200, contentLength: 5))
    }

    func testMissingContentLengthHeader() throws {
        let response = "HTTP/1.1 200 OK\r\nX-Custom: value\r\n\r\nHello"
        let events = try parser.feed(Data(response.utf8))

        let filtered = events.filter { $0 != .needMoreData }
        XCTAssertEqual(filtered[0], .headersComplete(statusCode: 200, contentLength: nil))
    }

    // MARK: - Zero-Length Body

    func testZeroLengthResponse() throws {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
        let events = try parser.feed(Data(response.utf8))

        let filtered = events.filter { $0 != .needMoreData }
        XCTAssertEqual(filtered[0], .headersComplete(statusCode: 200, contentLength: 0))
        XCTAssertEqual(filtered[1], .responseComplete)
    }

    // MARK: - Partial Body Consumption

    func testPartialBodyInMultipleChunks() throws {
        let headers = "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n"
        let part1 = "Hello"
        let part2 = "World"

        let events1 = try parser.feed(Data((headers + part1).utf8))
        let filtered1 = events1.filter { $0 != .needMoreData }

        XCTAssertTrue(filtered1.contains(.headersComplete(statusCode: 200, contentLength: 10)))
        XCTAssertTrue(filtered1.contains(.bodyProgress(newBodyBytes: 5)))

        let events2 = try parser.feed(Data(part2.utf8))
        let filtered2 = events2.filter { $0 != .needMoreData }

        XCTAssertTrue(filtered2.contains(.bodyProgress(newBodyBytes: 5)))
        XCTAssertTrue(filtered2.contains(.responseComplete))
    }

    // MARK: - Additional Headers

    func testResponseWithMultipleHeaders() throws {
        let response = "HTTP/1.1 200 OK\r\nServer: TestServer\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello"
        let events = try parser.feed(Data(response.utf8))

        let filtered = events.filter { $0 != .needMoreData }
        XCTAssertEqual(filtered[0], .headersComplete(statusCode: 200, contentLength: 5))
        XCTAssertEqual(filtered[1], .bodyProgress(newBodyBytes: 5))
        XCTAssertEqual(filtered[2], .responseComplete)
    }

    // MARK: - Reset Between Responses

    func testParserResetsAfterResponseComplete() throws {
        let response1 = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
        let response2 = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello"

        let events1 = try parser.feed(Data(response1.utf8))
        let filtered1 = events1.filter { $0 != .needMoreData }
        XCTAssertTrue(filtered1.contains(.responseComplete))

        let events2 = try parser.feed(Data(response2.utf8))
        let filtered2 = events2.filter { $0 != .needMoreData }

        XCTAssertTrue(filtered2.contains(.headersComplete(statusCode: 200, contentLength: 5)))
        XCTAssertTrue(filtered2.contains(.bodyProgress(newBodyBytes: 5)))
        XCTAssertTrue(filtered2.contains(.responseComplete))
    }

    // MARK: - Edge Cases

    func testStatusCodeWith201() throws {
        let response = "HTTP/1.1 201 Created\r\nContent-Length: 0\r\n\r\n"
        let events = try parser.feed(Data(response.utf8))

        let filtered = events.filter { $0 != .needMoreData }
        XCTAssertEqual(filtered[0], .headersComplete(statusCode: 201, contentLength: 0))
    }

    func testStatusCodeWith299() throws {
        let response = "HTTP/1.1 299 Custom\r\nContent-Length: 0\r\n\r\n"
        let events = try parser.feed(Data(response.utf8))

        let filtered = events.filter { $0 != .needMoreData }
        XCTAssertEqual(filtered[0], .headersComplete(statusCode: 299, contentLength: 0))
    }

    func testStatusCodeWith300() throws {
        let response = "HTTP/1.1 300 Multiple Choices\r\nContent-Length: 0\r\n\r\n"

        XCTAssertThrowsError(try parser.feed(Data(response.utf8))) { error in
            guard case HTTPResponseParser.ParserError.nonSuccessStatus(300) = error else {
                XCTFail("Expected nonSuccessStatus(300), got \(error)")
                return
            }
        }
    }

    func testStatusCodeWith100() throws {
        let response = "HTTP/1.1 100 Continue\r\nContent-Length: 0\r\n\r\n"

        XCTAssertThrowsError(try parser.feed(Data(response.utf8))) { error in
            guard case HTTPResponseParser.ParserError.nonSuccessStatus(100) = error else {
                XCTFail("Expected nonSuccessStatus(100), got \(error)")
                return
            }
        }
    }
}
