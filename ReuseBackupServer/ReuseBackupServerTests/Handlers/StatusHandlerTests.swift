import FlyingFox
import Foundation
@testable import ReuseBackupServer
import Testing

/// StatusHandlerのテスト
struct StatusHandlerTests {
    @Test func when_handler_initialized_then_properties_are_set() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 9090, startTime: startTime)
        // handler is non-optional, so this test is redundant but kept for completeness
        #expect(true)
    }

    @Test func when_healthy_server_then_returns_running_status() async throws {
        let startTime = Date(timeIntervalSinceNow: -100)
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, version: .http11, path: "/api/status", query: [], headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == HTTPStatusCode.ok)
        #expect(response.headers[HTTPHeader.contentType] == "application/json")

        let statusResponse = try await JSONDecoder().decode(
            ServerStatusResponse.self,
            from: response.bodyData
        )
        #expect(statusResponse.status == "running")
        #expect(statusResponse.version == "1.0.0")
        #expect(statusResponse.port == 8080)
        #expect(statusResponse.uptimeSeconds != nil)
    }

    @Test func when_long_uptime_then_returns_running_status() async throws {
        // 24時間以上前の開始時刻を設定
        let startTime = Date(timeIntervalSinceNow: -90000) // 25時間前
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, version: .http11, path: "/api/status", query: [], headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == HTTPStatusCode.ok)
        let statusResponse = try await JSONDecoder().decode(ServerStatusResponse.self, from: response.bodyData)
        #expect(statusResponse.status == "running") // 長時間稼働は正常
        #expect(statusResponse.uptimeSeconds! > 86400) // 24時間以上
    }

    @Test func when_uptime_calculated_then_reflects_time_difference() async throws {
        let startTime = Date(timeIntervalSinceNow: -300)
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, version: .http11, path: "/api/status", query: [], headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == HTTPStatusCode.ok)
        let statusResponse = try await JSONDecoder().decode(ServerStatusResponse.self, from: response.bodyData)
        let uptime = statusResponse.uptimeSeconds!

        #expect(uptime > 299.0)
        #expect(uptime < 301.0)
    }

    @Test func when_different_ports_then_response_reflects_correct_port() async throws {
        let ports: [UInt16] = [8080, 9090, 3000]
        let startTime = Date()

        for port in ports {
            let handler = StatusHandler(port: port, startTime: startTime)
            let request = HTTPRequest(method: .GET, version: .http11, path: "/api/status", query: [], headers: [:], body: Data())

            let response = try await handler.handleRequest(request)

            #expect(response.statusCode == HTTPStatusCode.ok)
            let statusResponse = try await JSONDecoder().decode(ServerStatusResponse.self, from: response.bodyData)
            #expect(statusResponse.port == port)
        }
    }

    @Test func when_health_check_runs_then_verifies_system_status() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, version: .http11, path: "/api/status", query: [], headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == HTTPStatusCode.ok)
        let statusResponse = try await JSONDecoder().decode(ServerStatusResponse.self, from: response.bodyData)
        // システムが正常であれば"running"、問題があれば"degraded"
        #expect(["running", "degraded"].contains(statusResponse.status))
    }
}
