import Foundation
import FlyingFox
import OSLog

/// HummingBirdサーバーをHTTPServerProtocolに適合させるラッパー（プレースホルダー実装）
///
/// 現在はFlyingFoxをベースとしたプレースホルダー実装を提供。
/// 将来的にiOS 17.0+環境でHummingBirdに移行予定。
final class HummingBirdHTTPServerWrapper: HTTPServerProtocol {
    let port: UInt16
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "HummingBirdHTTPServerWrapper")
    
    /// 実際のFlyingFoxサーバーインスタンス
    private let flyingFoxWrapper: FlyingFoxHTTPServerWrapper
    
    init(port: UInt16) {
        self.port = port
        flyingFoxWrapper = FlyingFoxHTTPServerWrapper(port: port)
        logger.info("HummingBirdHTTPServerWrapper initialized with FlyingFox backend on port \(port)")
    }
    
    func appendRoute(_ route: HTTPRoute, to handler: HTTPHandler) async {
        await flyingFoxWrapper.appendRoute(route, to: handler)
    }
    
    func run() async throws {
        logger.info("Starting HummingBird server (FlyingFox backend) on port \(self.port)")
        try await flyingFoxWrapper.run()
    }
    
    func stop() async {
        logger.info("Stopping HummingBird server (FlyingFox backend)")
        await flyingFoxWrapper.stop()
    }
}