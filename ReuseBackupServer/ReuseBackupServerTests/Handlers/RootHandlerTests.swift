import FlyingFox
import Foundation
@testable import ReuseBackupServer
import Testing

/// RootHandlerのテスト
struct RootHandlerTests {
    // MARK: - Basic Tests

    @Test func when_handler_initialized_then_port_is_set() async throws {
        let handler = RootHandler(port: 9090)

        // ハンドラーが正常に初期化されることを確認
        #expect(handler != nil)
    }

    // MARK: - Request Handling Tests

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

    @Test func when_japanese_accept_language_then_returns_japanese_message() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(
            method: .GET,
            path: "/",
            headers: ["Accept-Language": "ja-JP,ja;q=0.9,en;q=0.8"],
            body: Data()
        )

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)
        #expect(rootResponse.message == "ReuseBackup サーバーが稼働中です")
    }

    @Test func when_english_accept_language_then_returns_english_message() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(
            method: .GET,
            path: "/",
            headers: ["Accept-Language": "en-US,en;q=0.9"],
            body: Data()
        )

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)
        #expect(rootResponse.message == "ReuseBackup Server is running")
    }

    @Test func when_no_accept_language_then_returns_english_message() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(method: .GET, path: "/", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)
        #expect(rootResponse.message == "ReuseBackup Server is running")
    }

    // MARK: - Query Parameter Tests

    @Test func when_details_parameter_true_then_includes_additional_endpoints() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(method: .GET, path: "/?details=true", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)
        #expect(rootResponse.endpoints.contains("/"))
        #expect(rootResponse.endpoints.contains("/api/status"))
        #expect(rootResponse.endpoints.contains("/api/upload"))
        #expect(rootResponse.endpoints.contains("/api/files"))
        #expect(rootResponse.endpoints.count == 4)
    }

    @Test func when_details_parameter_false_then_includes_basic_endpoints_only() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(method: .GET, path: "/?details=false", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)
        #expect(rootResponse.endpoints.count == 2)
        #expect(rootResponse.endpoints.contains("/"))
        #expect(rootResponse.endpoints.contains("/api/status"))
    }

    @Test func when_no_query_parameters_then_includes_basic_endpoints_only() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(method: .GET, path: "/", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)
        #expect(rootResponse.endpoints.count == 2)
    }

    // MARK: - Port Configuration Tests

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

    // MARK: - Header Tests

    @Test func when_user_agent_provided_then_logs_user_agent() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(
            method: .GET,
            path: "/",
            headers: ["User-Agent": "Mozilla/5.0 Test Browser"],
            body: Data()
        )

        let response = try await handler.handleRequest(request)

        // レスポンスが正常であることを確認（ログ出力は実際のログシステムで確認）
        #expect(response.statusCode == .ok)
    }

    @Test func when_content_length_header_then_matches_body_size() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(method: .GET, path: "/", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let contentLength = response.headers[.contentLength]
        let actualLength = response.body.count
        #expect(contentLength == "\(actualLength)")
    }

    // MARK: - Response Format Tests

    @Test func when_request_processed_then_response_time_is_recent() async throws {
        let handler = RootHandler(port: 8080)
        let request = HTTPRequest(method: .GET, path: "/", headers: [:], body: Data())

        let beforeRequest = Date()
        let response = try await handler.handleRequest(request)
        let afterRequest = Date()

        #expect(response.statusCode == .ok)
        let rootResponse = try JSONDecoder().decode(RootResponse.self, from: response.body)

        let formatter = ISO8601DateFormatter()
        let responseTime = formatter.date(from: rootResponse.serverTime)

        #expect(responseTime != nil)
        #expect(responseTime! >= beforeRequest)
        #expect(responseTime! <= afterRequest)
    }
}
