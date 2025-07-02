import FlyingFox
import Foundation

/// ルートエンドポイント（/）のハンドラー
final class RootHandler: HTTPHandler {
    private let port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func handleRequest(_: HTTPRequest) async throws -> HTTPResponse {
        do {
            // 基本的なヘルスチェック
            let healthStatus = checkBasicHealth()

            if healthStatus.isHealthy {
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
            } else {
                // サーバーに問題がある場合
                let errorResponse = ErrorResponse(
                    error: "server_degraded",
                    message: healthStatus.message,
                    statusCode: 503,
                    serverTime: ISO8601DateFormatter().string(from: Date())
                )

                let jsonData = try JSONEncoder().encode(errorResponse)
                return HTTPResponse(
                    statusCode: .serviceUnavailable,
                    headers: [.contentType: "application/json"],
                    body: jsonData
                )
            }
        } catch {
            // 予期しないエラー
            let errorResponse = ErrorResponse(
                error: "internal_error",
                message: "Server encountered an internal error",
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

    private func checkBasicHealth() -> (isHealthy: Bool, message: String) {
        // メモリ使用量の簡易チェック
        let memoryInfo = ProcessInfo.processInfo.physicalMemory
        let usedMemory = mach_task_basic_info()

        // 基本的な生存確認（応答できている = 健全）
        // より詳細なチェックは将来的に追加可能
        return (isHealthy: true, message: "Server is operational")
    }
}
