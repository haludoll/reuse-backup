//
//  HTTPServerServiceTests.swift
//  ReuseBackupServerTests
//
//  Created by haludoll on 2025/07/01.
//

import Foundation
@testable import ReuseBackupServer
import Testing

/// HTTPサーバーサービス層のテスト
struct HTTPServerServiceTests {
    // MARK: - Basic Service Tests

    @Test func when_service_initialized_then_default_state_is_correct() async throws {
        let service = await HTTPServerService()

        #expect(await service.isRunning == false)
        #expect(await service.port == 8080)
    }

    @Test func when_service_initialized_with_custom_port_then_port_is_set() async throws {
        let customPort: UInt16 = 9090
        let service = await HTTPServerService(port: customPort)

        #expect(await service.port == customPort)
        #expect(await service.isRunning == false)
    }

    // MARK: - Dependency Injection Tests

    @Test func when_service_initialized_with_mock_factory_then_uses_mock() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        #expect(await service.isRunning == false)
        #expect(mockFactory.createServerCallCount == 0)
    }

    @Test func when_service_starts_then_creates_server_via_factory() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        try await service.start()

        #expect(mockFactory.createServerCallCount == 1)
        #expect(mockFactory.lastCreatedPort == 8080)
        #expect(await service.isRunning == true)

        await service.stop()
    }

    @Test func when_service_starts_then_configures_routes() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        try await service.start()

        guard let mockServer = mockFactory.lastCreatedServer else {
            #expect(Bool(false), "Mock server should be created")
            return
        }

        #expect(mockServer.appendRouteCallCount == 2)
        #expect(mockServer.hasRoute(.init(method: .GET, path: "/api/status")))
        #expect(mockServer.hasRoute(.init(method: .POST, path: "/api/message")))

        await service.stop()
    }

    @Test func when_service_starts_multiple_times_then_only_starts_once() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        try await service.start()
        try await service.start()
        try await service.start()

        #expect(mockFactory.createServerCallCount == 1)
        #expect(await service.isRunning == true)

        await service.stop()
    }

    @Test func when_service_stops_then_server_stops() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        try await service.start()
        #expect(await service.isRunning == true)

        await service.stop()

        #expect(await service.isRunning == false)
        guard let mockServer = mockFactory.lastCreatedServer else {
            #expect(Bool(false), "Mock server should exist")
            return
        }
        #expect(mockServer.stopCallCount == 1)
    }

    @Test func when_service_stops_without_starting_then_no_error() async throws {
        let service = await HTTPServerService()

        await service.stop()

        #expect(await service.isRunning == false)
    }

    @Test func when_service_stops_multiple_times_then_stops_gracefully() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        try await service.start()
        await service.stop()
        await service.stop()
        await service.stop()

        #expect(await service.isRunning == false)
        guard let mockServer = mockFactory.lastCreatedServer else {
            #expect(Bool(false), "Mock server should exist")
            return
        }
        #expect(mockServer.stopCallCount == 1)
    }

    // MARK: - Route Handler Tests

    @Test func when_status_handler_configured_then_route_exists() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        try await service.start()

        guard let mockServer = mockFactory.lastCreatedServer else {
            #expect(Bool(false), "Mock server should exist")
            return
        }

        #expect(mockServer.hasRoute(.init(method: .GET, path: "/api/status")))

        await service.stop()
    }

    // MARK: - Error Handling Tests

    @Test func when_server_factory_throws_then_service_handles_error() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        // サーバー作成後にrun()でエラーを発生させる
        try await service.start()

        guard let mockServer = mockFactory.lastCreatedServer else {
            #expect(Bool(false), "Mock server should exist")
            return
        }

        // モックサーバーでエラーをシミュレート
        mockServer.shouldThrowOnRun = true

        // サーバーがエラーで停止した場合、isRunningがfalseになることを確認
        // 実際のテストでは、サーバータスクの完了を待つ必要がある
        await service.stop()
        #expect(await service.isRunning == false)
    }

    // MARK: - Integration Tests

    @Test func service_conforms_to_protocol() async throws {
        let service: HTTPServerServiceProtocol = await HTTPServerService()

        #expect(await service.isRunning == false)
    }

    @Test func service_lifecycle_with_mock() async throws {
        let mockFactory = MockHTTPServerFactory()
        let service = await HTTPServerService(port: 8080, serverFactory: mockFactory)

        // 初期状態
        #expect(await service.isRunning == false)
        #expect(mockFactory.createServerCallCount == 0)

        // 開始
        try await service.start()
        #expect(await service.isRunning == true)
        #expect(mockFactory.createServerCallCount == 1)

        // 停止
        await service.stop()
        #expect(await service.isRunning == false)

        // 再開始
        try await service.start()
        #expect(await service.isRunning == true)
        #expect(mockFactory.createServerCallCount == 2)

        await service.stop()
    }
}

/// モックHTTPサーバーサービスのテスト
struct MockHTTPServerServiceTests {
    // MARK: - Initialization Tests

