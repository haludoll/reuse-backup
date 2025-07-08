import Foundation
import HTTPTypes

#if canImport(Hummingbird)
import Hummingbird

/// HummingBird v1.xサーバーをHTTPServerAdapterProtocolに適合させるアダプター
@available(iOS 15.0, *)
public final class HummingBirdV1Adapter: HTTPServerAdapterProtocol {
    public let port: UInt16
    
    private var application: HBApplication?
    private var routes: [(HTTPRouteInfo, HTTPHandlerAdapter)] = []
    
    public init(port: UInt16) {
        self.port = port
    }
    
    public func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        routes.append((route, handler))
    }
    
    public func run() async throws {
        let app = HBApplication(
            configuration: .init(
                address: .hostname("0.0.0.0", port: Int(port)),
                serverName: "ReuseBackupServer-HummingBird"
            )
        )
        
        // 登録されたルートをHummingBirdアプリケーションに追加
        for (route, handler) in routes {
            let handlerWrapper = HummingBirdHandlerWrapper(handler: handler)
            
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
        
        self.application = app
        try await app.start()
        await app.wait()
    }
    
    public func stop() async {
        await application?.stop()
        application = nil
    }
}

/// HTTPHandlerAdapterをHummingBird v1.xハンドラーに変換するラッパー
@available(iOS 15.0, *)
private struct HummingBirdHandlerWrapper {
    let handler: HTTPHandlerAdapter
    
    func handle(_ request: HBRequest) async throws -> HBResponse {
        // HBRequestをHTTPRequestInfoに変換
        let requestInfo = HTTPRequestInfo(
            method: convertFromHummingBirdMethod(request.method),
            path: request.uri.path,
            headerFields: convertFromHummingBirdHeaders(request.headers),
            body: request.body.buffer.map { Data(buffer: $0) }
        )
        
        // ハンドラーで処理
        let responseInfo = try await handler.handleRequest(requestInfo)
        
        // HTTPResponseInfoをHBResponseに変換
        var response = HBResponse(
            status: convertToHummingBirdStatus(responseInfo.status),
            headers: convertToHummingBirdHeaders(responseInfo.headerFields)
        )
        
        if let body = responseInfo.body {
            response.body = .byteBuffer(ByteBufferAllocator().buffer(data: body))
        }
        
        return response
    }
    
    /// HBRequest.MethodをHTTPTypes.HTTPRequest.Methodに変換
    private func convertFromHummingBirdMethod(_ method: HBHTTPMethod) -> HTTPRequest.Method {
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
    private func convertFromHummingBirdHeaders(_ headers: HBHTTPHeaders) -> HTTPFields {
        var httpFields = HTTPFields()
        for (name, value) in headers {
            httpFields[HTTPField.Name(name)!] = value
        }
        return httpFields
    }
    
    /// HTTPTypes.HTTPResponse.StatusをHummingBird HTTPResponseStatusに変換
    private func convertToHummingBirdStatus(_ status: HTTPResponse.Status) -> HBHTTPStatus {
        HBHTTPStatus(code: status.code)
    }
    
    /// HTTPTypes.HTTPFieldsをHummingBird HTTPHeadersに変換
    private func convertToHummingBirdHeaders(_ headerFields: HTTPFields) -> HBHTTPHeaders {
        var headers = HBHTTPHeaders()
        for field in headerFields {
            headers.add(name: field.name.rawName, value: field.value)
        }
        return headers
    }
}

#else
/// HummingBirdが利用できない場合のプレースホルダー実装
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
        throw NSError(domain: "HummingBirdV1Unavailable", code: 1, userInfo: [NSLocalizedDescriptionKey: "HummingBird v1.x is not available"])
    }
    
    public func stop() async {
        print("Warning: HummingBird v1.x stop not available")
    }
}
#endif