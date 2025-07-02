import Foundation

// MARK: - Server Status

/// サーバーの実行状態を表す列挙型
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

/// サーバーステータスレスポンスの構造体
struct ServerStatusResponse: Codable {
    let status: String
    let version: String
    let serverTime: String
    let port: UInt16
    let uptimeSeconds: TimeInterval?
}

/// ルートエンドポイントのレスポンス構造体
struct RootResponse: Codable {
    let status: String
    let message: String
    let version: String
    let port: UInt16
    let serverTime: String
    let endpoints: [String]
}

/// エラーレスポンスの構造体
struct ErrorResponse: Codable {
    let error: String
    let message: String
    let statusCode: Int
    let serverTime: String
}
