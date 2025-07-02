import FlyingFox
import Foundation

/// ステータスエンドポイント（/api/status）のハンドラー
final class StatusHandler: HTTPHandler {
    private let port: UInt16
    private let startTime: Date

    init(port: UInt16, startTime: Date) {
        self.port = port
        self.startTime = startTime
    }

    func handleRequest(_: HTTPRequest) async throws -> HTTPResponse {
        let uptime = Date().timeIntervalSince(startTime)
        let statusResponse = ServerStatusResponse(
            status: "running",
            version: "1.0.0",
            serverTime: ISO8601DateFormatter().string(from: Date()),
            port: port,
            uptimeSeconds: uptime
        )

        let jsonData = try JSONEncoder().encode(statusResponse)
        return HTTPResponse(
            statusCode: .ok,
            headers: [.contentType: "application/json"],
            body: jsonData
        )
    }
}
