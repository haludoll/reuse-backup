import Foundation
import HTTPTypes

#if canImport(Hummingbird) && compiler(>=5.9)
import Hummingbird

/// HummingBird v2.x サーバーをHTTPServerAdapterProtocolに適合させるアダプター
@available(iOS 17.0, *)
public final class HummingBirdV2Adapter: HTTPServerAdapterProtocol {
    public let port: UInt16
    
    private var routes: [(HTTPRouteInfo, HTTPHandlerAdapter)] = []
    
    public init(port: UInt16) {
        self.port = port
    }
    
    public func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        routes.append((route, handler))
    }
    
    public func run() async throws {
        let router = Router()
        
        // 登録されたルートをHummingBird v2ルーターに追加
        for (route, handler) in routes {
            let handlerWrapper = HummingBirdV2HandlerWrapper(handler: handler)
            
            switch route.method {
            case .get:
                router.get(RouterPath(route.path), use: handlerWrapper.handle)
            case .post:
                router.post(RouterPath(route.path), use: handlerWrapper.handle)
            case .put:
                router.put(RouterPath(route.path), use: handlerWrapper.handle)
            case .delete:
                router.delete(RouterPath(route.path), use: handlerWrapper.handle)
            case .patch:
                router.patch(RouterPath(route.path), use: handlerWrapper.handle)
            case .head:
                router.head(RouterPath(route.path), use: handlerWrapper.handle)
            case .options:
                // OPTIONSは標準的なGETとして扱う
                router.get(RouterPath(route.path), use: handlerWrapper.handle)
            default:
                router.get(RouterPath(route.path), use: handlerWrapper.handle)
            }
        }
        
        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname("0.0.0.0", port: Int(port))
            )
        )
        
        try await app.runService()
    }
    
    public func stop() async {
        // HummingBird v2では、runServiceが終了すると自動的にクリーンアップされる
    }
}

/// HTTPHandlerAdapterをHummingBird v2ハンドラーに変換するラッパー
@available(iOS 17.0, *)
private struct HummingBirdV2HandlerWrapper: Sendable {
    let handler: HTTPHandlerAdapter
    
    func handle(_ request: Request, context: BasicRequestContext) async throws -> Response {
        // HummingBird v2 RequestをHTTPRequestInfoに変換
        let requestInfo = HTTPRequestInfo(
            method: convertFromHummingBirdMethod(request.method),
            path: request.uri.path,
            headerFields: convertFromHummingBirdHeaders(request.headers),
            body: await collectBody(from: request)
        )
        
        // ハンドラーで処理
        let responseInfo = try await handler.handleRequest(requestInfo)
        
        // HTTPResponseInfoをHummingBird v2 Responseに変換
        var response = Response(
            status: convertToHummingBirdStatus(responseInfo.status),
            headers: convertToHummingBirdHeaders(responseInfo.headerFields)
        )
        
        if let body = responseInfo.body {
            response.body = .init(contentLength: body.count) { writer in
                try await writer.write(ByteBuffer(data: body))
                try await writer.finish(nil)
            }
        }
        
        return response
    }
    
    /// Request.Methodを HTTPTypes.HTTPRequest.Methodに変換
    private func convertFromHummingBirdMethod(_ method: HTTPRequest.Method) -> HTTPTypes.HTTPRequest.Method {
        switch method.rawValue {
        case "GET": return .get
        case "POST": return .post
        case "PUT": return .put
        case "DELETE": return .delete
        case "PATCH": return .patch
        case "HEAD": return .head
        case "OPTIONS": return .options
        default: return .get
        }
    }
    
    /// HummingBird HTTPFieldsをHTTPTypes.HTTPFieldsに変換
    private func convertFromHummingBirdHeaders(_ headers: HTTPFields) -> HTTPTypes.HTTPFields {
        var httpFields = HTTPTypes.HTTPFields()
        for field in headers {
            httpFields[HTTPTypes.HTTPField.Name(field.name.rawName)!] = field.value
        }
        return httpFields
    }
    
    /// HTTPTypes.HTTPResponse.StatusをHummingBird HTTPResponse.Statusに変換
    private func convertToHummingBirdStatus(_ status: HTTPTypes.HTTPResponse.Status) -> HTTPResponse.Status {
        HTTPResponse.Status(code: status.code, reasonPhrase: status.reasonPhrase)
    }
    
    /// HTTPTypes.HTTPFieldsをHummingBird HTTPFieldsに変換
    private func convertToHummingBirdHeaders(_ headerFields: HTTPTypes.HTTPFields) -> HTTPFields {
        var headers = HTTPFields()
        for field in headerFields {
            headers.append(HTTPField(name: .init(field.name.rawName)!, value: field.value))
        }
        return headers
    }
    
    /// リクエストボディを収集
    private func collectBody(from request: Request) async -> Data? {
        let body = request.body
        
        var data = Data()
        do {
            for try await chunk in body {
                let bytes = chunk.readableBytesView
                data.append(contentsOf: bytes)
            }
        } catch {
            return nil
        }
        
        return data.isEmpty ? nil : data
    }
}

#else
/// HummingBird v2が利用できない場合のプレースホルダー実装
@available(iOS 17.0, *)
public final class HummingBirdV2Adapter: HTTPServerAdapterProtocol {
    public let port: UInt16
    
    public init(port: UInt16) {
        self.port = port
        print("Warning: HummingBird v2.x is not available. Using placeholder implementation.")
    }
    
    public func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        print("Warning: HummingBird v2.x route registration not available")
    }
    
    public func run() async throws {
        throw NSError(
            domain: "HummingBirdV2Unavailable", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "HummingBird v2.x is not available"])
    }
    
    public func stop() async {
        print("Warning: HummingBird v2.x stop not available")
    }
}
#endif