import Foundation
import APISharedModels

// MARK: - Server Status

/// サーバーの実行状態を表す列挙型（内部状態管理用）
enum ServerStatus: Equatable {
    /// サーバーが停止中
    case stopped
    /// サーバーが開始処理中
    case starting
    /// サーバーが正常稼働中
    case running
    /// サーバーが停止処理中
    case stopping
    /// エラーが発生した状態
    case error(String)

    /// ステータスの文字列表現
    var description: String {
        switch self {
        case .stopped: return "stopped"
        case .starting: return "starting"
        case .running: return "running"
        case .stopping: return "stopping"
        case .error: return "error"
        }
    }
}

// MARK: - Response Models
// APISharedModelsの自動生成モデルを使用
// - Components.Schemas.ServerStatus: サーバーステータスレスポンス
// - Components.Schemas.ErrorResponse: エラーレスポンス
// - Components.Schemas.MessageRequest: メッセージリクエスト
// - Components.Schemas.MessageResponse: メッセージレスポンス
