import Foundation
import HTTPTypes

#if false
// HummingBird v1.xは現在のHummingBird v2パッケージでは利用できません

#else
/// HummingBirdが利用できない場合のプレースホルダー実装
@available(iOS 15.0, *)
@available(iOS, deprecated: 17.0, message: "Use HummingBirdV2Adapter for iOS 17+")
public final class HummingBirdV1Adapter: HTTPServerAdapterProtocol {
    public let port: UInt16
    
    public init(port: UInt16) {
        self.port = port
        print("Warning: HummingBird v1.x is not available with v2 package. Use HummingBirdV2Adapter instead.")
    }
    
    public func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        print("Warning: HummingBird v1.x route registration not available")
    }
    
    public func run() async throws {
        throw NSError(domain: "HummingBirdV1Unavailable", code: 1, userInfo: [NSLocalizedDescriptionKey: "HummingBird v1.x is not available with v2 package"])
    }
    
    public func stop() async {
        print("Warning: HummingBird v1.x stop not available")
    }
}
#endif