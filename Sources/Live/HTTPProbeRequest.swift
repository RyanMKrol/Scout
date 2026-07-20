import Foundation

enum HTTPProbeRequest {
    static let host = "speed.cloudflare.com"
    static let probeBytes = 262_144
    /// Effectively-unbounded body size for the continuous download stream: large enough that a
    /// receive loop keeps flowing for a whole sweep session. The download loop transparently
    /// re-requests if the server ever finishes this body first, so this is a floor, not a cap.
    static let downloadBytes = 1_073_741_824

    static func download() -> Data {
        let request = "GET /__down?bytes=\(downloadBytes) HTTP/1.1\r\n" +
            "Host: \(host)\r\n" +
            "Connection: keep-alive\r\n" +
            "\r\n"
        return Data(request.utf8)
    }

    static func uploadHeader() -> Data {
        let request = "POST /__up HTTP/1.1\r\n" +
            "Host: \(host)\r\n" +
            "Content-Type: application/octet-stream\r\n" +
            "Content-Length: \(probeBytes)\r\n" +
            "Connection: keep-alive\r\n" +
            "\r\n"
        return Data(request.utf8)
    }

    static func uploadBody() -> Data {
        Data(repeating: 0x55, count: probeBytes)
    }
}
