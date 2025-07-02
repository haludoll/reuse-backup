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

    // MARK: - APISharedModels Tests

    // 自動生成モデルのテストはOpenAPI仕様により保証されているため、
    // ここでは内部ServerStatus enumのみをテストします。
}
