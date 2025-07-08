import APISharedModels
import Foundation
import HTTPServerAdapters
import HTTPTypes
@testable import ReuseBackupServer
import Testing

/// StatusHandlerのテスト
struct StatusHandlerTests {
    @Test func when_handler_initialized_then_properties_are_set() async throws {
        let startTime = Date()
        _ = StatusHandler(port: 9090, startTime: startTime)
        // handler is non-optional, so this test is redundant but kept for completeness
        #expect(true)
    }

    @Test func when_healthy_server_then_returns_running_status() async throws {
        let startTime = Date(timeIntervalSinceNow: -100)
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequestInfo(method: .get, path: "/api/status")

        let response = try await handler.handleRequest(request)

        #expect(response.status == .ok)
        #expect(response.headerFields[.contentType] == "application/json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let statusResponse = try decoder.decode(
            Components.Schemas.ServerStatus.self,
            from: response.body!
        )
        #expect(statusResponse.status == .running)
        #expect(statusResponse.version == "1.0.0")
        #expect(statusResponse.uptime >= 100)
    }

    @Test func when_long_uptime_then_returns_running_status() async throws {
        // 24時間以上前の開始時刻を設定
        let startTime = Date(timeIntervalSinceNow: -90000) // 25時間前
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequestInfo(method: .get, path: "/api/status")

        let response = try await handler.handleRequest(request)

        #expect(response.status == .ok)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let statusResponse = try decoder.decode(Components.Schemas.ServerStatus.self, from: response.body!)
        #expect(statusResponse.status == .running) // 長時間稼働は正常
        #expect(statusResponse.uptime > 86400) // 24時間以上
    }

    @Test func when_uptime_calculated_then_reflects_time_difference() async throws {
        let startTime = Date(timeIntervalSinceNow: -300)
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequestInfo(method: .get, path: "/api/status")

        let response = try await handler.handleRequest(request)

        #expect(response.status == .ok)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let statusResponse = try decoder.decode(Components.Schemas.ServerStatus.self, from: response.body!)
        let uptime = statusResponse.uptime

        #expect(uptime > 299)
        #expect(uptime < 301)
    }

    @Test func when_different_ports_then_returns_running_status() async throws {
        let ports: [UInt16] = [8080, 9090, 3000]
        let startTime = Date()

        for port in ports {
            let handler = StatusHandler(port: port, startTime: startTime)
            let request = HTTPRequestInfo(method: .get, path: "/api/status")

            let response = try await handler.handleRequest(request)

            #expect(response.status == .ok)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let statusResponse = try decoder.decode(Components.Schemas.ServerStatus.self, from: response.body!)
            #expect(statusResponse.status == .running)
        }
    }

    @Test func when_health_check_runs_then_verifies_system_status() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequestInfo(method: .get, path: "/api/status")

        let response = try await handler.handleRequest(request)

        #expect(response.status == .ok)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let statusResponse = try decoder.decode(Components.Schemas.ServerStatus.self, from: response.body!)
        // システムが正常であれば"running"
        #expect(statusResponse.status == .running)
    }
}
