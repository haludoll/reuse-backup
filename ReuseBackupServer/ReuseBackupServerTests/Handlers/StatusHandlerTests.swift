import FlyingFox
import Foundation
@testable import ReuseBackupServer
import Testing

/// StatusHandlerのテスト
struct StatusHandlerTests {
    // MARK: - Basic Tests

    @Test func when_handler_initialized_then_properties_are_set() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 9090, startTime: startTime)

        // ハンドラーが正常に初期化されることを確認
        #expect(handler != nil)
    }

    // MARK: - JSON Response Tests

    @Test func when_basic_request_then_returns_json_status() async throws {
        let startTime = Date(timeIntervalSinceNow: -100) // 100秒前に開始
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "application/json")

        let responseData = try JSONSerialization.jsonObject(with: response.body) as! [String: Any]
        #expect(responseData["status"] as? String == "running")
        #expect(responseData["version"] as? String == "1.0.0")
        #expect(responseData["port"] as? UInt16 == 8080)
        #expect(responseData["uptimeSeconds"] as? Double != nil)
        #expect(responseData["requestCount"] as? Int == 1) // 最初のリクエスト
    }

    @Test func when_multiple_requests_then_request_count_increments() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status", headers: [:], body: Data())

        // 3回リクエストを送信
        for expectedCount in 1 ... 3 {
            let response = try await handler.handleRequest(request)

            #expect(response.statusCode == .ok)
            let responseData = try JSONSerialization.jsonObject(with: response.body) as! [String: Any]
            #expect(responseData["requestCount"] as? Int == expectedCount)
        }
    }

    @Test func when_uptime_calculated_then_reflects_time_difference() async throws {
        let startTime = Date(timeIntervalSinceNow: -300) // 5分前に開始
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let responseData = try JSONSerialization.jsonObject(with: response.body) as! [String: Any]
        let uptime = responseData["uptimeSeconds"] as! Double

        // 稼働時間が約300秒（5分）であることを確認（多少の誤差を許容）
        #expect(uptime > 299.0)
        #expect(uptime < 301.0)
    }

    // MARK: - System Info Tests

    @Test func when_system_parameter_true_then_includes_system_info() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status?system=true", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let responseData = try JSONSerialization.jsonObject(with: response.body) as! [String: Any]
        let systemInfo = responseData["systemInfo"] as? [String: Any]

        #expect(systemInfo != nil)
        #expect(systemInfo!["memoryUsage"] != nil)
        #expect(systemInfo!["processId"] != nil)
        #expect(systemInfo!["systemVersion"] != nil)
    }

    @Test func when_system_parameter_false_then_excludes_system_info() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status?system=false", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let responseData = try JSONSerialization.jsonObject(with: response.body) as! [String: Any]
        let systemInfo = responseData["systemInfo"]

        #expect(systemInfo == nil)
    }

    // MARK: - Plain Text Response Tests

    @Test func when_format_plain_then_returns_plain_text() async throws {
        let startTime = Date(timeIntervalSinceNow: -60) // 1分前に開始
        let handler = StatusHandler(port: 9090, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status?format=plain", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "text/plain")

        let responseText = String(data: response.body, encoding: .utf8)!
        #expect(responseText.contains("ReuseBackup Server Status"))
        #expect(responseText.contains("Status: Running"))
        #expect(responseText.contains("Version: 1.0.0"))
        #expect(responseText.contains("Port: 9090"))
        #expect(responseText.contains("Uptime: 1m"))
        #expect(responseText.contains("Requests: 1"))
    }

    @Test func when_format_json_then_returns_json() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status?format=json", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "application/json")

        // JSONが正常にパースできることを確認
        let responseData = try JSONSerialization.jsonObject(with: response.body) as! [String: Any]
        #expect(responseData["status"] as? String == "running")
    }

    @Test func when_invalid_format_then_defaults_to_json() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status?format=xml", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "application/json")
    }

    // MARK: - Uptime Formatting Tests

    @Test func when_uptime_seconds_only_then_formats_correctly() async throws {
        let startTime = Date(timeIntervalSinceNow: -30) // 30秒前
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status?format=plain", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        let responseText = String(data: response.body, encoding: .utf8)!
        #expect(responseText.contains("30s"))
    }

    @Test func when_uptime_minutes_then_formats_correctly() async throws {
        let startTime = Date(timeIntervalSinceNow: -150) // 2分30秒前
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status?format=plain", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        let responseText = String(data: response.body, encoding: .utf8)!
        #expect(responseText.contains("2m 30s"))
    }

    @Test func when_uptime_hours_then_formats_correctly() async throws {
        let startTime = Date(timeIntervalSinceNow: -3900) // 1時間5分前
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status?format=plain", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        let responseText = String(data: response.body, encoding: .utf8)!
        #expect(responseText.contains("1h 5m"))
    }

    // MARK: - Port Configuration Tests

    @Test func when_different_ports_then_response_reflects_correct_port() async throws {
        let ports: [UInt16] = [8080, 9090, 3000]
        let startTime = Date()

        for port in ports {
            let handler = StatusHandler(port: port, startTime: startTime)
            let request = HTTPRequest(method: .GET, path: "/api/status", headers: [:], body: Data())

            let response = try await handler.handleRequest(request)

            #expect(response.statusCode == .ok)
            let responseData = try JSONSerialization.jsonObject(with: response.body) as! [String: Any]
            #expect(responseData["port"] as? UInt16 == port)
        }
    }

    // MARK: - Content Length Tests

    @Test func when_response_generated_then_content_length_matches() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status", headers: [:], body: Data())

        let response = try await handler.handleRequest(request)

        #expect(response.statusCode == .ok)
        let contentLength = response.headers[.contentLength]
        let actualLength = response.body.count
        #expect(contentLength == "\(actualLength)")
    }

    // MARK: - Concurrent Access Tests

    @Test func when_concurrent_requests_then_request_count_is_accurate() async throws {
        let startTime = Date()
        let handler = StatusHandler(port: 8080, startTime: startTime)
        let request = HTTPRequest(method: .GET, path: "/api/status", headers: [:], body: Data())

        // 並行して複数のリクエストを送信
        let numberOfRequests = 10
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< numberOfRequests {
                group.addTask {
                    _ = try? await handler.handleRequest(request)
                }
            }
        }

        // 最終的なリクエスト数を確認
        let finalResponse = try await handler.handleRequest(request)
        let responseData = try JSONSerialization.jsonObject(with: finalResponse.body) as! [String: Any]
        let finalCount = responseData["requestCount"] as! Int

        #expect(finalCount == numberOfRequests + 1) // +1は最終確認のリクエスト
    }
}
