import Foundation
import OSLog

/// サーバー管理のためのViewModel
///
/// MVVMアーキテクチャにおけるViewModel層として、サーバーの状態管理と
/// ビジネスロジックを担当します。UIとサービス層の橋渡しを行います。
@MainActor
final class ServerViewModel: ObservableObject {
    // MARK: - Published Properties

    /// サーバーの実行状態
    @Published var isRunning = false

    /// サーバーの現在のステータス
    @Published var serverStatus: ServerStatus = .stopped

    /// エラーメッセージ（エラー発生時に表示）
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// HTTPサーバーサービス
    private let httpServerService: HTTPServerServiceProtocol

    /// ログ出力用のLogger
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "ServerViewModel")

    // MARK: - Initialization

    /// ServerViewModelを初期化
    ///
    /// - Parameter httpServerService: HTTPサーバーサービスの実装（デフォルト: HTTPServerService）
    init(httpServerService: HTTPServerServiceProtocol = HTTPServerService()) {
        self.httpServerService = httpServerService
        logger.info("ServerViewModel initialized")
    }

    // MARK: - Server Control Methods

    /// HTTPサーバーを開始
    ///
    /// サーバーの開始処理を行い、状態を更新します。
    /// エラーが発生した場合は適切なエラーハンドリングを行います。
    func startServer() async {
        guard !isRunning else {
            logger.warning("Server status: already running")
            return
        }

        serverStatus = .starting
        errorMessage = nil
        logger.info("Server status: starting")

        do {
            try await httpServerService.start()

            isRunning = true
            serverStatus = .running
            logger.info("Server status: running")

        } catch {
            let errorMsg = "Failed to start server: \(error.localizedDescription)"

            isRunning = false
            serverStatus = .error(errorMsg)
            errorMessage = errorMsg
            logger.error("Server status: error - \(errorMsg)")
        }
    }

    /// HTTPサーバーを停止
    ///
    /// サーバーの停止処理を行い、状態を更新します。
    func stopServer() async {
        guard isRunning else {
            logger.warning("Server status: not running")
            return
        }

        serverStatus = .stopping
        logger.info("Server status: stopping")

        await httpServerService.stop()

        isRunning = false
        serverStatus = .stopped
        errorMessage = nil

        logger.info("Server status: stopped")
    }

    /// サーバーの状態を手動で更新
    ///
    /// UI更新やデバッグ目的で使用します。
    func refreshServerStatus() {
        isRunning = httpServerService.isRunning

        if isRunning {
            serverStatus = .running
        } else {
            serverStatus = .stopped
        }
    }

    // MARK: - Computed Properties

    /// サーバーのポート番号
    var port: UInt16 {
        return httpServerService.port
    }

    // MARK: - Cleanup

    deinit {
        logger.info("ServerViewModel deinitialized")
    }
}
