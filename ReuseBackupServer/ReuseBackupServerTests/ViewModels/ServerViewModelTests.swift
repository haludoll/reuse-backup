//
//  ServerViewModelTests.swift
//  ReuseBackupServerTests
//
//  Created by haludoll on 2025/07/01.
//

import Foundation
@testable import ReuseBackupServer
import Testing

/// サーバーViewModel層のテスト
struct ServerViewModelTests {
    // MARK: - Initialization Tests

    @Test func when_viewmodel_initialized_then_default_state_is_correct() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        let isRunning = await viewModel.isRunning
        let serverStatus = await viewModel.serverStatus
        let errorMessage = await viewModel.errorMessage

        #expect(isRunning == false)
        #expect(serverStatus == .stopped)
        #expect(errorMessage == nil)
    }

    // MARK: - Server Start Tests

    @Test func when_start_server_success_then_state_updates_correctly() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        await viewModel.startServer()

        let isRunning = await viewModel.isRunning
        let serverStatus = await viewModel.serverStatus
        let errorMessage = await viewModel.errorMessage

        #expect(mockService.startCallCount == 1)
        #expect(isRunning == true)
        #expect(serverStatus == .running)
        #expect(errorMessage == nil)
    }

    @Test func when_start_server_fails_then_error_state_is_set() async throws {
        let mockService = MockHTTPServerService()
        mockService.shouldThrowOnStart = true
        let viewModel = await ServerViewModel(httpServerService: mockService)

        await viewModel.startServer()

        let isRunning = await viewModel.isRunning
        let serverStatus = await viewModel.serverStatus
        let errorMessage = await viewModel.errorMessage

        #expect(mockService.startCallCount == 1)
        #expect(isRunning == false)
        #expect(serverStatus == .error("Failed to start server: Mock server start failed"))
        #expect(errorMessage != nil)
    }

    @Test func when_start_server_already_running_then_no_operation() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        // 先にサーバーを開始
        await viewModel.startServer()
        #expect(mockService.startCallCount == 1)

        // 再度開始を試行
        await viewModel.startServer()

        // 開始は一度だけ呼ばれる
        #expect(mockService.startCallCount == 1)
    }

    // MARK: - Server Stop Tests

    @Test func when_stop_server_then_state_updates_correctly() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        // 先にサーバーを開始
        await viewModel.startServer()
        let isRunningAfterStart = await viewModel.isRunning
        #expect(isRunningAfterStart == true)

        // サーバーを停止
        await viewModel.stopServer()

        let isRunning = await viewModel.isRunning
        let serverStatus = await viewModel.serverStatus
        let errorMessage = await viewModel.errorMessage

        #expect(mockService.stopCallCount == 1)
        #expect(isRunning == false)
        #expect(serverStatus == .stopped)
        #expect(errorMessage == nil)
    }

    @Test func when_stop_server_not_running_then_no_operation() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        // サーバーが停止状態で停止を試行
        await viewModel.stopServer()

        // 停止は呼ばれない
        #expect(mockService.stopCallCount == 0)
    }

    // MARK: - State Sync Tests

    @Test func when_refresh_server_status_then_state_syncs_with_service() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        // サービスの状態を直接変更（シミュレーション）
        try await mockService.start()

        // ビューモデルの状態を更新
        await viewModel.refreshServerStatus()

        let isRunning = await viewModel.isRunning
        let serverStatus = await viewModel.serverStatus

        #expect(isRunning == mockService.isRunning)
        #expect(serverStatus == .running)
    }

    // MARK: - Computed Properties Tests

    @Test func computed_properties_when_stopped() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        let portString = await viewModel.portString
        let statusDisplayText = await viewModel.statusDisplayText
        let controlButtonTitle = await viewModel.controlButtonTitle
        let isControlButtonDisabled = await viewModel.isControlButtonDisabled

        #expect(portString == "8080")
        #expect(statusDisplayText == "停止中")
        #expect(controlButtonTitle == "サーバー開始")
        #expect(isControlButtonDisabled == false)
    }

    @Test func computed_properties_when_running() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        // サーバーを開始
        await viewModel.startServer()

        let statusDisplayText = await viewModel.statusDisplayText
        let controlButtonTitle = await viewModel.controlButtonTitle
        let isControlButtonDisabled = await viewModel.isControlButtonDisabled

        #expect(statusDisplayText == "稼働中")
        #expect(controlButtonTitle == "サーバー停止")
        #expect(isControlButtonDisabled == false)
    }

    @Test func computed_properties_when_error() async throws {
        let mockService = MockHTTPServerService()
        mockService.shouldThrowOnStart = true
        let viewModel = await ServerViewModel(httpServerService: mockService)

        // サーバー開始でエラーを発生
        await viewModel.startServer()

        let statusDisplayText = await viewModel.statusDisplayText
        let controlButtonTitle = await viewModel.controlButtonTitle
        let isControlButtonDisabled = await viewModel.isControlButtonDisabled

        #expect(statusDisplayText.contains("エラー") == true)
        #expect(controlButtonTitle == "サーバー開始")
        #expect(isControlButtonDisabled == false)
    }

    // MARK: - Edge Cases Tests

    @Test func multiple_start_stop_operations() async throws {
        let mockService = MockHTTPServerService()
        let viewModel = await ServerViewModel(httpServerService: mockService)

        // 複数回の開始・停止操作
        await viewModel.startServer()
        await viewModel.stopServer()
        await viewModel.startServer()
        await viewModel.stopServer()

        let finalIsRunning = await viewModel.isRunning
        let finalServerStatus = await viewModel.serverStatus

        #expect(mockService.startCallCount == 2)
        #expect(mockService.stopCallCount == 2)
        #expect(finalIsRunning == false)
        #expect(finalServerStatus == .stopped)
    }
}
