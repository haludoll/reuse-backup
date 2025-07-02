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
        let service = HTTPServerService()

        #expect(service.isRunning == false)
    }

    // MARK: - Integration Tests

    // 注意: 実際のHTTPServerServiceの統合テストは実際のサーバーを起動するため
    // ここでは基本的なテストのみ実装し、詳細なテストはモックを使用

    @Test func service_conforms_to_protocol() async throws {
        let service: HTTPServerServiceProtocol = HTTPServerService()

        #expect(service.isRunning == false)
        // プロトコルに準拠していることを確認
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
        let service: HTTPServerServiceProtocol = HTTPServerService()
        #expect(service.isRunning == false)
    }

    @Test func mock_service_conforms_to_protocol() async throws {
        let service: HTTPServerServiceProtocol = MockHTTPServerService()
        #expect(service.isRunning == false)
    }

    @Test func protocol_polymorphism() async throws {
        let services: [HTTPServerServiceProtocol] = [
            HTTPServerService(),
            MockHTTPServerService(),
        ]

        for service in services {
            #expect(service.isRunning == false)
        }
    }
}