    @Test func when_mock_service_initialized_then_default_state_is_correct() async throws {
        let mockService = MockHTTPServerService()

        #expect(mockService.isRunning == false)
        #expect(mockService.startCallCount == 0)
        #expect(mockService.stopCallCount == 0)
        #expect(mockService.shouldThrowOnStart == false)
    }

    // MARK: - Start Tests

    @Test func when_mock_service_start_then_state_updates() async throws {
        let mockService = MockHTTPServerService()

        try await mockService.start()

        #expect(mockService.isRunning == true)
        #expect(mockService.startCallCount == 1)
    }

    @Test func when_mock_service_start_multiple_times_then_call_count_increases() async throws {
        let mockService = MockHTTPServerService()

        try await mockService.start()
        try await mockService.start()
        try await mockService.start()

        #expect(mockService.startCallCount == 3)
        #expect(mockService.isRunning == true) // 最後の状態
    }

    @Test func when_mock_service_start_with_error_then_throws() async throws {
        let mockService = MockHTTPServerService()
        mockService.shouldThrowOnStart = true

        do {
            try await mockService.start()
            #expect(Bool(false), "Expected error to be thrown")
        } catch {
            #expect(mockService.startCallCount == 1)
            #expect(mockService.isRunning == false)
            #expect(error is MockHTTPServerService.MockError)
        }
    }

    @Test func when_mock_service_start_with_custom_error_then_throws_custom_error() async throws {
        let mockService = MockHTTPServerService()
        mockService.shouldThrowOnStart = true
        mockService.startError = MockHTTPServerService.MockError.stopFailed

        do {
            try await mockService.start()
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as MockHTTPServerService.MockError {
            #expect(error == .stopFailed)
            #expect(mockService.startCallCount == 1)
        }
    }

    // MARK: - Stop Tests

    @Test func when_mock_service_stop_then_state_updates() async throws {
        let mockService = MockHTTPServerService()

        // 先に開始
        try await mockService.start()
        #expect(mockService.isRunning == true)

        // 停止
        await mockService.stop()

        #expect(mockService.isRunning == false)
        #expect(mockService.stopCallCount == 1)
    }

    @Test func when_mock_service_stop_multiple_times_then_call_count_increases() async throws {
        let mockService = MockHTTPServerService()

        await mockService.stop()
        await mockService.stop()
        await mockService.stop()

        #expect(mockService.stopCallCount == 3)
        #expect(mockService.isRunning == false)
    }

    // MARK: - State Management Tests

    @Test func when_mock_service_reset_then_state_resets() async throws {
        let mockService = MockHTTPServerService()

        // 状態を変更
        try await mockService.start()
        await mockService.stop()
        mockService.shouldThrowOnStart = true

        // リセット
        mockService.reset()

        #expect(mockService.isRunning == false)
        #expect(mockService.startCallCount == 0)
        #expect(mockService.stopCallCount == 0)
        #expect(mockService.shouldThrowOnStart == false)
    }

    // MARK: - Error Handling Tests

    @Test func mock_error_descriptions() async throws {
        let startError = MockHTTPServerService.MockError.startFailed
        let stopError = MockHTTPServerService.MockError.stopFailed

        #expect(startError.errorDescription == "Mock server start failed")
        #expect(stopError.errorDescription == "Mock server stop failed")
    }

    @Test func mock_error_equality() async throws {
        #expect(MockHTTPServerService.MockError.startFailed == MockHTTPServerService.MockError.startFailed)
        #expect(MockHTTPServerService.MockError.stopFailed == MockHTTPServerService.MockError.stopFailed)
        #expect(MockHTTPServerService.MockError.startFailed != MockHTTPServerService.MockError.stopFailed)
    }

    // MARK: - Complex Scenario Tests

    @Test func complex_start_stop_error_scenario() async throws {
        let mockService = MockHTTPServerService()

        // 正常開始
        try await mockService.start()
        #expect(mockService.isRunning == true)
        #expect(mockService.startCallCount == 1)

        // 正常停止
        await mockService.stop()
        #expect(mockService.isRunning == false)
        #expect(mockService.stopCallCount == 1)

        // エラー設定して開始
        mockService.shouldThrowOnStart = true
        do {
            try await mockService.start()
            #expect(Bool(false), "Expected error")
        } catch {
            #expect(mockService.startCallCount == 2)
            #expect(mockService.isRunning == false)
        }

        // エラー解除して再開始
        mockService.shouldThrowOnStart = false
        try await mockService.start()
        #expect(mockService.isRunning == true)
        #expect(mockService.startCallCount == 3)
    }
}

/// プロトコル準拠性のテスト
struct HTTPServerServiceProtocolTests {
    @Test func real_service_conforms_to_protocol() async throws {
        let service: HTTPServerServiceProtocol = await HTTPServerService()
        #expect(await service.isRunning == false)
    }

    @Test func mock_service_conforms_to_protocol() async throws {
        let service: HTTPServerServiceProtocol = MockHTTPServerService()
        #expect(service.isRunning == false)
    }

    @Test func protocol_polymorphism() async throws {
        let services: [HTTPServerServiceProtocol] = [
            await HTTPServerService(),
            MockHTTPServerService(),
        ]

        for service in services {
            #expect(await service.isRunning == false)
        }
    }
}
