import Foundation
import FlyingFox
import HTTPTypes

/// FlyingFoxサーバーをHTTPServerAdapterProtocolに適合させるアダプター
public final class FlyingFoxAdapter: HTTPServerAdapterProtocol {
    public let port: UInt16
    
    private var server: HTTPServer?
    private var routes: [(HTTPRouteInfo, HTTPHandlerAdapter)] = []
    
    public init(port: UInt16) {
        self.port = port
    }
    
    public func appendRoute(_ route: HTTPRouteInfo, to handler: HTTPHandlerAdapter) async {
        routes.append((route, handler))
    }
    
    public func run() async throws {
        let server = HTTPServer(port: port)
        
        // 登録されたルートをFlyingFoxサーバーに追加
        for (route, handler) in routes {
            let flyingFoxRoute = FlyingFox.HTTPRoute(
                method: convertToFlyingFoxMethod(route.method),
                path: route.path
            )
            
            let flyingFoxHandler = FlyingFoxHandlerWrapper(handler: handler)
            await server.appendRoute(flyingFoxRoute, to: flyingFoxHandler)
        }
        
        self.server = server
        try await server.run()
    }
    
    public func stop() async {
        await server?.stop()
        server = nil
    }
    
    /// HTTPTypes.HTTPRequest.MethodをFlyingFox.HTTPMethodに変換
    private func convertToFlyingFoxMethod(_ method: HTTPRequest.Method) -> FlyingFox.HTTPMethod {
        switch method {
        case .get: return .GET
        case .post: return .POST
        case .put: return .PUT
        case .delete: return .DELETE
        case .patch: return .PATCH
        case .head: return .HEAD
        case .options: return .OPTIONS
        default: return .GET
        }
    }
}

/// HTTPHandlerAdapterをFlyingFox.HTTPHandlerに変換するラッパー
private struct FlyingFoxHandlerWrapper: FlyingFox.HTTPHandler {
    let handler: HTTPHandlerAdapter
    
    func handleRequest(_ request: FlyingFox.HTTPRequest) async throws -> FlyingFox.HTTPResponse {
        // FlyingFox.HTTPRequestをHTTPRequestInfoに変換
        let requestInfo = HTTPRequestInfo(
            method: convertFromFlyingFoxMethod(request.method),
            path: request.path,
            headerFields: convertFromFlyingFoxHeaders(request.headers),
            body: try await request.bodyData
        )
        
        // ハンドラーで処理
        let responseInfo = try await handler.handleRequest(requestInfo)
        
        // HTTPResponseInfoをFlyingFox.HTTPResponseに変換
        return FlyingFox.HTTPResponse(
            statusCode: convertToFlyingFoxStatus(responseInfo.status),
            headers: convertToFlyingFoxHeaders(responseInfo.headerFields),
            body: responseInfo.body ?? Data()
        )
    }
    
    /// FlyingFox.HTTPMethodをHTTPTypes.HTTPRequest.Methodに変換
    private func convertFromFlyingFoxMethod(_ method: FlyingFox.HTTPMethod) -> HTTPRequest.Method {
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
    
    /// FlyingFox.HTTPHeadersをHTTPTypes.HTTPFieldsに変換
    private func convertFromFlyingFoxHeaders(_ headers: [FlyingFox.HTTPHeader: String]) -> HTTPFields {
        var httpFields = HTTPFields()
        for (header, value) in headers {
            httpFields[HTTPField.Name(header.rawValue)!] = value
        }
        return httpFields
    }
    
    /// HTTPTypes.HTTPResponse.StatusをFlyingFox.HTTPStatusCodeに変換
    private func convertToFlyingFoxStatus(_ status: HTTPResponse.Status) -> FlyingFox.HTTPStatusCode {
        switch status.code {
        case 200: return .ok
        case 201: return .created
        case 202: return .accepted
        case 204: return .noContent
        case 400: return .badRequest
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 405: return .methodNotAllowed
        case 409: return .conflict
        case 500: return .internalServerError
        case 501: return .notImplemented
        case 502: return .badGateway
        case 503: return .serviceUnavailable
        default: return .ok
        }
    }
    
    /// HTTPTypes.HTTPFieldsをFlyingFox.HTTPHeadersに変換
    private func convertToFlyingFoxHeaders(_ headerFields: HTTPFields) -> [FlyingFox.HTTPHeader: String] {
        var headers: [FlyingFox.HTTPHeader: String] = [:]
        for field in headerFields {
            let header = FlyingFox.HTTPHeader(rawValue: field.name.rawName)
            headers[header] = field.value
        }
        return headers
    }
}