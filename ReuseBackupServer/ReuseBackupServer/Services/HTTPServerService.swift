import FlyingFox
import Foundation
import OSLog

/// HTTP サーバー機能を提供するサービスクラス
///
/// FlyingFoxフレームワークを使用してHTTPサーバー機能を提供します。
/// 主な機能：
/// - `/` - サーバー基本情報
/// - `/api/status` - サーバーステータス情報の取得
final class HTTPServerService: HTTPServerServiceProtocol {
    // MARK: - Properties

    /// FlyingFoxのHTTPサーバーインスタンス
    private var server: FlyingFox.HTTPServer?

    /// サーバー実行中のタスク
    private var serverTask: Task<Void, Never>?

    /// サーバーが使用するポート番号
    let port: UInt16

    /// ログ出力用のLogger
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "HTTPServerService")

    // MARK: - Initialization

    /// HTTPServerServiceを初期化
    ///
    /// 指定されたポート（デフォルト: 8080）でサーバーを初期化します。
    /// - Parameter port: サーバーが使用するポート番号
    init(port: UInt16 = 8080) {
        self.port = port
        logger.info("HTTPServerService initialized for port \(port)")
    }

    // MARK: - Server Control

    /// HTTPサーバーを開始
    ///
    /// FlyingFoxを使用してHTTPサーバーを開始し、ルートとAPIエンドポイントを設定します。
    /// サーバーは別タスクで非同期実行され、即座に制御が戻ります。
    /// - Throws: サーバー開始に失敗した場合のエラー
    func start() async throws {
        guard server == nil else {
            logger.warning("Server is already running")
            return
        }

        logger.info("Starting HTTP server on port \(self.port)")

        let server = HTTPServer(port: port)

        await server.appendRoute(.init(method: .GET, path: "/"), to: ClosureHTTPHandler(rootHandler))
        await server.appendRoute(.init(method: .GET, path: "/api/status"), to: ClosureHTTPHandler(statusHandler))

        // server.run()は永続的にawaitするため、先にインスタンスを保存
        self.server = server
        serverTask = Task {
            do {
                try await server.run()
            } catch {
                self.server = nil
                self.serverTask = nil
                logger.error("HTTP server stopped with error: \(error.localizedDescription)")
            }
        }

        logger.info("HTTP server started successfully on port \(self.port)")
    }

    /// HTTPサーバーを停止
    ///
    /// 実行中のFlyingFoxサーバーを停止し、関連するタスクもキャンセルします。
    func stop() async {
        guard let server = server else {
            logger.warning("Server is not running")
            return
        }

        logger.info("Stopping HTTP server")

        serverTask?.cancel()
        await server.stop()

        self.server = nil
        serverTask = nil

        logger.info("HTTP server stopped")
    }

    /// サーバーが実行中かどうかを返す
    var isRunning: Bool { server != nil }

    // MARK: - Route Handlers

    /// ルートエンドポイントのハンドラー
    ///
    /// サーバーの基本情報を返します。
    /// - Parameter request: HTTPリクエスト
    /// - Returns: サーバー情報を含むHTTPレスポンス
    @Sendable
    private func rootHandler(request _: HTTPRequest) async throws -> HTTPResponse {
        let response = [
            "status": "success",
            "message": "ReuseBackup Server is running",
            "port": port,
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: response)
        return HTTPResponse(statusCode: .ok,
                            headers: [.contentType: "application/json"],
                            body: jsonData)
    }

    /// APIステータスエンドポイントのハンドラー
    ///
    /// サーバーの詳細なステータス情報を返します。
    /// - Parameter request: HTTPリクエスト
    /// - Returns: ステータス情報を含むHTTPレスポンス
    @Sendable
    private func statusHandler(request _: HTTPRequest) async throws -> HTTPResponse {
        let statusResponse = ServerStatusResponse(
            status: "running",
            version: "1.0.0",
            serverTime: ISO8601DateFormatter().string(from: Date())
        )

        let jsonData = try JSONEncoder().encode(statusResponse)
        return HTTPResponse(statusCode: .ok,
                            headers: [.contentType: "application/json"],
                            body: jsonData)
    }
}
