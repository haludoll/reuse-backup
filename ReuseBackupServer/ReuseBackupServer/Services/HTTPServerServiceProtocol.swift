import Foundation

/// HTTPサーバーサービスのプロトコル
///
/// テスタビリティのためにHTTPServerServiceを抽象化します。
/// モックオブジェクトの作成やDIパターンの実装が可能になります。
protocol HTTPServerServiceProtocol {
    /// サーバーが実行中かどうかを返す
    var isRunning: Bool { get }

    /// HTTPサーバーを開始
    ///
    /// - Throws: サーバー開始に失敗した場合のエラー
    func start() async throws

    /// HTTPサーバーを停止
    func stop() async
}
