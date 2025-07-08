import dnssd
import Foundation
import Network
import os.log
import UIKit

/// NetServiceを使用したBonjourサービス発見機能を提供するサービス
final class BonjourService: NSObject, ObservableObject {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "BonjourService")
    private var netService: NetService?
    private let serviceName: String
    private let port: UInt16

    @Published private(set) var isAdvertising = false
    @Published private(set) var lastError: Error?

    /// ユーザーフレンドリーなエラーメッセージ
    var userFriendlyErrorMessage: String? {
        guard let error = lastError else { return nil }

        switch error {
        case NWError.dns(DNSServiceErrorType(kDNSServiceErr_NoAuth)):
            return "ローカルネットワークへのアクセス許可が必要です。設定 > プライバシーとセキュリティ > ローカルネットワーク でこのアプリを有効にしてください。"
        default:
            return "ネットワークエラーが発生しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Initialization

    override init() {
        port = 8080

        // デバイス名を使用してサービス名を生成
        let deviceName = UIDevice.current.name
        serviceName = "ReuseBackupServer-\(deviceName)"

        super.init()
        logger.info("BonjourService initialized with service name: \(self.serviceName), port: \(self.port)")
    }

    init(port: UInt16) {
        self.port = port

        // デバイス名を使用してサービス名を生成
        let deviceName = UIDevice.current.name
        serviceName = "ReuseBackupServer-\(deviceName)"

        super.init()
        logger.info("BonjourService initialized with service name: \(self.serviceName), port: \(self.port)")
    }

    // MARK: - Public Methods

    /// Bonjourサービスの発信を開始
    func startAdvertising() {
        guard !isAdvertising else {
            logger.warning("Bonjour service is already advertising")
            return
        }

        logger.info("Starting Bonjour service advertising")

        // TXTレコードを作成
        let txtRecordData = createTXTRecordData()

        // NetServiceを作成
        netService = NetService(domain: "", type: "_reuse-backup._tcp", name: serviceName, port: Int32(port))

        guard let service = netService else {
            logger.error("Failed to create NetService")
            DispatchQueue.main.async {
                self.lastError = NSError(domain: "BonjourService", code: -1, userInfo: [NSLocalizedDescriptionKey: "NetService作成に失敗"])
            }
            return
        }

        // TXTレコードを設定
        service.setTXTRecord(txtRecordData)

        // デリゲートを設定
        service.delegate = self

        // サービスの発信を開始
        service.publish()
    }

    /// Bonjourサービスの発信を停止
    func stopAdvertising() {
        guard let service = netService else {
            logger.warning("Bonjour service is not running")
            return
        }

        logger.info("Stopping Bonjour service advertising")

        service.stop()
        netService = nil

        DispatchQueue.main.async {
            self.isAdvertising = false
        }

        logger.info("Bonjour service stopped")
    }

    /// TXTレコードを更新
    func updateTXTRecord(status: String = "running", capacity: String = "available") {
        guard let service = netService, isAdvertising else {
            logger.warning("Cannot update TXT record: service not advertising")
            return
        }

        let txtRecordData = createTXTRecordData(status: status, capacity: capacity)
        service.setTXTRecord(txtRecordData)
        logger.info("TXT record updated with status: \(status), capacity: \(capacity)")
    }

    // MARK: - Private Methods

    private func createTXTRecordData(status: String = "running", capacity: String = "available") -> Data {
        var txtDict: [String: Data] = [:]

        // バージョン情報
        txtDict["version"] = "1.0.0".data(using: .utf8)

        // サーバー状態
        txtDict["status"] = status.data(using: .utf8)

        // 容量状態
        txtDict["capacity"] = capacity.data(using: .utf8)

        // デバイス情報
        txtDict["device"] = UIDevice.current.model.data(using: .utf8)

        // ポート情報（クライアントが接続するため）
        let portString = String(port)
        txtDict["port"] = portString.data(using: .utf8)

        return NetService.data(fromTXTRecord: txtDict)
    }
}

// MARK: - NetServiceDelegate

extension BonjourService: NetServiceDelegate {
    func netServiceDidPublish(_: NetService) {
        logger.info("Bonjour service published successfully")
        DispatchQueue.main.async {
            self.isAdvertising = true
            self.lastError = nil
        }
    }

    func netService(_: NetService, didNotPublish errorDict: [String: NSNumber]) {
        logger.error("Bonjour service failed to publish: \(errorDict)")

        let error = NSError(domain: "BonjourService", code: -1, userInfo: errorDict as [String: Any])
        DispatchQueue.main.async {
            self.isAdvertising = false
            self.lastError = error
        }
    }

    func netServiceDidStop(_: NetService) {
        logger.info("Bonjour service stopped")
        DispatchQueue.main.async {
            self.isAdvertising = false
        }
    }
}
