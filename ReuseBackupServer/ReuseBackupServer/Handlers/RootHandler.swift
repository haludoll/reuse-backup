import FlyingFox
import Foundation

/// ルートエンドポイント（/）のハンドラー
final class RootHandler: HTTPHandler {
    private let port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func handleRequest(_: HTTPRequest) async throws -> HTTPResponse {
        let response = RootResponse(
            status: "success",
            message: "ReuseBackup Server is running",
            version: "1.0.0",
            port: port,
            serverTime: ISO8601DateFormatter().string(from: Date()),
            endpoints: ["/", "/api/status"]
        )

        let jsonData = try JSONEncoder().encode(response)
        return HTTPResponse(
            statusCode: .ok,
            headers: [.contentType: "application/json"],
            body: jsonData
        )
    }
}
