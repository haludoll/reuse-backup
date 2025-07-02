//
//  MockHTTPServerService.swift
//  ReuseBackupServer
//
//  Created by haludoll on 2025/07/01.
//

import Foundation
@testable import ReuseBackupServer

/// テスト用のモックHTTPServerService
///
/// テストで使用するためのモック実装です。
/// 実際のサーバーを起動せずにテストを実行できます。
class MockHTTPServerService: HTTPServerServiceProtocol {
    /// サーバーの実行状態（テスト用）
    private(set) var isRunning: Bool = false
    
    /// サーバーが使用するポート番号（テスト用）
    let port: UInt16 = 8080

    /// 開始が呼ばれた回数（テスト検証用）
    private(set) var startCallCount = 0

    /// 停止が呼ばれた回数（テスト検証用）
    private(set) var stopCallCount = 0

    /// 開始時にエラーを投げるかどうか（テスト用）
    var shouldThrowOnStart = false

    /// 開始時に投げるエラー（テスト用）
    var startError: Error = MockError.startFailed

    /// HTTPサーバーを開始（モック実装）
    func start() async throws {
        startCallCount += 1

        if shouldThrowOnStart {
            throw startError
        }

        isRunning = true
    }

    /// HTTPサーバーを停止（モック実装）
    func stop() async {
        stopCallCount += 1
        isRunning = false
    }

    /// テスト用のエラー型
    enum MockError: Error, LocalizedError {
        case startFailed
        case stopFailed

        var errorDescription: String? {
            switch self {
            case .startFailed:
                return "Mock server start failed"
            case .stopFailed:
                return "Mock server stop failed"
            }
        }
    }

    /// テスト状態をリセット
    func reset() {
        isRunning = false
        startCallCount = 0
        stopCallCount = 0
        shouldThrowOnStart = false
        startError = MockError.startFailed
    }
}
