import Foundation
import HTTPServerAdaptersCore

/// プレースホルダーのHummingBird v1.xアダプター
/// 
/// 依存関係の競合を避けるため、実際にはHummingBirdV2Adapterを使用します。
/// iOS 15-16環境では警告を表示して、可能であればiOS 17にアップグレードを推奨します。
@available(iOS 15.0, *)
@available(iOS, deprecated: 17.0, message: "Use HummingBirdV2Adapter for iOS 17+")
public final class HummingBirdV1Adapter: HTTPServerAdapterProtocol {
    public let port: UInt16
    private let underlyingAdapter: HTTPServerAdapterProtocol?
    
    public init(port: UInt16) {
        self.port = port
        
        if #available(iOS 17.0, *) {
            // iOS 17以上であればV2アダプターを使用
            self.underlyingAdapter = HummingBirdV2Adapter(port: port)
        } else {
            // iOS 15-16では実装なし（警告のみ）
            self.underlyingAdapter = nil
            print("Warning: HummingBird v1.x is not available due to dependency conflicts.")
            print("Please upgrade to iOS 17+ for full HTTP server functionality.")
        }
    }
    
    public func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        if let adapter = underlyingAdapter {
            await adapter.appendRoute(route, to: handler)
        } else {
            print("Warning: Route registration not available on iOS 15-16")
        }
    }
    
    public func run() async throws {
        if let adapter = underlyingAdapter {
            try await adapter.run()
        } else {
            throw NSError(
                domain: "HummingBirdV1Unavailable", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "HummingBird v1.x is not available due to dependency conflicts. Please upgrade to iOS 17+."]
            )
        }
    }
    
    public func stop() async {
        if let adapter = underlyingAdapter {
            await adapter.stop()
        } else {
            print("Warning: Server stop not available on iOS 15-16")
        }
    }
}