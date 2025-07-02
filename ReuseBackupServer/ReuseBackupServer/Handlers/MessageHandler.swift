import APISharedModels
import FlyingFox
import Foundation

struct MessageHandler: HTTPHandler {
    private let messageManager: MessageManager

    init(messageManager: MessageManager) {
        self.messageManager = messageManager
    }

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        switch request.method {
        case .POST:
            return try await handlePost(request)
        default:
            return HTTPResponse(statusCode: .methodNotAllowed)
        }
    }

    private func handlePost(_ request: HTTPRequest) async throws -> HTTPResponse {
        do {
            let body = try await request.bodyData
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messageRequest = try decoder.decode(Components.Schemas.MessageRequest.self, from: body)

            messageManager.addMessage(messageRequest.message)

            let response = Components.Schemas.MessageResponse(
                status: .success,
                received: true,
                serverTimestamp: Date()
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(response)
            return HTTPResponse(
                statusCode: .ok,
                headers: [.contentType: "application/json"],
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
            return HTTPResponse(
                statusCode: .badRequest,
                headers: [.contentType: "application/json"],
                body: jsonData
            )
        }
    }
}
