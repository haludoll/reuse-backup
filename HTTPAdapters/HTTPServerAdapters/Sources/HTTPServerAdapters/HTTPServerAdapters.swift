import Foundation
import HTTPTypes

/// HTTPサーバーの抽象インターフェース
public protocol HTTPServerAdapterProtocol: Sendable {
    /// サーバーが使用するポート番号
    var port: UInt16 { get }
    
    /// HTTPルートとハンドラーを追加
    /// - Parameters:
    ///   - route: 登録するHTTPルート情報
    ///   - handler: リクエストを処理するハンドラー
    func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async
    
    /// HTTPサーバーを開始
    /// - Throws: サーバー開始に失敗した場合のエラー
    func run() async throws
    
    /// HTTPサーバーを停止
    func stop() async
}

/// HTTPルート情報
public struct HTTPRouteInfo: Sendable {
    public let method: HTTPRequest.Method
    public let path: String
    
    public init(method: HTTPRequest.Method, path: String) {
        self.method = method
        self.path = path
    }
}

/// HTTPリクエスト情報
public struct HTTPRequestInfo: Sendable {
    public let method: HTTPRequest.Method
    public let path: String
    public let headerFields: HTTPFields
    public let body: Data?
    
    public init(method: HTTPRequest.Method, path: String, headerFields: HTTPFields = HTTPFields(), body: Data? = nil) {
        self.method = method
        self.path = path
        self.headerFields = headerFields
        self.body = body
    }
}

/// HTTPレスポンス情報
public struct HTTPResponseInfo: Sendable {
    public let status: HTTPResponse.Status
    public let headerFields: HTTPFields
    public let body: Data?
    
    public init(status: HTTPResponse.Status, headerFields: HTTPFields = HTTPFields(), body: Data? = nil) {
        self.status = status
        self.headerFields = headerFields
        self.body = body
    }
}

/// HTTPハンドラーアダプター
public protocol HTTPHandlerAdapter: Sendable {
    /// HTTPリクエストを処理
    /// - Parameter request: 処理するHTTPリクエスト情報
    /// - Returns: HTTPレスポンス情報
    /// - Throws: リクエスト処理中のエラー
    func handleRequest(_ request: HTTPRequestInfo) async throws -> HTTPResponseInfo
}