import APISharedModels
import Foundation
import HTTPServerAdapters
import HTTPTypes
import Testing

@testable import ReuseBackupServer

@Suite("MessageHandler Tests")
@MainActor
struct MessageHandlerTests {
    private let messageManager = MessageManager()

    private var handler: MessageHandler {
        MessageHandler(messageManager: messageManager)
    }

    @Test("when_postWithValidMessage_then_returnsSuccessResponse")
    func validMessagePost() async throws {
        let messageRequest = Components.Schemas.MessageRequest(message: "Test message")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let requestBody = try encoder.encode(messageRequest)

        let request = HTTPRequestInfo(
            method: .post,
            path: "/api/message",
            headerFields: HTTPFields(),
            body: requestBody
        )

        let response = try await handler.handleRequest(request)

        #expect(response.status == .ok)
        #expect(response.headerFields[.contentType] == "application/json")

        let responseBody = try #require(response.body)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let messageResponse = try decoder.decode(Components.Schemas.MessageResponse.self, from: responseBody)

        #expect(messageResponse.status == .success)
        #expect(messageResponse.received == true)
        #expect(messageResponse.serverTimestamp != nil)

        let messages = await messageManager.getMessages()
        #expect(messages.count == 1)
        #expect(messages.first?.content == "Test message")
    }

    @Test("when_postWithInvalidJSON_then_returnsBadRequest")
    func invalidJSONPost() async throws {
        let invalidJSON = "invalid json".data(using: .utf8)!

        let request = HTTPRequestInfo(
            method: .post,
            path: "/api/message",
            headerFields: HTTPFields(),
            body: invalidJSON
        )

        let response = try await handler.handleRequest(request)

        #expect(response.status == .badRequest)
        #expect(response.headerFields[.contentType] == "application/json")

        let responseBody = try #require(response.body)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let errorResponse = try decoder.decode(Components.Schemas.ErrorResponse.self, from: responseBody)

        #expect(errorResponse.status == .error)
        #expect(errorResponse.error == "Invalid message format")
        #expect(errorResponse.received == false)
    }

    @Test("when_postWithMissingBody_then_returnsBadRequest")
    func missingBodyPost() async throws {
        let request = HTTPRequestInfo(
            method: .post,
            path: "/api/message",
            headerFields: HTTPFields(),
            body: nil
        )

        let response = try await handler.handleRequest(request)

        #expect(response.status == .badRequest)
        #expect(response.headerFields[.contentType] == "application/json")

        let responseBody = try #require(response.body)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let errorResponse = try decoder.decode(Components.Schemas.ErrorResponse.self, from: responseBody)

        #expect(errorResponse.status == .error)
        #expect(errorResponse.error == "Invalid message format")
        #expect(errorResponse.received == false)
    }

    @Test("when_getRequest_then_returnsMethodNotAllowed")
    func getRequestNotAllowed() async throws {
        let request = HTTPRequestInfo(
            method: .get,
            path: "/api/message",
            headerFields: HTTPFields(),
            body: nil
        )

        let response = try await handler.handleRequest(request)

        #expect(response.status == .methodNotAllowed)
    }

    @Test("when_putRequest_then_returnsMethodNotAllowed")
    func putRequestNotAllowed() async throws {
        let request = HTTPRequestInfo(
            method: .put,
            path: "/api/message",
            headerFields: HTTPFields(),
            body: nil
        )

        let response = try await handler.handleRequest(request)

        #expect(response.status == .methodNotAllowed)
    }

    @Test("when_deleteRequest_then_returnsMethodNotAllowed")
    func deleteRequestNotAllowed() async throws {
        let request = HTTPRequestInfo(
            method: .delete,
            path: "/api/message",
            headerFields: HTTPFields(),
            body: nil
        )

        let response = try await handler.handleRequest(request)

        #expect(response.status == .methodNotAllowed)
    }

    @Test("when_postWithEmptyMessage_then_returnsSuccessResponse")
    func emptyMessagePost() async throws {
        let messageRequest = Components.Schemas.MessageRequest(message: "")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let requestBody = try encoder.encode(messageRequest)

        let request = HTTPRequestInfo(
            method: .post,
            path: "/api/message",
            headerFields: HTTPFields(),
            body: requestBody
        )

        let response = try await handler.handleRequest(request)

        #expect(response.status == .ok)

        let responseBody = try #require(response.body)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let messageResponse = try decoder.decode(Components.Schemas.MessageResponse.self, from: responseBody)

        #expect(messageResponse.status == .success)
        #expect(messageResponse.received == true)

        let messages = await messageManager.getMessages()
        #expect(messages.last?.content == "")
    }

    @Test("when_postWithLongMessage_then_returnsSuccessResponse")
    func longMessagePost() async throws {
        let longMessage = String(repeating: "a", count: 1000)
        let messageRequest = Components.Schemas.MessageRequest(message: longMessage)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let requestBody = try encoder.encode(messageRequest)

        let request = HTTPRequestInfo(
            method: .post,
            path: "/api/message",
            headerFields: HTTPFields(),
            body: requestBody
        )

        let response = try await handler.handleRequest(request)

        #expect(response.status == .ok)

        let messages = await messageManager.getMessages()
        #expect(messages.last?.content == longMessage)
    }
}
