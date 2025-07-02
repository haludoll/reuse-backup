import FlyingFox
import Foundation
import OSLog

/// ルートエンドポイント（/）のハンドラー
///
/// サーバーの基本情報を返すハンドラーです。
/// リクエストのヘッダー情報やパラメータを考慮して適切なレスポンスを返します。
final class RootHandler: HTTPHandler {
    // MARK: - Properties

    /// サーバーが使用するポート番号
    private let port: UInt16

    /// ログ出力用のLogger
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "RootHandler")

    // MARK: - Initialization

    /// RootHandlerを初期化
    /// - Parameter port: サーバーのポート番号
    init(port: UInt16) {
        self.port = port
    }

    // MARK: - HTTPHandler

    /// ルートエンドポイントのリクエストを処理
    /// - Parameter request: HTTPリクエスト
    /// - Returns: サーバー基本情報を含むHTTPレスポンス
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        logger.info("Root endpoint accessed from \(request.headers["User-Agent"] ?? "Unknown")")

        // Accept-Languageヘッダーを確認して言語を決定
        let acceptLanguage = request.headers["Accept-Language"] ?? ""
        let isJapanese = acceptLanguage.contains("ja")

        let message = isJapanese ? "ReuseBackup サーバーが稼働中です" : "ReuseBackup Server is running"

        // クエリパラメータを解析
        let queryParams = parseQueryParameters(from: request.path)
        let includeDetails = queryParams["details"] == "true"

        var endpoints = ["/", "/api/status"]

        // 詳細情報が要求された場合は追加エンドポイント情報を含める
        if includeDetails {
            endpoints.append(contentsOf: [
                "/api/upload",
                "/api/files",
            ])
        }

        let response = RootResponse(
            status: "success",
            message: message,
            version: "1.0.0",
            port: port,
            serverTime: ISO8601DateFormatter().string(from: Date()),
            endpoints: endpoints
        )

        let jsonData = try JSONEncoder().encode(response)

        logger.debug("Root endpoint responded with \(endpoints.count) endpoints")

        return HTTPResponse(
            statusCode: .ok,
            headers: [
                .contentType: "application/json",
                .contentLength: "\(jsonData.count)",
            ],
            body: jsonData
        )
    }

    // MARK: - Private Methods

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
}
