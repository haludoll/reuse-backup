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
        do {
            let uptime = Date().timeIntervalSince(startTime)
            let healthCheck = performHealthCheck()

            if healthCheck.isHealthy {
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
            } else {
                // サーバーに問題がある場合
                let statusResponse = ServerStatusResponse(
                    status: "degraded",
                    version: "1.0.0",
                    serverTime: ISO8601DateFormatter().string(from: Date()),
                    port: port,
                    uptimeSeconds: uptime
                )

                let jsonData = try JSONEncoder().encode(statusResponse)
                return HTTPResponse(
                    statusCode: .ok, // ステータス情報は返せるので200
                    headers: [.contentType: "application/json"],
                    body: jsonData
                )
            }
        } catch {
            // 予期しないエラー
            let errorResponse = ErrorResponse(
                error: "status_check_failed",
                message: "Unable to retrieve server status",
                statusCode: 500,
                serverTime: ISO8601DateFormatter().string(from: Date())
            )

            let jsonData = try JSONEncoder().encode(errorResponse)
            return HTTPResponse(
                statusCode: .internalServerError,
                headers: [.contentType: "application/json"],
                body: jsonData
            )
        }
    }

    private func performHealthCheck() -> (isHealthy: Bool, issues: [String]) {
        var issues: [String] = []

        // 実際に問題となる状況のみチェック
        // 稼働時間自体は問題ではないため、チェックから除外

        // 基本的なシステム状態確認
        // 現在の簡易実装では常に健全と判定
        // 将来的に以下を追加予定：
        // - 実際のメモリ使用量チェック
        // - ディスク容量チェック
        // - ネットワーク接続状態チェック

        return (isHealthy: true, issues: issues)
    }
}
