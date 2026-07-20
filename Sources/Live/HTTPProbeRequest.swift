import Foundation

enum HTTPProbeRequest {
    static let host = "speed.cloudflare.com"
    static let probeBytes = 262_144
    /// Per-request body size for the continuous download stream. Cloudflare's `/__down` endpoint
    /// **rejects any `bytes` value ≥ 100 MB with `403 Forbidden`** (empirically: 90 MB → 200 OK,
    /// 100 MB → 403), so this MUST stay comfortably under 100_000_000. It is NOT a session cap:
    /// the download loop re-requests seamlessly on each body completion (see
    /// `CellularThroughputSampler.streamDownload`), so a large-but-legal body just means the stream
    /// flows for seconds between re-requests while yielding a sample per received chunk throughout.
    static let downloadBytes = 90_000_000

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
