import FlyingFox
import Foundation

/// HTTPサーバーの抽象化プロトコル
///
/// FlyingFoxのHTTPServerを抽象化し、テスト可能にするためのプロトコルです。
protocol HTTPServerProtocol: Sendable {
    /// サーバーが使用するポート番号
    var port: UInt16 { get }

    /// ルートを追加する
    /// - Parameters:
    ///   - route: 追加するルート
    ///   - handler: ルートハンドラー
    func appendRoute(_ route: HTTPRoute, to handler: HTTPHandler) async

    /// サーバーを開始する
    /// - Throws: サーバー開始エラー
    func run() async throws

    /// サーバーを停止する
    func stop() async
}

/// FlyingFoxのHTTPServerをプロトコルに適合させるラッパー
final class FlyingFoxHTTPServerWrapper: HTTPServerProtocol {
    private let server: FlyingFox.HTTPServer

    var port: UInt16 {
        server.port
    }

    init(port: UInt16) {
        server = FlyingFox.HTTPServer(port: port)
    }

    func appendRoute(_ route: HTTPRoute, to handler: HTTPHandler) async {
        await server.appendRoute(route, to: handler)
    }

    func run() async throws {
        try await server.run()
    }

    func stop() async {
        await server.stop()
    }
}
