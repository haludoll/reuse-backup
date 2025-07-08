import Foundation

/// HTTPサーバーを作成するファクトリープロトコル
///
/// HTTPサーバーの生成を抽象化し、テスト時にモックサーバーを注入可能にします。
protocol HTTPServerFactory: Sendable {
    /// 指定されたポートでHTTPサーバーを作成する
    /// - Parameter port: サーバーが使用するポート番号
    /// - Returns: HTTPServerProtocolに準拠するサーバーインスタンス
    func createServer(port: UInt16) -> HTTPServerProtocol
}

/// HummingBirdのHTTPServerを作成するファクトリー実装
final class HummingBirdHTTPServerFactory: HTTPServerFactory {
    func createServer(port: UInt16) -> HTTPServerProtocol {
        HummingBirdHTTPServerWrapper(port: port)
    }
}

/// FlyingFoxのHTTPServerを作成するファクトリー実装（下位互換性のため保持）
final class FlyingFoxHTTPServerFactory: HTTPServerFactory {
    func createServer(port: UInt16) -> HTTPServerProtocol {
        FlyingFoxHTTPServerWrapper(port: port)
    }
}
