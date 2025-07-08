import APISharedModels
import Foundation
import HTTPServerAdapters
import HTTPTypes

struct MessageHandler: HTTPHandlerAdapter {
    private let messageManager: MessageManager

    init(messageManager: MessageManager) {
        self.messageManager = messageManager
    }

    func handleRequest(_ request: HTTPRequestInfo) async throws -> HTTPResponseInfo {
        switch request.method {
        case .post:
            try await handlePost(request)
        default:
            HTTPResponseInfo(status: .methodNotAllowed)
        }
    }

    private func handlePost(_ request: HTTPRequestInfo) async throws -> HTTPResponseInfo {
        do {
            guard let body = request.body else {
                throw NSError(domain: "MessageHandler", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing request body"])
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messageRequest = try decoder.decode(Components.Schemas.MessageRequest.self, from: body)

            await messageManager.addMessage(messageRequest.message)

            let response = Components.Schemas.MessageResponse(
                status: .success,
                received: true,
                serverTimestamp: Date()
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(response)
            var headers = HTTPFields()
            headers[.contentType] = "application/json"
            return HTTPResponseInfo(
                status: .ok,
                headerFields: headers,
                body: jsonData
            )
        } catch {
            let errorResponse = Components.Schemas.ErrorResponse(
                status: .error,
                error: "Invalid message format",
                received: false
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(errorResponse)
            var headers = HTTPFields()
            headers[.contentType] = "application/json"
            return HTTPResponseInfo(
                status: .badRequest,
                headerFields: headers,
                body: jsonData
            )
        }
    }
}
