import FlyingFox
import Foundation
import OSLog

/// HTTP サーバー機能を提供するサービスクラス
///
/// HTTPサーバーファクトリーを使用してHTTPサーバー機能を提供します。
/// 主な機能：
/// - `/api/status` - サーバーステータス情報の取得
/// - `/api/message` - メッセージ受信API（POST）
final class HTTPServerService: HTTPServerServiceProtocol {
    // MARK: - Properties

    /// HTTPサーバーインスタンス
    private var server: HTTPServerProtocol?

    /// サーバー実行中のタスク
    private var serverTask: Task<Void, Never>?

    /// サーバーが使用するポート番号
    let port: UInt16

    /// HTTPサーバーファクトリー
    private let serverFactory: HTTPServerFactory

    /// サーバー開始時刻
    private var startTime: Date?

    /// メッセージ管理
    let messageManager = MessageManager()

    /// Bonjourサービス発見機能
    private var bonjourService: BonjourService?

    /// BonjourServiceへの読み取り専用アクセス
    var bonjour: BonjourService? {
        bonjourService
    }

    /// ログ出力用のLogger
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "HTTPServerService")

    // MARK: - Initialization

    /// HTTPServerServiceを初期化
    ///
    /// 指定されたポートとファクトリーでサーバーを初期化します。
    /// - Parameters:
    ///   - port: サーバーが使用するポート番号
    ///   - serverFactory: HTTPサーバーを作成するファクトリー
    init(port: UInt16 = 8080, serverFactory: HTTPServerFactory = FlyingFoxHTTPServerFactory()) {
        self.port = port
        self.serverFactory = serverFactory
        logger.info("HTTPServerService initialized for port \(port)")
    }

    // MARK: - Server Control

    /// HTTPサーバーを開始
    ///
    /// サーバーファクトリーを使用してHTTPサーバーを開始し、ルートとAPIエンドポイントを設定します。
    /// サーバーは別タスクで非同期実行され、即座に制御が戻ります。
    /// - Throws: サーバー開始に失敗した場合のエラー
    func start() async throws {
        guard server == nil else {
            logger.warning("Server is already running")
            return
        }

        let port = port
        logger.info("Starting HTTP server on port \(port)")

        let server = serverFactory.createServer(port: port)
        let currentStartTime = Date()

        let statusHandler = StatusHandler(port: port, startTime: currentStartTime)
        let messageHandler = MessageHandler(messageManager: messageManager)

        await server.appendRoute(.init(method: .GET, path: "/api/status"), to: statusHandler)
        await server.appendRoute(.init(method: .POST, path: "/api/message"), to: messageHandler)

        // server.run()は永続的にawaitするため、先にインスタンスを保存
        self.server = server
        startTime = currentStartTime

        // デバッグ: ポート情報をログ出力
        logger.info("🔍 [DEBUG] HTTPサーバーポート: \(port)")
        
        // Bonjourサービスを開始
        bonjourService = BonjourService(port: port)
        bonjourService?.startAdvertising()

        serverTask = Task {
            do {
                try await server.run()
            } catch {
                self.server = nil
                self.serverTask = nil
                self.startTime = nil
                // Bonjourサービスも停止
                self.bonjourService?.stopAdvertising()
                self.bonjourService = nil
                logger.error("HTTP server stopped with error: \(error.localizedDescription)")
            }
        }

        logger.info("HTTP server started successfully on port \(port) with Bonjour advertising")
    }

    /// HTTPサーバーを停止
    ///
    /// 実行中のHTTPサーバーを停止し、関連するタスクもキャンセルします。
    func stop() async {
        guard let server else {
            logger.warning("Server is not running")
            return
        }

        logger.info("Stopping HTTP server")

        serverTask?.cancel()
        await server.stop()

        // Bonjourサービスも停止
        bonjourService?.stopAdvertising()
        bonjourService = nil

        self.server = nil
        serverTask = nil
        startTime = nil

        logger.info("HTTP server and Bonjour service stopped")
    }

    /// サーバーが実行中かどうかを返す
    var isRunning: Bool { server != nil }
}
