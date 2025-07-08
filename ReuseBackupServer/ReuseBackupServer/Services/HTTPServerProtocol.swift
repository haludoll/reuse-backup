import Foundation
import HTTPServerAdapters
import HTTPTypes

/// HTTPサーバーの抽象化プロトコル
///
/// HTTPServerAdaptersのHTTPServerAdapterProtocolを抽象化し、テスト可能にするためのプロトコルです。
protocol HTTPServerProtocol: Sendable {
    /// サーバーが使用するポート番号
    var port: UInt16 { get }

    /// ルートを追加する
    /// - Parameters:
    ///   - route: 追加するルート
    ///   - handler: ルートハンドラー
    func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async

    /// サーバーを開始する
    /// - Throws: サーバー開始エラー
    func run() async throws

    /// サーバーを停止する
    func stop() async
}

/// HTTPServerAdaptersのサーバーをプロトコルに適合させるラッパー
final class HTTPAdaptersServerWrapper: HTTPServerProtocol {
    private let server: HTTPServerAdapterProtocol
    let port: UInt16

    init(port: UInt16) {
        self.port = port
        server = HTTPServerAdapterFactory.createServer(port: port)
    }

    func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        await server.appendRoute(route, to: handler)
    }

    func run() async throws {
        try await server.run()
    }

    func stop() async {
        await server.stop()
    }
}
