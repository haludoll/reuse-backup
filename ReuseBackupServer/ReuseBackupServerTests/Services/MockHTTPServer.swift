import Foundation
import HTTPServerAdapters
import HTTPTypes
@testable import ReuseBackupServer

/// テスト用のモックHTTPサーバー
final class MockHTTPServer: HTTPServerProtocol, @unchecked Sendable {
    // MARK: - Properties

    let port: UInt16
    private var routes: [HTTPRouteInfo: HTTPHandlerAdapter] = [:]
    private(set) var isRunning = false

    // MARK: - Call Tracking

    private(set) var appendRouteCallCount = 0
    private(set) var runCallCount = 0
    private(set) var stopCallCount = 0

    // MARK: - Error Configuration

    var shouldThrowOnRun = false
    var runError: Error = MockError.runFailed

    // MARK: - Request Simulation

    private(set) var lastAppendedRoute: HTTPRouteInfo?
    private(set) var lastAppendedHandler: HTTPHandlerAdapter?

    // MARK: - Initialization

    init(port: UInt16) {
        self.port = port
    }

    // MARK: - HTTPServerProtocol

    func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        appendRouteCallCount += 1
        routes[route] = handler
        lastAppendedRoute = route
        lastAppendedHandler = handler
    }

    func run() async throws {
        runCallCount += 1

        if shouldThrowOnRun {
            throw runError
        }

        isRunning = true

        // 実際のサーバーのように永続的に実行される状態をシミュレート
        // テストでは適切にstop()が呼ばれることを確認
        try await withCheckedThrowingContinuation { (_: CheckedContinuation<Void, Error>) in
            // 永続実行をシミュレート（実際にはstop()で中断される）
        }
    }

    func stop() async {
        stopCallCount += 1
        isRunning = false
    }

    // MARK: - Test Utilities

    /// モック状態をリセット
    func reset() {
        routes.removeAll()
        isRunning = false
        appendRouteCallCount = 0
        runCallCount = 0
        stopCallCount = 0
        shouldThrowOnRun = false
        runError = MockError.runFailed
        lastAppendedRoute = nil
        lastAppendedHandler = nil
    }

    /// 指定されたルートが登録されているかチェック
    func hasRoute(_ route: HTTPRouteInfo) -> Bool {
        routes.keys.contains(route)
    }

    /// 登録されたルート数を取得
    var routeCount: Int {
        routes.count
    }

    /// 指定されたルートのハンドラーでリクエストをシミュレート
    func simulateRequest(for route: HTTPRouteInfo, request: HTTPRequestInfo) async throws -> HTTPResponseInfo? {
        guard let handler = routes[route] else {
            return nil
        }
        return try await handler.handleRequest(request)
    }
}

// MARK: - MockHTTPServer.MockError

extension MockHTTPServer {
    enum MockError: Error, Equatable, LocalizedError {
        case runFailed
        case routeNotFound

        var errorDescription: String? {
            switch self {
            case .runFailed:
                "Mock server run failed"
            case .routeNotFound:
                "Route not found in mock server"
            }
        }
    }
}

// MARK: - HTTPRouteInfo Hashable Extension

extension HTTPRouteInfo: @retroactive Equatable {}
extension HTTPRouteInfo: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(method)
        hasher.combine(path)
    }

    public static func == (lhs: HTTPRouteInfo, rhs: HTTPRouteInfo) -> Bool {
        lhs.method == rhs.method && lhs.path == rhs.path
    }
}

/// テスト用のモックHTTPサーバーファクトリー
final class MockHTTPServerFactory: HTTPServerFactory, @unchecked Sendable {
    private(set) var createServerCallCount = 0
    private(set) var lastCreatedPort: UInt16?
    private(set) var createdServers: [MockHTTPServer] = []

    func createServer(port: UInt16) -> HTTPServerProtocol {
        createServerCallCount += 1
        lastCreatedPort = port

        let server = MockHTTPServer(port: port)
        createdServers.append(server)
        return server
    }

    /// ファクトリー状態をリセット
    func reset() {
        createServerCallCount = 0
        lastCreatedPort = nil
        createdServers.removeAll()
    }

    /// 最後に作成されたモックサーバーを取得
    var lastCreatedServer: MockHTTPServer? {
        createdServers.last
    }
}
