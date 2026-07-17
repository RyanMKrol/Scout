import Foundation

enum HTTPProbeRequest {
    static let host = "speed.cloudflare.com"
    static let probeBytes = 262_144

    static func download() -> Data {
        let request = "GET /__down?bytes=\(probeBytes) HTTP/1.1\r\n" +
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
