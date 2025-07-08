import Foundation
import HTTPServerAdaptersCore

#if canImport(Hummingbird) && compiler(>=5.9)
import Hummingbird

/// HummingBird v1.x サーバーをHTTPServerAdapterProtocolに適合させるアダプター
@available(iOS 15.0, *)
@available(iOS, deprecated: 17.0, message: "Use HummingBirdV2Adapter for iOS 17+")
public final class HummingBirdV1Adapter: HTTPServerAdapterProtocol {
    public let port: UInt16
    
    private var routes: [(HTTPRouteInfo, HTTPHandlerAdapter)] = []
    
    public init(port: UInt16) {
        self.port = port
    }
    
    public func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        routes.append((route, handler))
    }
    
    public func run() async throws {
        let app = HBApplication(configuration: .init(address: .hostname("0.0.0.0", port: Int(port))))
        
        // 登録されたルートをHummingBird v1ルーターに追加
        for (route, handler) in routes {
            let handlerWrapper = HummingBirdV1HandlerWrapper(handler: handler)
            
            switch route.method {
            case .get:
                app.router.get(route.path, use: handlerWrapper.handle)
            case .post:
                app.router.post(route.path, use: handlerWrapper.handle)
            case .put:
                app.router.put(route.path, use: handlerWrapper.handle)
            case .delete:
                app.router.delete(route.path, use: handlerWrapper.handle)
            case .patch:
                app.router.patch(route.path, use: handlerWrapper.handle)
            case .head:
                app.router.head(route.path, use: handlerWrapper.handle)
            case .options:
                app.router.options(route.path, use: handlerWrapper.handle)
            default:
                app.router.get(route.path, use: handlerWrapper.handle)
            }
        }
        
        try await app.start()
        try await app.wait()
    }
    
    public func stop() async {
        // HummingBird v1では、waitが終了すると自動的にクリーンアップされる
    }
}

/// HTTPHandlerAdapterをHummingBird v1ハンドラーに変換するラッパー
@available(iOS 15.0, *)
private struct HummingBirdV1HandlerWrapper: Sendable {
    let handler: HTTPHandlerAdapter
    
    func handle(_ request: HBRequest) async throws -> HBResponse {
        // HummingBird v1 HBRequestをHTTPRequestInfoに変換
        let requestInfo = HTTPRequestInfo(
            method: convertFromHummingBirdMethod(request.method),
            path: request.uri.path,
            headerFields: convertFromHummingBirdHeaders(request.headers),
            body: await collectBody(from: request)
        )
        
        // ハンドラーで処理
        let responseInfo = try await handler.handleRequest(requestInfo)
        
        // HTTPResponseInfoをHummingBird v1 HBResponseに変換
        var response = HBResponse(
            status: convertToHummingBirdStatus(responseInfo.status),
            headers: convertToHummingBirdHeaders(responseInfo.headerFields)
        )
        
        if let body = responseInfo.body {
            response.body = .data(body)
        }
        
        return response
    }
    
    /// HBRequest.Methodを HTTPTypes.HTTPRequest.Methodに変換
    private func convertFromHummingBirdMethod(_ method: HBHTTPMethod) -> HTTPTypes.HTTPRequest.Method {
        switch method {
        case .GET: return .get
        case .POST: return .post
        case .PUT: return .put
        case .DELETE: return .delete
        case .PATCH: return .patch
        case .HEAD: return .head
        case .OPTIONS: return .options
        default: return .get
        }
    }
    
    /// HummingBird HTTPHeadersをHTTPTypes.HTTPFieldsに変換
    private func convertFromHummingBirdHeaders(_ headers: HTTPHeaders) -> HTTPTypes.HTTPFields {
        var httpFields = HTTPTypes.HTTPFields()
        for (name, value) in headers {
            if let fieldName = HTTPTypes.HTTPField.Name(name) {
                httpFields[fieldName] = value
            }
        }
        return httpFields
    }
    
    /// HTTPTypes.HTTPResponse.StatusをHummingBird HBHTTPStatusに変換
    private func convertToHummingBirdStatus(_ status: HTTPTypes.HTTPResponse.Status) -> HBHTTPStatus {
        HBHTTPStatus(code: status.code)
    }
    
    /// HTTPTypes.HTTPFieldsをHummingBird HTTPHeadersに変換
    private func convertToHummingBirdHeaders(_ headerFields: HTTPTypes.HTTPFields) -> HTTPHeaders {
        var headers = HTTPHeaders()
        for field in headerFields {
            headers.add(name: field.name.rawName, value: field.value)
        }
        return headers
    }
    
    /// リクエストボディを収集
    private func collectBody(from request: HBRequest) async -> Data? {
        guard let body = request.body.buffer else { return nil }
        return Data(buffer: body)
    }
}

#else
/// HummingBird v1が利用できない場合のプレースホルダー実装
@available(iOS 15.0, *)
@available(iOS, deprecated: 17.0, message: "Use HummingBirdV2Adapter for iOS 17+")
public final class HummingBirdV1Adapter: HTTPServerAdapterProtocol {
    public let port: UInt16
    
    public init(port: UInt16) {
        self.port = port
        print("Warning: HummingBird v1.x is not available. Using placeholder implementation.")
    }
    
    public func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        print("Warning: HummingBird v1.x route registration not available")
    }
    
    public func run() async throws {
        throw NSError(
            domain: "HummingBirdV1Unavailable", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "HummingBird v1.x is not available"])
    }
    
    public func stop() async {
        print("Warning: HummingBird v1.x stop not available")
    }
}
#endif