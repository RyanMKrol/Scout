import Foundation

struct HTTPResponseParser {
    enum Event: Equatable {
        case needMoreData
        case headersComplete(statusCode: Int, contentLength: Int?)
        case bodyProgress(newBodyBytes: Int)
        case responseComplete
    }

    enum ParserError: Error, Equatable {
        case malformedResponse
        case nonSuccessStatus(Int)
    }

    private var buffer = Data()
    private var state: State = .headersPending
    private var currentStatusCode: Int = 0
    private var currentContentLength: Int?
    private var bodyBytesReceived: Int = 0

    private enum State {
        case headersPending
        case bodyPending
    }

    mutating func feed(_ data: Data) throws -> [Event] {
        buffer.append(data)
        var events: [Event] = []

        while true {
            switch state {
            case .headersPending:
                let headerResult = try processHeaderState()
                if let (headers, bytesConsumed) = headerResult {
                    currentStatusCode = headers.statusCode
                    currentContentLength = headers.contentLength
                    bodyBytesReceived = 0
                    buffer.removeFirst(bytesConsumed)

                    events.append(.headersComplete(
                        statusCode: currentStatusCode,
                        contentLength: currentContentLength
                    ))

                    if let contentLength = headers.contentLength, contentLength == 0 {
                        events.append(.responseComplete)
                        resetForNextResponse()
                        if buffer.isEmpty {
                            return events
                        }
                    } else {
                        state = .bodyPending
                    }
                } else {
                    events.append(.needMoreData)
                    return events
                }

            case .bodyPending:
                let bodyResult = try processBodyState()
                if let (bytesConsumed, isComplete) = bodyResult {
                    if bytesConsumed > 0 {
                        events.append(.bodyProgress(newBodyBytes: bytesConsumed))
                    }
                    if isComplete {
                        events.append(.responseComplete)
                        resetForNextResponse()
                        if buffer.isEmpty {
                            return events
                        }
                    }
                } else {
                    events.append(.needMoreData)
                    return events
                }
            }
        }
    }

    private struct HeadersInfo {
        let statusCode: Int
        let contentLength: Int?
    }

    private mutating func processHeaderState() throws -> (HeadersInfo, Int)? {
        guard let headerEndIndex = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        let headerData = buffer[..<headerEndIndex.lowerBound]
        let headerString = String(data: headerData, encoding: .utf8) ?? ""
        let lines = headerString.split(separator: "\r\n", omittingEmptySubsequences: false)

        guard !lines.isEmpty else { throw ParserError.malformedResponse }

        let statusLine = String(lines[0])
        let statusComponents = statusLine.split(separator: " ")
        guard statusComponents.count >= 2, let statusCode = Int(statusComponents[1]) else {
            throw ParserError.malformedResponse
        }

        guard (200 ... 299).contains(statusCode) else {
            throw ParserError.nonSuccessStatus(statusCode)
        }

        let contentLength = extractContentLength(from: lines)
        let bytesConsumed = buffer.distance(from: buffer.startIndex, to: headerEndIndex.upperBound)
        return (HeadersInfo(statusCode: statusCode, contentLength: contentLength), bytesConsumed)
    }

    private func extractContentLength(from lines: [Substring]) -> Int? {
        for line in lines.dropFirst() {
            let trimmedLine = String(line)
            if trimmedLine.isEmpty {
                break
            }
            let parts = trimmedLine.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let headerName = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
            if headerName == "content-length" {
                let headerValue = String(parts[1]).trimmingCharacters(in: .whitespaces)
                return Int(headerValue)
            }
        }
        return nil
    }

    private mutating func processBodyState() throws -> (Int, Bool)? {
        guard let contentLength = currentContentLength else {
            return nil
        }

        let bytesNeeded = contentLength - bodyBytesReceived
        if buffer.count >= bytesNeeded {
            bodyBytesReceived += bytesNeeded
            buffer.removeFirst(bytesNeeded)
            return (bytesNeeded, true)
        }

        let bodyBytes = buffer.count
        if bodyBytes > 0 {
            bodyBytesReceived += bodyBytes
            buffer.removeFirst(bodyBytes)
            return (bodyBytes, false)
        }

        return nil
    }

    private mutating func resetForNextResponse() {
        state = .headersPending
        currentStatusCode = 0
        currentContentLength = nil
        bodyBytesReceived = 0
    }
}
