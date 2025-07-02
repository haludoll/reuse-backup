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

        // 稼働時間チェック（長時間稼働でのメモリリーク等）
        let uptime = Date().timeIntervalSince(startTime)
        if uptime > 86400 { // 24時間以上
            issues.append("Long uptime detected")
        }

        // 簡易メモリチェック
        let processInfo = ProcessInfo.processInfo
        let totalMemory = processInfo.physicalMemory

        // 基本的なディスク容量チェック（将来的にファイル保存で必要）
        if let homeDirectory = NSHomeDirectory().data(using: .utf8) {
            // ディスク容量が十分かチェック（簡易版）
            // 実際の実装では適切なディスク容量チェックが必要
        }

        return (isHealthy: issues.isEmpty, issues: issues)
    }
}
