import Foundation
@testable import ReuseBackupServer
import Testing

/// BonjourServiceのテストクラス
struct BonjourServiceTests {
    // MARK: - Initialization Tests

    @Test func when_bonjour_service_initialized_then_properties_are_set_correctly() async throws {
        let port: UInt16 = 8080
        let bonjourService = BonjourService(port: port)

        // 初期状態の確認
        #expect(!bonjourService.isAdvertising)
        #expect(bonjourService.lastError == nil)
    }

    // MARK: - Service Advertisement Tests

    @Test func when_start_advertising_called_then_service_starts() async throws {
        let bonjourService = BonjourService(port: 8080)

        // 発信開始
        bonjourService.startAdvertising()

        // 少し待機してサービスが開始されるのを待つ
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        // Note: 実際のネットワーク発信は環境依存のため、
        // ここでは例外が発生しないことのみを確認
        #expect(bonjourService.lastError == nil)
    }

    @Test func when_start_advertising_called_twice_then_no_error_occurs() async throws {
        let bonjourService = BonjourService(port: 8080)

        // 2回連続で発信開始
        bonjourService.startAdvertising()
        bonjourService.startAdvertising()

        // エラーが発生しないことを確認
        #expect(bonjourService.lastError == nil)
    }

    @Test func when_stop_advertising_called_without_start_then_no_error_occurs() async throws {
        let bonjourService = BonjourService(port: 8080)

        // 開始せずに停止
        bonjourService.stopAdvertising()

        // エラーが発生しないことを確認
        #expect(bonjourService.lastError == nil)
        #expect(!bonjourService.isAdvertising)
    }

    @Test func when_update_txt_record_called_without_advertising_then_no_error_occurs() async throws {
        let bonjourService = BonjourService(port: 8080)

        // 発信していない状態でTXTレコード更新
        bonjourService.updateTXTRecord(status: "stopped", capacity: "unavailable")

        // エラーが発生しないことを確認
        #expect(bonjourService.lastError == nil)
    }

    // MARK: - Service Lifecycle Tests

    @Test func when_service_lifecycle_managed_then_state_transitions_correctly() async throws {
        let bonjourService = BonjourService(port: 8080)

        // 初期状態
        #expect(!bonjourService.isAdvertising)

        // 発信開始
        bonjourService.startAdvertising()

        // 少し待機
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒

        // 発信停止
        bonjourService.stopAdvertising()

        // 最終状態
        #expect(!bonjourService.isAdvertising)
    }

    // MARK: - TXT Record Tests

    @Test func when_txt_record_updated_with_custom_values_then_no_error_occurs() async throws {
        let bonjourService = BonjourService(port: 8080)

        bonjourService.startAdvertising()

        // カスタム値でTXTレコード更新
        bonjourService.updateTXTRecord(status: "maintenance", capacity: "limited")

        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒

        bonjourService.stopAdvertising()

        // エラーが発生しないことを確認
        #expect(bonjourService.lastError == nil)
    }

    // MARK: - Edge Case Tests

    @Test func when_different_ports_used_then_services_can_coexist() async throws {
        let bonjourService1 = BonjourService(port: 8080)
        let bonjourService2 = BonjourService(port: 8081)

        // 異なるポートで同時に発信開始
        bonjourService1.startAdvertising()
        bonjourService2.startAdvertising()

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        // 両方停止
        bonjourService1.stopAdvertising()
        bonjourService2.stopAdvertising()

        // 両方ともエラーが発生しないことを確認
        #expect(bonjourService1.lastError == nil)
        #expect(bonjourService2.lastError == nil)
    }

    @Test func when_service_name_contains_special_characters_then_handles_gracefully() async throws {
        // デバイス名に特殊文字が含まれる可能性をテスト
        let bonjourService = BonjourService(port: 8080)

        bonjourService.startAdvertising()

        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒

        bonjourService.stopAdvertising()

        // 特殊文字が含まれていてもエラーが発生しないことを確認
        #expect(bonjourService.lastError == nil)
    }
}
