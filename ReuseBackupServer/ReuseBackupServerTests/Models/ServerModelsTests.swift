//
//  ServerModelsTests.swift
//  ReuseBackupServerTests
//
//  Created by haludoll on 2025/07/01.
//

import Foundation
@testable import ReuseBackupServer
import Testing

/// サーバーモデル層のテスト
struct ServerModelsTests {
    // MARK: - ServerStatus Tests

    @Test func when_server_status_stopped_then_description_is_stopped() async throws {
        let status = ServerStatus.stopped
        #expect(status.description == "stopped")
    }

    @Test func when_server_status_starting_then_description_is_starting() async throws {
        let status = ServerStatus.starting
        #expect(status.description == "starting")
    }

    @Test func when_server_status_running_then_description_is_running() async throws {
        let status = ServerStatus.running
        #expect(status.description == "running")
    }

    @Test func when_server_status_stopping_then_description_is_stopping() async throws {
        let status = ServerStatus.stopping
        #expect(status.description == "stopping")
    }

    @Test func when_server_status_error_then_description_is_error() async throws {
        let status = ServerStatus.error("Test error")
        #expect(status.description == "error")
    }

    @Test func when_server_status_equatable_then_comparison_works() async throws {
        #expect(ServerStatus.stopped == ServerStatus.stopped)
        #expect(ServerStatus.running == ServerStatus.running)
        #expect(ServerStatus.error("test") == ServerStatus.error("test"))
        #expect(ServerStatus.stopped != ServerStatus.running)
        #expect(ServerStatus.error("test1") != ServerStatus.error("test2"))
    }

    // MARK: - ServerStatusResponse Tests

    @Test func when_server_status_response_created_then_properties_are_set() async throws {
        let status = "running"
        let version = "1.0.0"
        let serverTime = "2025-07-01T12:00:00Z"

        let response = ServerStatusResponse(
            status: status,
            version: version,
            serverTime: serverTime,
            port: 8080,
            uptimeSeconds: 300.0
        )

        #expect(response.status == status)
        #expect(response.version == version)
        #expect(response.serverTime == serverTime)
    }

    @Test func when_server_status_response_encoded_then_json_is_correct() async throws {
        let response = ServerStatusResponse(
            status: "running",
            version: "1.0.0",
            serverTime: "2025-07-01T12:00:00Z",
            port: 8080,
            uptimeSeconds: 300.0
        )

        let jsonData = try JSONEncoder().encode(response)
        let jsonString = String(data: jsonData, encoding: .utf8)

        #expect(jsonString?.contains("\"status\":\"running\"") == true)
        #expect(jsonString?.contains("\"version\":\"1.0.0\"") == true)
        #expect(jsonString?.contains("\"serverTime\":\"2025-07-01T12:00:00Z\"") == true)
    }

    @Test func when_server_status_response_decoded_then_properties_are_correct() async throws {
        let jsonString = """
        {
            "status": "stopped",
            "version": "2.0.0",
            "serverTime": "2025-07-01T15:30:00Z",
            "port": 9090,
            "uptimeSeconds": 600.5
        }
        """

        let jsonData = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(ServerStatusResponse.self, from: jsonData)

        #expect(response.status == "stopped")
        #expect(response.version == "2.0.0")
        #expect(response.serverTime == "2025-07-01T15:30:00Z")
        #expect(response.port == 9090)
        #expect(response.uptimeSeconds == 600.5)
    }
}
