import Foundation
import Hummingbird
import Logging
import NIOCore

/// HummingBirdサーバーをHTTPServerProtocolに適合させるラッパー
final class HummingBirdHTTPServerWrapper: HTTPServerProtocol {
    private let port: UInt16
    private var application: Application<some ServerChildChannel, some ServerChildChannel>?
    private var logger = Logger(label: "HummingBirdHTTPServerWrapper")
    
    /// ルートハンドラーのストレージ
    private var routes: [(HTTPRoute, HTTPHandler)] = []
    
    init(port: UInt16) {
        self.port = port
    }
    
    func appendRoute(_ route: HTTPRoute, to handler: HTTPHandler) async {
        routes.append((route, handler))
    }
    
    func run() async throws {
        // HummingBird アプリケーションの設定
        let router = Router()
        
        // 登録されたルートをHummingBirdルーターに追加
        for (route, handler) in routes {
            switch route.method {
            case .GET:
                router.get(route.path) { request, context in
                    try await self.handleHummingBirdRequest(request: request, handler: handler)
                }
            case .POST:
                router.post(route.path) { request, context in
                    try await self.handleHummingBirdRequest(request: request, handler: handler)
                }
            case .PUT:
                router.put(route.path) { request, context in
                    try await self.handleHummingBirdRequest(request: request, handler: handler)
                }
            case .DELETE:
                router.delete(route.path) { request, context in
                    try await self.handleHummingBirdRequest(request: request, handler: handler)
                }
            }
        }
        
        // HummingBird アプリケーションの作成と実行
        var app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: Int(port)))
        )
        
        self.application = app
        
        try await app.runService()
    }
    
    func stop() async {
        await application?.shutdown()
        application = nil
    }
    
    /// HummingBirdリクエストをHTTPHandlerで処理するためのアダプター
    private func handleHummingBirdRequest(
        request: Request,
        handler: HTTPHandler
    ) async throws -> Response {
        // HummingBird Request を HTTPRequest に変換
        let httpRequest = try await convertToHTTPRequest(request)
        
        // HTTPHandler で処理
        let httpResponse = try await handler.handleRequest(httpRequest)
        
        // HTTPResponse を HummingBird Response に変換
        return convertToHummingBirdResponse(httpResponse)
    }
    
    /// HummingBird Request を HTTPRequest に変換
    private func convertToHTTPRequest(_ request: Request) async throws -> HTTPRequest {
        let method: HTTPMethod = convertHTTPMethod(request.method)
        let path = request.uri.path
        let headers: [HTTPHeader: String] = convertHeaders(request.headers)
        
        // ボディデータの取得
        let bodyData: Data
        if let buffer = request.body.buffer {
            bodyData = Data(buffer: buffer)
        } else {
            bodyData = Data()
        }
        
        return HTTPRequest(
            method: method,
            path: path,
            headers: headers,
            body: bodyData
        )
    }
    
    /// HummingBird HTTPMethod を HTTPMethod に変換
    private func convertHTTPMethod(_ method: HTTPRequest.Method) -> HTTPMethod {
        switch method {
        case .GET: return .GET
        case .POST: return .POST
        case .PUT: return .PUT
        case .DELETE: return .DELETE
        default: return .GET
        }
    }
    
    /// HummingBird Headers を HTTPHeader辞書に変換
    private func convertHeaders(_ headers: HTTPHeaders) -> [HTTPHeader: String] {
        var result: [HTTPHeader: String] = [:]
        for (name, value) in headers {
            if let httpHeader = HTTPHeader(rawValue: name) {
                result[httpHeader] = value
            }
        }
        return result
    }
    
    /// HTTPResponse を HummingBird Response に変換
    private func convertToHummingBirdResponse(_ httpResponse: HTTPResponse) -> Response {
        let status = convertHTTPStatus(httpResponse.statusCode)
        
        var headers: HTTPHeaders = [:]
        for (header, value) in httpResponse.headers {
            headers.add(name: header.rawValue, value: value)
        }
        
        let body: ResponseBody
        if let bodyData = httpResponse.body {
            body = ResponseBody(data: bodyData)
        } else {
            body = ResponseBody()
        }
        
        return Response(status: status, headers: headers, body: body)
    }
    
    /// HTTPStatusCode を HummingBird HTTPResponseStatus に変換
    private func convertHTTPStatus(_ statusCode: HTTPStatusCode) -> HTTPResponse.Status {
        switch statusCode {
        case .ok: return .ok
        case .badRequest: return .badRequest
        case .methodNotAllowed: return .methodNotAllowed
        case .internalServerError: return .internalServerError
        default: return .ok
        }
    }
}