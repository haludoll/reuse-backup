import FlyingFox
import Foundation
@testable import ReuseBackupServer
import Testing

/// RootHandlerのテスト
struct RootHandlerTests {
    @Test func when_handler_initialized_then_port_is_set() async throws {
        let handler = RootHandler(port: 9090)
        #expect(handler != nil)
    }

    @Test func when_basic_request_then_returns_success_response() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(method: .GET, path: "/", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "application/json")

        let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)
        #expect(rootResponse.status == "success")
        #expect(rootResponse.port == 8080)
        #expect(rootResponse.version == "1.0.0")
        #expect(rootResponse.endpoints.contains("/"))
        #expect(rootResponse.endpoints.contains("/api/status"))
    }

    @Test func when_different_ports_then_response_reflects_correct_port() async throws {
        let ports: [UInt16] = [8080, 9090, 3000]

        for port in ports {
            let handler = RootHandler(port: port)
            let request = HTTPRequest(method: .GET, path: "/", headers: [:], body: Data())

            let response = try await handler.handleRequest(request)

            #expect(response.statusCode == .ok)
            let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)
            #expect(rootResponse.port == port)
        }
    }
}
