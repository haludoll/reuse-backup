import FlyingFox
import Foundation

final class MessageHandler: HTTPHandler {
    private let messageManager: MessageManager

    init(messageManager: MessageManager) {
        self.messageManager = messageManager
    }

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        switch request.method {
        case .POST:
            return try await handlePost(request)
        case .GET:
            return try await handleGet()
        case .DELETE:
            return try await handleDelete()
        default:
            return HTTPResponse(statusCode: .methodNotAllowed)
        }
    }

    private func handlePost(_ request: HTTPRequest) async throws -> HTTPResponse {
        let body = try await request.bodyData
        guard let message = String(data: body, encoding: .utf8) else {
            return HTTPResponse(statusCode: .badRequest)
        }

        messageManager.addMessage(message)
        return HTTPResponse(statusCode: .created)
    }

    private func handleGet() async throws -> HTTPResponse {
        let messages = messageManager.getMessages()
        let jsonData = try JSONEncoder().encode(messages)

        return HTTPResponse(
            statusCode: .ok,
            headers: [.contentType: "application/json"],
            body: jsonData
        )
    }

    private func handleDelete() async throws -> HTTPResponse {
        messageManager.clearMessages()
        return HTTPResponse(statusCode: .noContent)
    }
}
