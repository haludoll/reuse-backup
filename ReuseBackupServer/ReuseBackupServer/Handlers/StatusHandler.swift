import FlyingFox
import Foundation
import OSLog

/// ステータスエンドポイント（/api/status）のハンドラー
///
/// サーバーの詳細なステータス情報を返すハンドラーです。
/// サーバーの稼働時間、メモリ使用状況、リクエスト統計などの情報を提供します。
final class StatusHandler: HTTPHandler {
    // MARK: - Properties

    /// サーバーが使用するポート番号
    private let port: UInt16

    /// サーバーの開始時刻
    private let startTime: Date

    /// リクエスト統計
    private var requestCount: Int = 0
    private let requestCountLock = NSLock()

    /// ログ出力用のLogger
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "StatusHandler")

    // MARK: - Initialization

    /// StatusHandlerを初期化
    /// - Parameters:
    ///   - port: サーバーのポート番号
    ///   - startTime: サーバーの開始時刻
    init(port: UInt16, startTime: Date) {
        self.port = port
        self.startTime = startTime
    }

    // MARK: - HTTPHandler

    /// ステータスエンドポイントのリクエストを処理
    /// - Parameter request: HTTPリクエスト
    /// - Returns: サーバーステータス情報を含むHTTPレスポンス
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        incrementRequestCount()

        logger.info("Status endpoint accessed")

        // リクエストのクエリパラメータを解析
        let queryParams = parseQueryParameters(from: request.path)
        let includeSystemInfo = queryParams["system"] == "true"
        let format = queryParams["format"] ?? "json"

        // 稼働時間を計算
        let uptime = Date().timeIntervalSince(startTime)

        // システム情報（オプション）
        var systemInfo: [String: Any]? = nil
        if includeSystemInfo {
            systemInfo = [
                "memoryUsage": getMemoryUsage(),
                "processId": ProcessInfo.processInfo.processIdentifier,
                "systemVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            ]
        }

        // レスポンス形式に応じて処理
        switch format {
        case "plain":
            return try createPlainTextResponse(uptime: uptime)
        case "json":
            fallthrough
        default:
            return try createJSONResponse(uptime: uptime, systemInfo: systemInfo)
        }
    }

    // MARK: - Private Methods

    /// リクエスト数をインクリメント（スレッドセーフ）
    private func incrementRequestCount() {
        requestCountLock.lock()
        defer { requestCountLock.unlock() }
        requestCount += 1
    }

    /// 現在のリクエスト数を取得
    private func getCurrentRequestCount() -> Int {
        requestCountLock.lock()
        defer { requestCountLock.unlock() }
        return requestCount
    }

    /// URLのクエリパラメータを解析
    /// - Parameter path: リクエストパス
    /// - Returns: パラメータの辞書
    private func parseQueryParameters(from path: String) -> [String: String] {
        guard let url = URL(string: path),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            return [:]
        }

        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value
        }
        return params
    }

    /// JSONレスポンスを作成
    /// - Parameters:
    ///   - uptime: 稼働時間
    ///   - systemInfo: システム情報（オプション）
    /// - Returns: JSONレスポンス
    private func createJSONResponse(uptime: TimeInterval, systemInfo: [String: Any]?) throws -> HTTPResponse {
        var responseData: [String: Any] = [
            "status": "running",
            "version": "1.0.0",
            "serverTime": ISO8601DateFormatter().string(from: Date()),
            "port": port,
            "uptimeSeconds": uptime,
            "requestCount": getCurrentRequestCount(),
        ]

        if let systemInfo = systemInfo {
            responseData["systemInfo"] = systemInfo
        }

        let jsonData = try JSONSerialization.data(withJSONObject: responseData, options: .prettyPrinted)

        logger.debug("Status endpoint responded with JSON format")

        return HTTPResponse(
            statusCode: .ok,
            headers: [
                .contentType: "application/json",
                .contentLength: "\(jsonData.count)",
            ],
            body: jsonData
        )
    }

    /// プレーンテキストレスポンスを作成
    /// - Parameter uptime: 稼働時間
    /// - Returns: プレーンテキストレスポンス
    private func createPlainTextResponse(uptime: TimeInterval) throws -> HTTPResponse {
        let uptimeFormatted = formatUptime(uptime)
        let responseText = """
        ReuseBackup Server Status
        ========================
        Status: Running
        Version: 1.0.0
        Port: \(port)
        Uptime: \(uptimeFormatted)
        Requests: \(getCurrentRequestCount())
        Server Time: \(ISO8601DateFormatter().string(from: Date()))
        """

        let textData = responseText.data(using: .utf8) ?? Data()

        logger.debug("Status endpoint responded with plain text format")

        return HTTPResponse(
            statusCode: .ok,
            headers: [
                .contentType: "text/plain",
                .contentLength: "\(textData.count)",
            ],
            body: textData
        )
    }

    /// 稼働時間を人間が読みやすい形式にフォーマット
    /// - Parameter uptime: 稼働時間（秒）
    /// - Returns: フォーマットされた稼働時間文字列
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// メモリ使用量を取得（簡易版）
    /// - Returns: メモリ使用量の辞書
    private func getMemoryUsage() -> [String: Any] {
        let processInfo = ProcessInfo.processInfo
        return [
            "physicalMemory": processInfo.physicalMemory,
            "activeProcessorCount": processInfo.activeProcessorCount,
        ]
    }
}
